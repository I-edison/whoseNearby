# WhoseNearby — complete update pack

## Apply (Windows)
```powershell
# Extract this zip over your project (or use as the project root)

cd backend
copy .env.example .env
# Edit .env: JWT_SECRET, Twilio, Paystack, ADMIN_API_KEY, etc.
npx prisma db push
npm install
npm run dev

cd ..\frontend
flutter pub get
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8081 --dart-define=API_BASE_URL=http://YOUR_PC_IP:4000

# APK (one line):
flutter build apk --release --dart-define=API_BASE_URL=http://YOUR_PC_IP:4000
```

## Twilio SMS OTP
```env
OTP_PROVIDER=twilio
TWILIO_ACCOUNT_SID=...
TWILIO_AUTH_TOKEN=...
TWILIO_FROM_NUMBER=+1...
OTP_EXPOSE_CODE=false
```
See backend/TWILIO_SETUP.md

## Docs
- FEATURES_ADDED.md — full feature list
- PUBLIC_TEST.md — tester guide
- backend/TWILIO_SETUP.md — SMS setup
