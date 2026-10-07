/**
 * OTP delivery providers.
 * Set OTP_PROVIDER=twilio | termii | africastalking | console (default)
 *
 * Email targets (contain @):
 *   - RESEND_API_KEY  → sends via Resend
 *   - or SMTP_HOST + SMTP_USER + SMTP_PASS → sends via Nodemailer
 *   - otherwise logs to console (demo)
 */

export async function sendOtpSms(target: string, code: string): Promise<void> {
  const provider = (process.env.OTP_PROVIDER || 'console').toLowerCase();
  const isPhone = !target.includes('@');

  if (!isPhone) {
    await sendOtpEmail(target, code);
    return;
  }

  if (provider === 'twilio') {
    await sendTwilio(target, code);
    return;
  }
  if (provider === 'termii') {
    await sendTermii(target, code);
    return;
  }
  if (provider === 'africastalking') {
    await sendAfricasTalking(target, code);
    return;
  }

  console.log(`[OTP console → ${target}] code=${code}`);
}

/** Send OTP by email (Resend → SMTP → console fallback) */
async function sendOtpEmail(email: string, code: string): Promise<void> {
  const from =
    process.env.EMAIL_FROM || 'WhoseNearby <noreply@whosenearby.local>';
  const subject = 'Your WhoseNearby verification code';
  const text = `Your WhoseNearby code is ${code}.\n\nValid for a few minutes. Do not share it.`;
  const html = `
    <div style="font-family:sans-serif;max-width:420px;margin:0 auto;">
      <p>Your <strong>WhoseNearby</strong> verification code is:</p>
      <p style="font-size:28px;font-weight:bold;letter-spacing:6px;margin:16px 0;">${code}</p>
      <p style="color:#666;font-size:14px;">Valid for a few minutes. Do not share it with anyone.</p>
    </div>
  `;

  // 1) Resend (recommended)
  if (process.env.RESEND_API_KEY) {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ from, to: email, subject, html, text }),
    });
    if (!res.ok) {
      const t = await res.text();
      throw new Error(`Resend failed: ${res.status} ${t}`);
    }
    console.log(`[OTP email → ${email}] sent via Resend`);
    return;
  }

  // 2) SMTP via Nodemailer
  if (process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS) {
    const nodemailer = await import('nodemailer');
    const transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT || 587),
      secure: process.env.SMTP_SECURE === 'true',
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
    await transporter.sendMail({ from, to: email, subject, text, html });
    console.log(`[OTP email → ${email}] sent via SMTP`);
    return;
  }

  // 3) Demo / local — just log
  console.log(`[OTP email → ${email}] code=${code}`);
}

/** E.164-ish: Nigeria 0XXXXXXXXXX → +234XXXXXXXXXX */
function normalizePhone(phone: string): string {
  let to = phone.replace(/[\s()-]/g, '');
  if (to.startsWith('00')) to = '+' + to.slice(2);
  if (to.startsWith('0') && to.length >= 10) to = '+234' + to.slice(1);
  if (!to.startsWith('+')) to = '+' + to;
  return to;
}

async function sendTwilio(phone: string, code: string) {
  const accountSid = process.env.TWILIO_ACCOUNT_SID || '';
  const authToken = process.env.TWILIO_AUTH_TOKEN || '';
  const from = process.env.TWILIO_FROM_NUMBER || '';

  if (!accountSid || !authToken) {
    throw new Error('TWILIO_ACCOUNT_SID / TWILIO_AUTH_TOKEN not configured');
  }
  if (!from) {
    throw new Error(
      'TWILIO_FROM_NUMBER not configured (buy/verify a number in Twilio Console)'
    );
  }

  const to = normalizePhone(phone);
  const url = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
  const body = new URLSearchParams({
    To: to,
    From: from,
    Body: `Your WhoseNearby code is ${code}. Valid for a few minutes. Do not share it.`,
  });

  const basic = Buffer.from(`${accountSid}:${authToken}`).toString('base64');
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${basic}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Twilio failed: ${res.status} ${text}`);
  }
}

async function sendTermii(phone: string, code: string) {
  const apiKey = process.env.TERMII_API_KEY;
  const sender = process.env.TERMII_SENDER_ID || 'WhoseNear';
  if (!apiKey) throw new Error('TERMII_API_KEY not configured');

  let to = phone.replace(/\s/g, '');
  if (to.startsWith('0')) to = '234' + to.slice(1);
  if (to.startsWith('+')) to = to.slice(1);

  const res = await fetch('https://api.ng.termii.com/api/sms/send', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      to,
      from: sender,
      sms: `Your WhoseNearby code is ${code}. Valid for a few minutes.`,
      type: 'plain',
      channel: 'generic',
      api_key: apiKey,
    }),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Termii failed: ${res.status} ${text}`);
  }
}

async function sendAfricasTalking(phone: string, code: string) {
  const apiKey = process.env.AT_API_KEY;
  const username = process.env.AT_USERNAME;
  const from = process.env.AT_SENDER_ID || 'WhoseNear';
  if (!apiKey || !username) throw new Error('AT_API_KEY / AT_USERNAME not configured');

  const to = normalizePhone(phone);

  const body = new URLSearchParams({
    username,
    to,
    message: `Your WhoseNearby code is ${code}. Valid for a few minutes.`,
    from,
  });

  const res = await fetch('https://api.africastalking.com/version1/messaging', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      apiKey,
      Accept: 'application/json',
    },
    body,
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Africa's Talking failed: ${res.status} ${text}`);
  }
}