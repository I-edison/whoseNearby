# WhoseNearby — Public testing guide

## What this build is for
Share with testers (clients + artisans) so they can register, find nearby artisans, chat, pay into hold, and release payment when work is done.

## Before you invite anyone

### 1. Backend (API) on a reachable machine
```bash
cd backend
cp .env.example .env
# Edit .env:
#   JWT_SECRET=<long random 32+ characters>
#   OTP_DEMO_CODE=123456          # keep for closed beta, or wire real SMS later
#   OTP_EXPOSE_CODE=false         # never true for public
#   DATABASE_URL=file:./dev.db    # SQLite is fine for small beta
#   CORS_ORIGIN=*                 # or your app origin

npm install
npx prisma db push
npm run dev
# API should answer http://YOUR_PUBLIC_IP:4000/health
```

Open port **4000** (or put nginx in front). Phone/testers must reach this host from their network.

### 2. App (Flutter)
**Option A — Web (fastest for mixed testers)**
```bash
cd frontend
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8081 \
  --dart-define=API_BASE_URL=http://YOUR_PUBLIC_IP:4000
```
Testers open `http://YOUR_PUBLIC_IP:8081`

**Option B — Android APK**
```bash
cd frontend
flutter pub get
flutter build apk --release \
  --dart-define=API_BASE_URL=http://YOUR_PUBLIC_IP:4000
# Output: build/app/outputs/flutter-apk/app-release.apk
```
Share the APK. Testers must allow “install from unknown sources”.

**Option C — iOS** needs a Mac + Apple developer account (TestFlight).

### 3. Must-do checklist
- [ ] `npx prisma db push` after pulling this zip (adds `Notification.data` + `User.coverUrl`)
- [ ] JWT_SECRET is not `change-me-...`
- [ ] OTP_EXPOSE_CODE=false for real users
- [ ] API IP/hostname is reachable from tester phones (not only `localhost`)
- [ ] At least one client account + one artisan account smoke-tested on the same network

## Test script for volunteers

| Role | Steps |
|------|--------|
| **Client** | Register → set location → Fund wallet ₦5,000 → Set PIN → Find artisan → Chat → Agree amount → Confirm & pay → After work, enter 6-digit code → Rate |
| **Artisan** | Register as artisan / complete onboarding → Go available → Accept job from inbox → Chat → Share completion code only when work is done → Check wallet after client confirms |

OTP for closed beta: **123456**

## Known beta limits
- OTP is demo code unless you plug Termii / Africa’s Talking
- Wallet “Fund” is a demo top-up (not real bank rails)
- Local push alerts need a real device (web browsers often block them); in-app **Alerts** tab still lists notifications
- SQLite is fine for ~tens of concurrent testers; move to Postgres for scale

## If something breaks
1. **Confirm & pay Prisma / notifications empty** → run `npx prisma db push` and restart API  
2. **Cover image error** → same db push; then change cover again on Profile  
3. **Money still “on hold” after release** → pull-to-refresh Wallet; job must be status COMPLETED (client entered correct 6-digit code)  
4. **Cannot reach API** → phone and server not on same network / firewall / wrong API_BASE_URL  

## Support contact
Put your WhatsApp / email here before sharing.
