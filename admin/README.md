# WhoseNearby Admin (standalone)

This is **not** part of the Flutter app. It is a separate browser dashboard that talks to your API.

## Requirements
- Backend API running (`npm run dev` in `backend/`)
- `ADMIN_API_KEY` set in `backend/.env`

## Run (pick one)

### Option A — simple static server (recommended)
```powershell
cd admin
npx --yes serve -p 5050
```
Open: **http://127.0.0.1:5050**

### Option B — VS Code / Cursor “Live Server”
Right‑click `index.html` → Open with Live Server.

### Option C — still available on the API (optional)
If the API is running with the bundled static files:
**http://127.0.0.1:4000/admin-ui**

## Login
| Field | Example |
|--------|---------|
| Admin API key | Same as `ADMIN_API_KEY` in `backend/.env` |
| API base URL | `http://127.0.0.1:4000` or `http://YOUR_PC_IP:4000` |

## What it does
- Stats
- Approve / reject artisan verifications
- Resolve disputes (refund client / pay artisan / close)
- Review reports

No Flutter build needed. Keep the admin key private.
