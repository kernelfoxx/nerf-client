# Установка на Pterodactyl (512 МБ RAM)

Pterodactyl даёт контейнер с публичным IP и портом. Бот работает на **long polling**, поэтому HTTPS-webhook и домен не нужны. Для кнопки «Открыть Nerf Gram» достаточно `http://IP:PORT`; для нативного `Telegram.WebApp.openInvoice` Telegram требует HTTPS — если он не откроется, поставь Cloudflare Tunnel/Nginx перед контейнером и укажи HTTPS-адрес в `PUBLIC_BASE_URL`.

## 1. Файлы

Залей в папку сервера:

```
app/
static/
scripts/
requirements.txt
Dockerfile
.env.example
```

`.env` **не заливать** — секреты задаются переменными окружения в панели.

## 2. Egg / Startup

- Docker Image: `python:3.12-slim`
- Startup Command: `python -m app.main`
- Port: `8080` (или любой, но он должен совпадать с `PORT`)
- Working Directory: `/app` (или `/home/container`, если залил без Docker)

Если используешь прилагаемый `Dockerfile`, сборка сама ставит зависимости; для «обычного» Python Egg добавь в Startup先行:

```sh
pip install --no-cache-dir -r requirements.txt && python -m app.main
```

Pterodactyl с 512 МБ выдержит: один uvicorn + httpx long polling, без тяжёлых ORM.

## 3. Переменные окружения

Скопируй поля из `.env.example` в панель:

| Переменная | Что положить |
|---|---|
| `BOT_TOKEN` | токен от @BotFather |
| `BOT_USERNAME` | имя бота без `@` |
| `PUBLIC_BASE_URL` | `http://<IP>:<public-port>` или HTTPS-домен |
| `PORT` | `8080` |
| `APP_SECRET` | `python -c "import secrets; print(secrets.token_urlsafe(48))"` |
| `WALLET_SEED` | 24 слова из `python scripts/generate_seed.py` |
| `CRYPTO_RATES_JSON` | `{"BTC":95000,"TON":5.5,"USDT":1}` |
| `CRYPTO_AUTO_CHECK` | `true` |
| `CRYPTO_MIN_CONFIRMATIONS` | `1` |
| `ETHERSCAN_API_KEY` | ключ Etherscan (нужен для точной проверки суммы ERC20) |

**Никогда** не публикуй `WALLET_SEED` и `APP_SECRET`. Seed — единственный способ вернуть средства с адресов.

## 4. Первый запуск

1. Создай бота у @BotFather.
2. Сгенерируй seed: `python scripts/generate_seed.py` (локально), скопируй фразу в `WALLET_SEED`.
3. Запусти контейнер. В логах должно быть `Bot: @...` и `Bot polling started`.
4. Напиши боту `/start`, нажми «Открыть Nerf Gram».
5. Проверь `/api/config` — должны вернуться тарифы и адреса.
6. Купи пробу через кнопку бота или сайт; бот пришлёт ключ `NFG-...`.
7. В iOS: Настройки ▸ Nerf Client ▸ Nerf Gram ▸ Ключ подписки, вставь ключ; сервер подписки — тот же `PUBLIC_BASE_URL`.

## 5. Подтверждение крипты

Подтверждения продавцом/админом **нет**: пользователь вводит tx hash, сервер опрашивает публичные блок-эксплореры. Если сумма и подтверждения сходятся, подписка активируется и бот сам отправляет ключ. В споре/ошибке эксплорера платеж остаётся `pending` — это не требует действий продавца.

## 6. Обслуживание

- База: `data/nerfgram.sqlite3` — включиvolume/-диск в панели, иначе данные исчезнут при пересоздании контейнера.
- Логи: обычный stdout контейнера.
- Смена `APP_SECRET` аннулирует все выданные токены входа и ключи.
- Смена `WALLET_SEED` сменит все адреса — не делай этого после приёма платежей.
