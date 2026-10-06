import fs from 'fs';
import path from 'path';
import { randomBytes } from 'crypto';

const UPLOAD_DIR = path.join(process.cwd(), 'uploads');
const MAX_BYTES = Number(process.env.UPLOAD_MAX_BYTES) || 5 * 1024 * 1024; // 5MB

export function ensureUploadDir() {
  if (!fs.existsSync(UPLOAD_DIR)) {
    fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  }
}

function detectImageType(buf: Buffer): 'jpg' | 'png' | 'webp' | 'gif' | null {
  if (buf.length < 12) return null;
  // JPEG
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) return 'jpg';
  // PNG
  if (
    buf[0] === 0x89 &&
    buf[1] === 0x50 &&
    buf[2] === 0x4e &&
    buf[3] === 0x47
  )
    return 'png';
  // GIF
  if (buf[0] === 0x47 && buf[1] === 0x49 && buf[2] === 0x46) return 'gif';
  // WEBP (RIFF....WEBP)
  if (
    buf[0] === 0x52 &&
    buf[1] === 0x49 &&
    buf[2] === 0x46 &&
    buf[3] === 0x46 &&
    buf[8] === 0x57 &&
    buf[9] === 0x45 &&
    buf[10] === 0x42 &&
    buf[11] === 0x50
  )
    return 'webp';
  return null;
}

/** Save a base64 data URL or raw base64 string; returns public path /uploads/xxx.ext */
export function saveBase64Image(
  input: string,
  _mimeHint?: string
): { filename: string; urlPath: string } {
  ensureUploadDir();

  let base64 = input;
  const dataUrl = /^data:(image\/[a-zA-Z0-9.+-]+);base64,(.+)$/s.exec(input);
  if (dataUrl) {
    base64 = dataUrl[2];
  }

  const buf = Buffer.from(base64, 'base64');
  if (buf.length > MAX_BYTES) {
    throw new Error(`Image too large (max ${Math.round(MAX_BYTES / 1024 / 1024)}MB)`);
  }
  if (buf.length < 32) {
    throw new Error('Invalid image data');
  }

  const kind = detectImageType(buf);
  if (!kind) {
    throw new Error('Only JPEG, PNG, WebP, or GIF images are allowed');
  }

  const filename = `${Date.now()}-${randomBytes(6).toString('hex')}.${kind}`;
  fs.writeFileSync(path.join(UPLOAD_DIR, filename), buf);
  return { filename, urlPath: `/uploads/${filename}` };
}
