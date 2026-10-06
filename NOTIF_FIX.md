# Notification fix — apply on top of your project

## Why Alerts showed "all caught up"
1. Notification rows often failed to save (missing `data` column) and errors were swallowed.
2. After paying, only the *artisan* got an alert — the *client* saw an empty list.
3. Alerts tab did not auto-refresh.

## What changed
- `notifyUser` retries without `data` if the DB is old
- Client + artisan both get alerts on fund and on job complete
- Chat messages use the same safe helper
- Alerts tab polls every 10s + clearer empty text

## Apply
1. Copy these folders over your project (or unzip this pack fully):
   - backend/src/utils/notify.ts
   - backend/src/routes/jobs.ts
   - backend/src/routes/chat.ts
   - frontend/lib/screens/job/notifications_screen.dart

2. In backend:
```powershell
cd backend
npx prisma db push
# stop and restart API
npm run dev
```

3. Hot restart / rebuild the app.

4. Test:
   - As artisan: accept a job → client should see "Artisan joined"
   - As client: fund job → client sees "Payment on hold", artisan sees "Job funded"
   - Send a chat message → other person sees "New message" in Alerts
   - Pull down on Alerts or wait ~10s to refresh

Check the API terminal for "notifyUser failed" — if you still see Prisma errors, `db push` did not run against the DB the server is using.
