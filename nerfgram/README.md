# Nerf Gram — платёльный бэкенд

Самостоятельный Python-стек для подписки Nerf Gram. Ставится на хостинг отдельно от iOS-приложения.

## Что внутри

- **Бот** (`app/bot.py`) — long polling через `getUpdates`, поэтому не нужен HTTPS-webhook и домен: работает на голом IP:порту Pterodactyl.
- **Сайт оплаты** (`static/`) — тёмный glass-дизайн, 3 тарифа, Telegram Stars и 4 криптосети, копирование адреса, заявка с tx hash.
- **Своя логика оплаты** (`app/service.py`, `app/db.py`) — без сторонних платёжных процессоров. Stars сверяются с `SuccessfulPayment`, крипта проверяется автоматически через публичные блок-эксплореры: продавец/админ ничего не подтверждает.
- **HD-адреса** (`app/wallets.py`) — TON, BTC, USDT TRC20, USDT ERC20 из одной BIP39-сид-фразы. BTC/ETH/TRON — стандартные BIP32-пути, TON — детерминированный ed25519-ключ из того же сида.
- **SQLite** — пользователи, entitlements, платежи, ключи активации. Один файл `data/nerfgram.sqlite3`.

## Тарифы

| Тариф | Цена | Stars |
|---|---|---|
| 3 дня | бесплатно, один раз | — |
| 7 дней | $2 | 200 XTR |
| 30 дней | $4 | 400 XTR |

Bot API permite `subscription_period` только `2592000` (30 дней), поэтому 7-дневный тариф — одноразовый XTR-инвойс с локальным учётом срока. 30 дней тоже одноразовый, чтобы логика была одинаковой.

## Локальный запуск

```sh
python -m venv .venv
. .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
# заполни BOT_TOKEN, APP_SECRET, PUBLIC_BASE_URL, ADMIN_IDS
python scripts/generate_seed.py   # сид-фраза + адреса
# вставь сид в WALLET_SEED в .env
set -a; . ./.env; set +a       # Windows PowerShell: Get-Content .env | ForEach-Object { ... }
python -m app.main
```

Открой `http://127.0.0.1:8080`. Бот напишет тебе в личку по `/start`.

## Установка на Pterodactyl (512 МБ)

Подробности — [PTERODACTYL.md](PTERODACTYL.md). Коротко:

1. Создай Egg с Docker-образом `python:3.12-slim`, Startup Command `python -m app.main`.
2. Скинь сюда `app/`, `static/`, `requirements.txt`, `Dockerfile`.
3. Переменные окружения — из `.env.example`.
4. Выдели порт 8080 и пробрось его наружу. `PUBLIC_BASE_URL` = `http://<IP>:<port>`.
5. Памяти 512 МБ достаточно: один uvicorn + polling, без тяжёлых ORM и web3.

## Поток оплаты

### Telegram Stars
1. Бот `/start` даёт ссылку `PUBLIC_BASE_URL/?auth=<подписанный токен>`.
2. Сайт запоминает токен в `localStorage` и показывает тарифы.
3. `POST /api/stars/invoice` → `createInvoiceLink(currency=XTR, prices=[...])`.
4. `pre_checkout_query` проверяет подпись payload и отвечает в течение 10 секунд.
5. `successful_payment` создаёт запись о платеже и вызывает `grant()`.
6. Бот присылает ключ `NFG-XXXXXX-XX`.

### Крипта
1. Сайт показывает адрес и сумму по текущему курсу из `CRYPTO_RATES_JSON`.
2. Пользователь переводит и вставляет tx hash.
3. Создаётся платёж в статусе `pending`; сервер проверяет tx hash в публичном блок-эксплорере.
4. Если сумма и число подтверждений сходятся, подписка активируется и бот сам отправляет ключ. Ручного подтверждения продавцом нет.

## API для iOS

`GET /api/entitlement?key=NFG-XXXXXX-XX`

```json
{"valid":true,"active":true,"plan":"week","active_until":1760000000,"user_id":123456789}
```

Ключ одноразово помечается использованным. Приложение должно хранить `active_until` локально и обновлять его, если ключ активен дольше.

## Безопасность

- `APP_SECRET` подписывает токены входа, payloadinvoice-ов и контрольные цифры ключа. Без него токены подделать нельзя.
- `WALLET_SEED` — единственный способ получить средства. Храни его только в переменных окружения панели и в офлайн-копии. Не коммить `.env`.
- Crypto-платежи проверяются публичными explorer-API без участия продавца; при ошибке API платёж остаётся `pending`, а не выдаёт доступ.
- Отзыв подписки через `subscription` update обрабатывается, но обычные тарифы одноразовые.

## Структура

```
nerfgram/
├── app/
│   ├── auth.py        подписанные токены, payload, ключи
│   ├── bot.py         long polling и обработка обновлений
│   ├── config.py      окружение
│   ├── db.py          SQLite
│   ├── main.py        единая точка входа
│   ├── plans.py       тарифы
│   ├── service.py     начисление подписок и платежи
│   ├── telegram.py    Bot API
│   ├── wallets.py     BIP39/BIP32 → адреса
│   └── web.py         FastAPI + API
├── scripts/generate_seed.py
├── static/            HTML/CSS/JS страницы оплаты
├── Dockerfile
└── .env.example
```
