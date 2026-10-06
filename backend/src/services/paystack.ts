/**
 * Paystack — primary payment provider for WhoseNearby.
 * Docs: https://paystack.com/docs/api
 */

const BASE = 'https://api.paystack.co';

function secret() {
  return (process.env.PAYSTACK_SECRET_KEY || '').trim();
}

export function paystackConfigured() {
  return secret().startsWith('sk_');
}

async function paystackFetch(path: string, init?: RequestInit) {
  const res = await fetch(`${BASE}${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${secret()}`,
      'Content-Type': 'application/json',
      ...(init?.headers || {}),
    },
  });
  const json = (await res.json()) as {
    status: boolean;
    message?: string;
    data?: Record<string, unknown>;
  };
  if (!res.ok || !json.status) {
    throw new Error(json.message || `Paystack error ${res.status}`);
  }
  return json.data || {};
}

export async function initializeDeposit(opts: {
  email: string;
  amountNaira: number;
  userId: string;
  callbackUrl?: string;
  metadata?: Record<string, string>;
}) {
  const amountKobo = Math.round(opts.amountNaira * 100);
  if (!paystackConfigured()) {
    const ref = `demo_${opts.userId.slice(0, 8)}_${Date.now()}`;
    return {
      demo: true as const,
      reference: ref,
      authorization_url: null as string | null,
      access_code: null as string | null,
      amount: opts.amountNaira,
      message: 'Demo mode: complete via POST /wallet/paystack/demo-complete',
    };
  }

  const data = await paystackFetch('/transaction/initialize', {
    method: 'POST',
    body: JSON.stringify({
      email: opts.email,
      amount: amountKobo,
      currency: 'NGN',
      callback_url: opts.callbackUrl,
      metadata: {
        userId: opts.userId,
        purpose: 'wallet_fund',
        ...(opts.metadata || {}),
      },
    }),
  });

  return {
    demo: false as const,
    reference: String(data.reference || ''),
    authorization_url: String(data.authorization_url || ''),
    access_code: data.access_code ? String(data.access_code) : null,
    amount: opts.amountNaira,
  };
}

export async function verifyTransaction(reference: string) {
  if (!paystackConfigured()) {
    return { success: true, amountNaira: 0, demo: true, reference, status: 'success' };
  }
  const data = await paystackFetch(`/transaction/verify/${encodeURIComponent(reference)}`);
  const status = String(data.status || '');
  const amountKobo = Number(data.amount || 0);
  return {
    success: status === 'success',
    amountNaira: amountKobo / 100,
    demo: false,
    reference: String(data.reference || reference),
    status,
    paidAt: data.paid_at,
    channel: data.channel,
  };
}

/** Verify webhook signature (x-paystack-signature) */
export function verifyPaystackSignature(rawBody: string, signature: string | undefined) {
  if (!signature || !secret()) return false;
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const crypto = require('crypto') as typeof import('crypto');
  const hash = crypto.createHmac('sha512', secret()).update(rawBody).digest('hex');
  return hash === signature;
}
