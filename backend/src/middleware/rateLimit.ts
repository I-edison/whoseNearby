import { Request, Response, NextFunction } from 'express';

type Bucket = { count: number; resetAt: number };

const buckets = new Map<string, Bucket>();

/**
 * Simple in-memory rate limiter (per process).
 * For multi-instance production, use Redis-backed limits.
 */
export function rateLimit(opts: {
  windowMs: number;
  max: number;
  keyFn?: (req: Request) => string;
  message?: string;
}) {
  const { windowMs, max, message = 'Too many requests. Try again later.' } = opts;
  const keyFn = opts.keyFn ?? ((req) => req.ip || 'unknown');

  return (req: Request, res: Response, next: NextFunction) => {
    const key = `${req.path}:${keyFn(req)}`;
    const now = Date.now();
    let b = buckets.get(key);
    if (!b || now > b.resetAt) {
      b = { count: 0, resetAt: now + windowMs };
      buckets.set(key, b);
    }
    b.count += 1;
    res.setHeader('X-RateLimit-Limit', String(max));
    res.setHeader('X-RateLimit-Remaining', String(Math.max(0, max - b.count)));
    if (b.count > max) {
      return res.status(429).json({ error: message });
    }
    next();
  };
}

// Periodic cleanup
setInterval(() => {
  const now = Date.now();
  for (const [k, b] of buckets) {
    if (now > b.resetAt) buckets.delete(k);
  }
}, 60_000).unref?.();
