import { Router } from 'express';
import { z } from 'zod';
import { randomInt } from 'crypto';
import { prisma } from '../utils/prisma';
import {
  hashPassword,
  verifyPassword,
  signToken,
} from '../utils/auth';
import { requireAuth, AuthRequest } from '../middleware/auth';
import { sendOtpSms } from '../services/otpProvider';

const router = Router();

/** Normalize phone/email so "0801 234 5678" and "08012345678" match. */
function normalizeTarget(raw: string): string {
  const t = raw.trim();
  if (t.includes('@')) return t.toLowerCase();
  // phone: keep digits only (and leading + if present)
  const digits = t.replace(/[^\d+]/g, '');
  return digits.startsWith('+') ? digits : digits.replace(/^\+/, '');
}

/** True when we have a real email/SMS delivery path (not just console). */
function isLiveDelivery(target: string): boolean {
  const isEmail = target.includes('@');
  if (isEmail) {
    return !!(
      process.env.RESEND_API_KEY ||
      (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS)
    );
  }
  const provider = (process.env.OTP_PROVIDER || 'console').toLowerCase();
  return (
    (provider === 'twilio' &&
      !!process.env.TWILIO_ACCOUNT_SID &&
      !!process.env.TWILIO_AUTH_TOKEN &&
      !!process.env.TWILIO_FROM_NUMBER) ||
    (provider === 'termii' && !!process.env.TERMII_API_KEY) ||
    (provider === 'africastalking' &&
      !!process.env.AT_API_KEY &&
      !!process.env.AT_USERNAME)
  );
}

const registerSchema = z.object({
  fullName: z.string().min(2),
  email: z.string().email().optional(),
  phone: z.string().min(10).optional(),
  password: z.string().min(6),
  role: z.enum(['CLIENT', 'ARTISAN', 'BOTH']).optional(),
  city: z.string().optional(),
  area: z.string().optional(),
  latitude: z.number().optional(),
  longitude: z.number().optional(),
});

router.post('/register', async (req, res, next) => {
  try {
    const data = registerSchema.parse(req.body);
    const email = data.email ? normalizeTarget(data.email) : undefined;
    const phone = data.phone ? normalizeTarget(data.phone) : undefined;
    if (!email && !phone) {
      return res.status(400).json({ error: 'Email or phone required' });
    }

    const existing = await prisma.user.findFirst({
      where: {
        OR: [
          email ? { email } : {},
          phone ? { phone } : {},
        ].filter((o) => Object.keys(o).length > 0),
      },
    });
    if (existing) {
      return res.status(409).json({ error: 'Account already exists' });
    }

    // Do NOT create User yet — wait until OTP succeeds (avoids orphan accounts).
    const passwordHash = await hashPassword(data.password);
    const target = phone || email!;
    const ttlMinutes = Number(process.env.OTP_TTL_MINUTES) || 5;
    const expiresAt = new Date(Date.now() + ttlMinutes * 60 * 1000);

    await prisma.pendingSignup.upsert({
      where: { target },
      create: {
        target,
        fullName: data.fullName,
        email: email || null,
        phone: phone || null,
        passwordHash,
        role: data.role || 'CLIENT',
        city: data.city,
        area: data.area,
        latitude: data.latitude,
        longitude: data.longitude,
        expiresAt,
      },
      update: {
        fullName: data.fullName,
        email: email || null,
        phone: phone || null,
        passwordHash,
        role: data.role || 'CLIENT',
        city: data.city,
        area: data.area,
        latitude: data.latitude,
        longitude: data.longitude,
        expiresAt,
      },
    });

    // Issue OTP for this target
    await prisma.otpCode.updateMany({
      where: { target, used: false },
      data: { used: true },
    });

    const live = isLiveDelivery(target);
    const forceDemo = process.env.OTP_FORCE_DEMO === 'true';
    const demoRaw = (process.env.OTP_DEMO_CODE || '').trim();
    const useDemo =
      forceDemo ||
      (!live && demoRaw && /^\d{6}$/.test(demoRaw)) ||
      (!live && !demoRaw && process.env.NODE_ENV !== 'production');

    const code = useDemo
      ? demoRaw && /^\d{6}$/.test(demoRaw)
        ? demoRaw
        : '123456'
      : String(randomInt(100000, 1000000));

    await prisma.otpCode.create({ data: { target, code, expiresAt } });
    console.log(
      `[OTP] signup live=${live} target=${target} code=${live ? '(hidden)' : code}`
    );
    try {
      await sendOtpSms(target, code);
    } catch (err) {
      console.error('OTP delivery failed:', err);
      if (live || process.env.NODE_ENV === 'production') {
        return res.status(502).json({
          error:
            err instanceof Error
              ? `Could not send OTP: ${err.message}`
              : 'Could not send OTP. Try again.',
        });
      }
    }

    const expose =
      !live &&
      process.env.OTP_EXPOSE_CODE !== 'false' &&
      process.env.NODE_ENV !== 'production';

    const channel = target.includes('@') ? 'email' : 'sms';

    res.status(200).json({
      needsOtp: true,
      target,
      channel,
      message: `Verify the code sent to your ${channel} to finish creating your account`,
      expiresInSeconds: ttlMinutes * 60,
      ...(expose ? { code } : {}),
    });
  } catch (e) {
    next(e);
  }
});

