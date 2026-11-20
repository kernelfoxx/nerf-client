"""Deterministic receiving addresses derived from one BIP39 seed.

BTC / ETH / TRON use standard BIP32 paths (m/44'/0'/0'/0/0, /60'/, /195'/).
TON uses an ed25519 key seeded by HMAC-SHA512 of the BIP39 seed -- deterministic,
but not a BIP32 TON path. Keep the seed offline: it is the only way to spend.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
from functools import lru_cache

import base58
from Crypto.Hash import keccak as _keccak
from ecdsa import SECP256k1, SigningKey
from ecdsa.curves import SECP256k1 as _CURVE
from mnemonic import Mnemonic
from nacl.signing import SigningKey as Ed25519SigningKey

ORDER = _CURVE.order
HARDENED = 0x80000000

NETWORKS = ("ton", "btc", "usdt-trc20", "usdt-erc20")
NETWORK_LABELS = {
    "ton": "TON",
    "btc": "Bitcoin",
    "usdt-trc20": "USDT · TRON (TRC20)",
    "usdt-erc20": "USDT · Ethereum (ERC20)",
}
COIN_TICKER = {
    "ton": "TON",
    "btc": "BTC",
    "usdt-trc20": "USDT",
    "usdt-erc20": "USDT",
}
DERIVATION_PATHS = {
    "btc": "m/44'/0'/0'/0/0",
    "usdt-erc20": "m/44'/60'/0'/0/0",
    "usdt-trc20": "m/44'/195'/0'/0/0",
    "ton": "HMAC-SHA512(seed, 'nerfgram-ton-ed25519')",
}


def sha256(data: bytes) -> bytes:
    return hashlib.sha256(data).digest()


def ripemd160(data: bytes) -> bytes:
    from Crypto.Hash import RIPEMD160

    return RIPEMD160.new(data).digest()


def keccak256(data: bytes) -> bytes:
    k = _keccak.new(digest_bits=256)
    k.update(data)
    return k.digest()


def hash160(data: bytes) -> bytes:
    return ripemd160(sha256(data))


def base58check(prefix: bytes, payload: bytes) -> str:
    raw = prefix + payload
    return base58.b58encode(raw + sha256(sha256(raw))[:4]).decode("ascii")


def _compressed(priv: bytes) -> bytes:
    return SigningKey.from_string(priv, curve=SECP256k1).get_verifying_key().to_string("compressed")


def _uncompressed(priv: bytes) -> bytes:
    return SigningKey.from_string(priv, curve=SECP256k1).get_verifying_key().to_string()


def _master(seed: bytes) -> tuple[bytes, bytes]:
    i = hmac.new(b"Bitcoin seed", seed, hashlib.sha512).digest()
    return i[:32], i[32:]


def _child(priv: bytes, chain: bytes, index: int) -> tuple[bytes, bytes]:
    if index >= HARDENED:
        data = b"\x00" + priv + index.to_bytes(4, "big")
    else:
        data = _compressed(priv) + index.to_bytes(4, "big")
    i = hmac.new(chain, data, hashlib.sha512).digest()
    child = (int.from_bytes(i[:32], "big") + int.from_bytes(priv, "big")) % ORDER
    return child.to_bytes(32, "big"), i[32:]


def _derive(seed: bytes, coin: int) -> bytes:
    priv, chain = _master(seed)
    for index in (HARDENED + 44, HARDENED + coin, HARDENED, 0, 0):
        priv, chain = _child(priv, chain, index)
    return priv


def _btc_address(priv: bytes) -> str:
    return base58check(b"\x00", hash160(_compressed(priv)))


def _eth_address(priv: bytes) -> str:
    raw = keccak256(_uncompressed(priv)[1:])[-20:]
    lower = raw.hex()
    digest = keccak256(lower.encode("ascii")).hex()
    checksum = "".join(c.upper() if c in "abcdef" and int(digest[i], 16) >= 8 else c for i, c in enumerate(lower))
    return "0x" + checksum


def _tron_address(priv: bytes) -> str:
    return base58check(b"\x41", keccak256(_uncompressed(priv)[1:])[-20:])


def _crc16_xmodem(data: bytes) -> int:
    crc = 0
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def _ton_address(seed: bytes) -> str:
    ton_seed = hmac.new(b"nerfgram-ton-ed25519", seed, hashlib.sha512).digest()[:32]
    public = Ed25519SigningKey(ton_seed).verify_key.encode()
    account_id = hashlib.sha256(public).digest()
    # Friendly TON address: bounceable tag (0x11), 1-byte workchain, 32-byte account id, CRC16.
    # The leading "EQ" is part of the base64 of the first two bytes, not a prefix to add.
    payload = b"\x11\x00" + account_id
    friendly = payload + _crc16_xmodem(payload).to_bytes(2, "big")
    return base64.urlsafe_b64encode(friendly).decode("ascii").rstrip("=")


@lru_cache(maxsize=1)
def addresses(seed_phrase: str) -> dict[str, str]:
    """Return one address per supported network, derived from the seed phrase."""
    phrase = " ".join(seed_phrase.strip().split())
    if not Mnemonic("english").check(phrase):
        raise ValueError("WALLET_SEED is not a valid BIP39 mnemonic")
    seed = Mnemonic("english").to_seed(phrase, passphrase="")
    return {
        "ton": _ton_address(seed),
        "btc": _btc_address(_derive(seed, 0)),
        "usdt-trc20": _tron_address(_derive(seed, 195)),
        "usdt-erc20": _eth_address(_derive(seed, 60)),
    }
