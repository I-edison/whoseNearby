# Features added in this pack

## Must-have (public readiness)
- **SMS OTP providers**: Termii + Africa's Talking (`OTP_PROVIDER`, keys in `.env`)
- **Paystack wallet top-up**: `POST /wallet/paystack/initialize` + verify; **demo-complete** when no secret key
- **Bank account + withdraw**: `PUT /wallet/bank`, withdraw requires bank details
- **Production guards**: JWT secret check, OTP expose warning
- **Legal**: `/terms`, `/privacy`, `/support` in app + `/legal/terms` `/legal/privacy` on API
- **Postgres note** in schema + `.env.example`

## Trust
- **Artisan verification submit**: `POST /artisans/me/verification` (PENDING → admin approve)
- **Admin API** (`x-admin-key`): stats, verifications, disputes resolve (refund/release), reports
- **Disputes**: `POST /trust/dispute` freezes job as DISPUTED; admin resolves
- **Report / block**: `POST /trust/report`, `POST /trust/block`
- **FCM token + push stub**: `POST /trust/fcm-token`; notifyUser tries FCM when `FCM_SERVER_KEY` set
- **Open jobs board**: `GET /jobs/open` + app screen **Browse open jobs**
- **Ratings list**: `GET /artisans/:id/ratings`

## Nice-to-have
- **Multiple skills**: `skillsJson` + `PATCH /artisans/me/skills`
- **Job photos field**: `photosJson` on Job (ready for uploads)
- **In-app Support / Terms / Privacy**
- **Bank screen** in wallet

## Still external (you configure)
1. Set `TERMII_API_KEY` or AT keys + `OTP_PROVIDER`
2. Set `PAYSTACK_SECRET_KEY` for live card funding
3. Set `ADMIN_API_KEY` and call `/admin/*` with header `x-admin-key`
4. Set `FCM_SERVER_KEY` + register device tokens from the app
5. Switch Prisma `provider` to `postgresql` for production hosting
6. Replace support WhatsApp/email with your real contacts
7. Store listing screenshots / final app icon when you publish

## Apply
```powershell
cd backend
npx prisma db push
npm run dev

cd ..\frontend
flutter pub get
# hot restart / rebuild APK
```