const loginSchema = z.object({
  identifier: z.string().min(3), // email or phone
  password: z.string().min(1),
});

router.post('/login', async (req, res, next) => {
  try {
    const { identifier, password } = loginSchema.parse(req.body);
    const id = normalizeTarget(identifier);
    const user = await prisma.user.findFirst({
      where: {
        OR: [{ email: id }, { phone: id }],
      },
    });
    if (!user || !(await verifyPassword(password, user.passwordHash))) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = signToken({ userId: user.id, role: user.role });
    res.json({
      user: {
        id: user.id,
        fullName: user.fullName,
        email: user.email,
        phone: user.phone,
        role: user.role,
        city: user.city,
        area: user.area,
        avatarLetter: user.avatarLetter,
        emailVerified: user.emailVerified ?? false,
      },
      token,
    });
  } catch (e) {
    next(e);
  }
});

// OTP — valid for a few minutes
router.post('/otp/request', async (req, res, next) => {
  try {
    const body = z.object({ target: z.string().min(5) }).parse(req.body);
    const target = normalizeTarget(body.target);
    if (target.length < 5) {
      return res.status(400).json({ error: 'Invalid phone or email' });
    }

    await prisma.otpCode.updateMany({
      where: { target, used: false },
      data: { used: true },
    });

    const live = isLiveDelivery(target);
    const forceDemo = process.env.OTP_FORCE_DEMO === 'true';
    const demoRaw = (process.env.OTP_DEMO_CODE || '').trim();
    const useDemo =
      forceDemo ||
      (!live && demoRaw && /^\d{6}$/.test(demoRaw)) ||
      (!live && !demoRaw && process.env.NODE_ENV !== 'production');

    const code = useDemo
      ? demoRaw && /^\d{6}$/.test(demoRaw)
        ? demoRaw
        : '123456'
      : String(randomInt(100000, 1000000));

    const ttlMinutes = Number(process.env.OTP_TTL_MINUTES) || 5;
    const expiresAt = new Date(Date.now() + ttlMinutes * 60 * 1000);

    await prisma.otpCode.create({ data: { target, code, expiresAt } });

    console.log(
      `[OTP] live=${live} target=${target} code=${live ? '(hidden)' : code}`
    );
    try {
      await sendOtpSms(target, code);
    } catch (err) {
      console.error('OTP delivery failed:', err);
      if (live || process.env.NODE_ENV === 'production') {
        return res.status(502).json({
          error:
            err instanceof Error
              ? `Could not send OTP: ${err.message}`
              : 'Could not send OTP. Try again.',
        });
      }
    }

    const expose =
      !live &&
      process.env.OTP_EXPOSE_CODE !== 'false' &&
      process.env.NODE_ENV !== 'production';

    const channel = target.includes('@') ? 'email' : 'sms';

    res.json({
      message: live
        ? `OTP sent by ${channel}`
        : 'OTP sent',
      channel,
      expiresInSeconds: ttlMinutes * 60,
      ...(expose ? { code } : {}),
    });
  } catch (e) {
    next(e);
  }
});

