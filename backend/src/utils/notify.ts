import { prisma } from './prisma';
import { sendPush } from '../services/fcm';

/**
 * Persist an in-app notification. Never throws.
 * Retries without `data` if the column is missing (old DB).
 * Best-effort FCM if user has fcmToken.
 */
export async function notifyUser(opts: {
  userId: string;
  type: string;
  title: string;
  body: string;
  data?: Record<string, unknown>;
}) {
  if (!opts.userId) return;
  const base = {
    userId: opts.userId,
    type: opts.type,
    title: opts.title,
    body: opts.body,
  };
  try {
    await prisma.notification.create({
      data: {
        ...base,
        ...(opts.data ? { data: JSON.stringify(opts.data) } : {}),
      },
    });
  } catch {
    try {
      await prisma.notification.create({ data: base });
    } catch (e2) {
      console.error('notifyUser failed', e2);
    }
  }

  try {
    const user = await prisma.user.findUnique({
      where: { id: opts.userId },
      select: { fcmToken: true },
    });
    const dataStr: Record<string, string> = {};
    if (opts.data) {
      for (const [k, v] of Object.entries(opts.data)) {
        dataStr[k] = String(v);
      }
    }
    await sendPush({
      token: user?.fcmToken,
      title: opts.title,
      body: opts.body,
      data: dataStr,
    });
  } catch {
    // ignore push errors
  }
}
