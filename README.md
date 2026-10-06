# WhoseNearby

Find artisans nearby. Chat, agree a price, pay into a safe hold, release when the job is done.

## Stack
- **Frontend:** Flutter (web / Android)
- **Backend:** Node.js + Express + Prisma (SQLite or Postgres)
- **Realtime:** WebSocket chat

## Quick start (local)
See `PUBLIC_TEST.md` for public beta steps.

```bash
# API
cd backend && cp .env.example .env && npm install && npx prisma db push && npm run dev

# App
cd frontend && flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8081 \
  --dart-define=API_BASE_URL=http://127.0.0.1:4000
```

Closed-beta OTP: **123456**

## Recent fixes
- Notifications schema (`data` field) + safer notify on payment
- Chat list: one conversation per person
- Profile cover image (changeable) + whoseNearby watermark
- Wallet “on hold” copy written for everyday users
