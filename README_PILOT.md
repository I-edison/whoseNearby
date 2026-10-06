# WhoseNearby — full pilot bundle

## Contents
- `frontend/` — Flutter app (logos, splash, location, chat, media, profile, home cards)
- `backend/` — Node API (OTP default 123456 in non-prod, media, jobs, chat, notifications)

## Backend
```powershell
cd backend
copy .env.example .env
# ensure: OTP_DEMO_CODE=123456
npm.cmd install
npx prisma db push
npx prisma db seed
npm.cmd run dev
```
API: http://0.0.0.0:4000  (use your PC IP for phones)

## Frontend (web pilot)
```powershell
cd frontend
# put logo files under assets/images if missing
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8081 --dart-define=API_BASE_URL=http://YOUR_PC_IP:4000
```

OTP for new accounts: **123456**

Demo logins:
- Client: 08012345678 / password123
- Artisan: 08023456789 / password123

## Logos
- assets/images/logo_full.png — wordmark (splash, login)
- assets/images/logo.png — icon mark

## Location
Pick a popular area (Ikeja etc.) then Continue. Live GPS is limited on web.

## Android APK
See frontend/android_templates/ if you need hardened Gradle files (AGP 8.11.1, desugar, no NDK pin).
Network access to Maven/Gradle is required for the first APK build.
