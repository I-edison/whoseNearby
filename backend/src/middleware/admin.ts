import { Request, Response, NextFunction } from 'express';

/** Simple admin gate via header x-admin-key === ADMIN_API_KEY */
export function requireAdmin(req: Request, res: Response, next: NextFunction) {
  const key = process.env.ADMIN_API_KEY || '';
  if (!key || key.length < 8) {
    return res.status(503).json({ error: 'Admin not configured (set ADMIN_API_KEY)' });
  }
  const provided = req.header('x-admin-key') || '';
  if (provided !== key) {
    return res.status(401).json({ error: 'Invalid admin key' });
  }
  next();
}
