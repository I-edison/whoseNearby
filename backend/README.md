# WhoseNearby API

Node.js + Express + TypeScript + Prisma (SQLite) backend for the WhoseNearby artisan marketplace.

## Quick start

```bash
cd whosenearby_backend
npm install
npm run db:setup   # generate client, create DB, seed demo data
npm run dev        # http://localhost:4000
```

## Demo accounts

| Role    | Phone / Email              | Password     |
|---------|----------------------------|--------------|
| Client  | `08012345678` / tunde@example.com | `password123` |
| Artisan | `08023456789` / emeka@example.com | `password123` |

OTP demo code: `123456`

## API overview

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/register` | — | Create account + wallet |
| POST | `/auth/login` | — | Login → JWT |
| POST | `/auth/otp/request` | — | Request OTP |
| POST | `/auth/otp/verify` | — | Verify OTP |
| GET | `/auth/me` | ✓ | Current user |
| GET | `/artisans?skill=&lat=&lng=&radius=` | — | Search nearby |
| GET | `/artisans/:id` | — | Artisan detail |
| POST | `/artisans/profile` | ✓ | Become artisan |
| GET | `/jobs/mine` | ✓ | My jobs |
| POST | `/jobs` | ✓ | Post job |
| POST | `/jobs/:id/start` | ✓ | Fund escrow (PIN) |
| POST | `/jobs/:id/complete` | ✓ | Release payment |
| POST | `/jobs/:id/rate` | ✓ | Rate artisan |
| GET | `/wallet` | ✓ | Balance + history |
| POST | `/wallet/pin` | ✓ | Set transfer PIN |
| POST | `/wallet/fund` | ✓ | Fund wallet |
| GET | `/chat/conversations` | ✓ | Message list |
| GET | `/chat/:jobId/messages` | ✓ | Thread |
| POST | `/chat/:jobId/messages` | ✓ | Send message |
| GET | `/notifications` | ✓ | Alerts |

## Job lifecycle

```
OPEN → NEGOTIATING → IN_PROGRESS (escrow hold) → COMPLETED (release) → rate
```

## Flutter connection

Point the app at:

```
http://localhost:4000   # web / iOS simulator
http://10.0.2.2:4000   # Android emulator
```

Use `Authorization: Bearer <token>` on protected routes.

## Production notes

- Switch `DATABASE_URL` to Postgres
- Change `JWT_SECRET`
- Remove `demoCode` from OTP response
- Add real SMS/email OTP provider
- Add rate limiting & request validation hardening
