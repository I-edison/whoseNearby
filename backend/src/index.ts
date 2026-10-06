import 'dotenv/config';
import http from 'http';
import express from 'express';
import cors from 'cors';
import { errorHandler } from './middleware/error';
import authRoutes from './routes/auth';
import artisanRoutes from './routes/artisans';
import jobRoutes from './routes/jobs';
import walletRoutes from './routes/wallet';
import chatRoutes from './routes/chat';
import notificationRoutes from './routes/notifications';
import { createWsServer } from './ws/hub';
import mediaRoutes from './routes/media';
import adminRoutes from './routes/admin';
import trustRoutes from './routes/trust';
import path from 'path';
import { ensureUploadDir } from './utils/uploads';
import { rateLimit } from './middleware/rateLimit';

const app = express();
const PORT = Number(process.env.PORT) || 4000;

// Production guards
if (process.env.NODE_ENV === 'production') {
  const secret = process.env.JWT_SECRET || '';
  if (!secret || secret.length < 32 || secret.includes('change-me')) {
    console.error('FATAL: Set a strong JWT_SECRET (32+ chars) in production.');
    process.exit(1);
  }
  if (process.env.OTP_EXPOSE_CODE === 'true') {
    console.warn('WARNING: OTP_EXPOSE_CODE=true in production — codes may leak in API responses.');
  }
}


app.use(cors({ origin: process.env.CORS_ORIGIN || true }));
app.use(express.json({ limit: process.env.JSON_BODY_LIMIT || '6mb' }));
app.use((_req, res, next) => {
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  next();
});
ensureUploadDir();
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads')));

app.get('/', (_req, res) => {
  res.type('html').send(`<!doctype html>
<html><head><meta charset="utf-8"/><title>WhoseNearby API</title>
<style>
  body{font-family:system-ui,sans-serif;max-width:520px;margin:48px auto;padding:0 16px;color:#111}
  code{background:#f4f4f5;padding:2px 6px;border-radius:4px}
  a{color:#0d7a4f}
</style></head><body>
  <h1>WhoseNearby API</h1>
  <p>Server is running.</p>
  <p>Health check: <a href="/health"><code>/health</code></a></p>
  <p>This is the <strong>API</strong>, not the mobile app UI.
  Run the Flutter app and set <code>API_BASE_URL</code> to this host.</p>
</body></html>`);
});


app.get('/legal/terms', (_req, res) => {
  res.type('text').send(`WhoseNearby Terms of Use

1. WhoseNearby connects clients with local artisans. We are a marketplace platform, not the service provider.
2. Payments held in escrow are released when the client confirms job completion with the code, or by admin dispute resolution.
3. Users must provide accurate information. Fraud, harassment, or illegal work is prohibited.
4. Artisans are independent. WhoseNearby does not employ artisans.
5. Demo wallets and OTP codes may be used in beta; production uses real SMS and payment providers when configured.

Contact support via the in-app Support screen.
`);
});
app.get('/legal/privacy', (_req, res) => {
  res.type('text').send(`WhoseNearby Privacy Policy

We collect account details (name, phone/email), location (to show nearby artisans), chat messages for jobs, and payment metadata.
We do not sell your personal data.
Location is used to sort artisans by distance.
Payment card data is handled by Paystack when configured; we store wallet balances and transaction records only.
Contact support to request account deletion.
`);
});

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'whosenearby-api', ws: '/ws' });
});

app.use(
  '/auth/otp',
  rateLimit({ windowMs: 15 * 60 * 1000, max: 20, message: 'Too many OTP attempts' })
);
app.use(
  '/auth/login',
  rateLimit({ windowMs: 15 * 60 * 1000, max: 30, message: 'Too many login attempts' })
);
app.use(
  '/media',
  rateLimit({ windowMs: 60 * 60 * 1000, max: 60, message: 'Upload limit reached' })
);
app.use('/auth', authRoutes);
app.use('/artisans', artisanRoutes);
app.use('/jobs', jobRoutes);
app.use('/wallet', walletRoutes);
app.use('/chat', chatRoutes);
app.use('/notifications', notificationRoutes);
app.use('/media', mediaRoutes);
app.use('/admin', adminRoutes);
app.use('/trust', trustRoutes);

app.use(errorHandler);

const server = http.createServer(app);
createWsServer(server);

server.listen(PORT, '0.0.0.0', () => {
  console.log(`WhoseNearby API  http://localhost:${PORT}`);
  console.log(`WebSocket        ws://localhost:${PORT}/ws?token=JWT`);
  console.log(`LAN phones:      http://<YOUR_PC_IP>:${PORT}`);
});
