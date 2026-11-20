"""Generate a fresh BIP39 seed and show the addresses it derives."""
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from mnemonic import Mnemonic  # noqa: E402

from app.wallets import NETWORK_LABELS, addresses  # noqa: E402


def main() -> None:
    phrase = Mnemonic("english").generate(strength=256)
    print("BIP39 seed (SAVE OFFLINE — this is the only way to spend):")
    print(phrase)
    print("\nDerived addresses:")
    for network, address in addresses(phrase).items():
        print(f"  {NETWORK_LABELS[network]:<24} {address}")
    print("\nPaste the phrase into WALLET_SEED in your .env / Pterodactyl environment.")


if __name__ == "__main__":
    main()