router.post('/otp/verify', async (req, res, next) => {
  try {
    const body = z
      .object({
        target: z.string(),
        code: z.string().min(4).max(8),
      })
      .parse(req.body);

    const target = normalizeTarget(body.target);
    const code = body.code.replace(/\s/g, '');

    if (!/^\d{6}$/.test(code)) {
      return res.status(400).json({ error: 'Enter the 6-digit code' });
    }

    const otp = await prisma.otpCode.findFirst({
      where: {
        target,
        code,
        used: false,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!otp) {
      return res.status(400).json({ error: 'Invalid or expired OTP' });
    }

    await prisma.otpCode.update({
      where: { id: otp.id },
      data: { used: true },
    });

    // Complete pending signup → create User only now
    const pending = await prisma.pendingSignup.findUnique({ where: { target } });
    if (pending) {
      if (pending.expiresAt < new Date()) {
        await prisma.pendingSignup.delete({ where: { id: pending.id } });
        return res.status(400).json({ error: 'Signup expired. Register again.' });
      }

      const stillExists = await prisma.user.findFirst({
        where: {
          OR: [
            pending.email ? { email: pending.email } : {},
            pending.phone ? { phone: pending.phone } : {},
          ].filter((o) => Object.keys(o).length > 0),
        },
      });
      if (stillExists) {
        await prisma.pendingSignup.delete({ where: { id: pending.id } });
        return res.status(409).json({ error: 'Account already exists. Please log in.' });
      }

      const avatarLetter = pending.fullName.trim()[0]?.toUpperCase() || 'U';
      const user = await prisma.user.create({
        data: {
          fullName: pending.fullName,
          email: pending.email,
          phone: pending.phone,
          passwordHash: pending.passwordHash,
          role: pending.role || 'CLIENT',
          city: pending.city,
          area: pending.area,
          latitude: pending.latitude,
          longitude: pending.longitude,
          avatarLetter,
          // Email is verified only when the OTP target was the email itself
          emailVerified: !!pending.email && target === pending.email,
          wallet: { create: { balance: 0 } },
        },
        select: {
          id: true,
          fullName: true,
          email: true,
          phone: true,
          role: true,
          city: true,
          area: true,
          avatarLetter: true,
          emailVerified: true,
        },
      });
      await prisma.pendingSignup.delete({ where: { id: pending.id } });
      const token = signToken({ userId: user.id, role: user.role });
      return res.json({ verified: true, created: true, user, token });
    }

    // Existing user verifying email (target is their email)
    if (target.includes('@')) {
      const user = await prisma.user.findFirst({ where: { email: target } });
      if (user && !user.emailVerified) {
        await prisma.user.update({
          where: { id: user.id },
          data: { emailVerified: true },
        });
        return res.json({ verified: true, emailVerified: true });
      }
    }

    res.json({ verified: true });
  } catch (e) {
    next(e);
  }
});

router.get('/me', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.userId },
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        role: true,
        city: true,
        area: true,
        latitude: true,
        longitude: true,
        avatarLetter: true,
        avatarUrl: true,
        coverUrl: true,
        emailVerified: true,
        artisanProfile: true,
        wallet: { select: { id: true, balance: true, pinHash: true } },
      },
    });
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json({
      ...user,
      wallet: user.wallet
        ? {
            id: user.wallet.id,
            balance: user.wallet.balance,
            hasPin: !!user.wallet.pinHash,
          }
        : null,
    });
  } catch (e) {
    next(e);
  }
});

// Update profile / location
router.patch('/me', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const data = z
      .object({
        fullName: z.string().min(2).optional(),
        city: z.string().optional(),
        area: z.string().optional(),
        latitude: z.number().optional(),
        longitude: z.number().optional(),
        role: z.enum(['CLIENT', 'ARTISAN', 'BOTH']).optional(),
      })
      .parse(req.body);

    const user = await prisma.user.update({
      where: { id: req.userId! },
      data,
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        role: true,
        city: true,
        area: true,
        latitude: true,
        longitude: true,
        avatarLetter: true,
        avatarUrl: true,
        coverUrl: true,
        emailVerified: true,
      },
    });
    res.json(user);
  } catch (e) {
    next(e);
  }
});

export default router;