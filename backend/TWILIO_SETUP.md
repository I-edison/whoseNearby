# Twilio OTP setup

## 1. Put secrets only in `backend/.env` (never commit this file)

```env
OTP_PROVIDER=twilio
TWILIO_ACCOUNT_SID=AC................................
TWILIO_AUTH_TOKEN=your_auth_token_here
TWILIO_FROM_NUMBER=+1..........
OTP_EXPOSE_CODE=false
OTP_DEMO_CODE=
```

## 2. From number
In [Twilio Console](https://console.twilio.com) → Phone Numbers → buy or use a trial number.
Trial accounts can only SMS **verified** destination numbers.

## 3. Restart API
```powershell
cd backend
npm run dev
```

## 4. Security
If Account SID / Auth Token were shared in chat or a screenshot, **rotate the Auth Token** in Twilio Console → Account → API keys & tokens.
