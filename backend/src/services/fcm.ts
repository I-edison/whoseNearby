/**
 * FCM HTTP v1 stub. Set FCM_SERVER_KEY for legacy HTTP API.
 * Without a key, only logs (in-app notifications still work).
 */

export async function sendPush(opts: {
  token?: string | null;
  title: string;
  body: string;
  data?: Record<string, string>;
}) {
  if (!opts.token) return;
  const key = process.env.FCM_SERVER_KEY;
  if (!key) {
    console.log(`[FCM skip] ${opts.title}: ${opts.body}`);
    return;
  }
  try {
    await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        Authorization: `key=${key}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to: opts.token,
        notification: { title: opts.title, body: opts.body },
        data: opts.data || {},
      }),
    });
  } catch (e) {
    console.error('FCM send failed', e);
  }
}
