import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { requireAuth, AuthRequest } from '../middleware/auth';
import { saveBase64Image } from '../utils/uploads';

const router = Router();

const imageBody = z.object({
  imageBase64: z.string().min(64),
  mimeType: z.string().optional(),
});

/** POST /media/avatar — set current user's profile photo */
router.post('/avatar', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const { imageBase64, mimeType } = imageBody.parse(req.body);
    const { urlPath } = saveBase64Image(imageBase64, mimeType);
    const user = await prisma.user.update({
      where: { id: req.userId! },
      data: { avatarUrl: urlPath },
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        role: true,
        city: true,
        area: true,
        avatarLetter: true,
        avatarUrl: true,
      },
    });
    res.json({ user, avatarUrl: urlPath });
  } catch (e: unknown) {
    if (e instanceof Error && e.message.includes('too large')) {
      return res.status(400).json({ error: e.message });
    }
    next(e);
  }
});

/** DELETE /media/avatar */
router.delete('/avatar', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const user = await prisma.user.update({
      where: { id: req.userId! },
      data: { avatarUrl: null },
      select: {
        id: true,
        fullName: true,
        avatarUrl: true,
        avatarLetter: true,
      },
    });
    res.json({ user });
  } catch (e) {
    next(e);
  }
});

/** POST /media/portfolio — add image to artisan portfolio */
router.post('/portfolio', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const { imageBase64, mimeType } = imageBody.parse(req.body);
    const profile = await prisma.artisanProfile.findUnique({
      where: { userId: req.userId! },
    });
    if (!profile) {
      return res.status(400).json({ error: 'Create an artisan profile first' });
    }
    const { urlPath } = saveBase64Image(imageBase64, mimeType);
    let list: string[] = [];
    try {
      list = profile.portfolioJson ? JSON.parse(profile.portfolioJson) : [];
    } catch {
      list = [];
    }
    if (list.length >= 12) {
      return res.status(400).json({ error: 'Portfolio limit is 12 images' });
    }
    list.push(urlPath);
    const updated = await prisma.artisanProfile.update({
      where: { id: profile.id },
      data: { portfolioJson: JSON.stringify(list) },
    });
    res.json({ portfolio: list, profile: updated });
  } catch (e: unknown) {
    if (e instanceof Error && e.message.includes('too large')) {
      return res.status(400).json({ error: e.message });
    }
    next(e);
  }
});

/** DELETE /media/portfolio — remove by index */
router.delete('/portfolio/:index', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const index = Number(req.params.index);
    if (!Number.isInteger(index) || index < 0) {
      return res.status(400).json({ error: 'Invalid index' });
    }
    const profile = await prisma.artisanProfile.findUnique({
      where: { userId: req.userId! },
    });
    if (!profile) return res.status(404).json({ error: 'No artisan profile' });
    let list: string[] = [];
    try {
      list = profile.portfolioJson ? JSON.parse(profile.portfolioJson) : [];
    } catch {
      list = [];
    }
    if (index >= list.length) {
      return res.status(400).json({ error: 'Index out of range' });
    }
    list.splice(index, 1);
    await prisma.artisanProfile.update({
      where: { id: profile.id },
      data: { portfolioJson: JSON.stringify(list) },
    });
    res.json({ portfolio: list });
  } catch (e) {
    next(e);
  }
});


/** POST /media/cover — set current user's profile cover image */
router.post('/cover', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const { imageBase64, mimeType } = imageBody.parse(req.body);
    const { urlPath } = saveBase64Image(imageBase64, mimeType);
    const user = await prisma.user.update({
      where: { id: req.userId! },
      data: { coverUrl: urlPath },
      select: {
        id: true,
        fullName: true,
        avatarUrl: true,
        coverUrl: true,
        avatarLetter: true,
      },
    });
    res.json({ user, coverUrl: urlPath });
  } catch (e: unknown) {
    if (e instanceof Error && e.message.includes('too large')) {
      return res.status(400).json({ error: e.message });
    }
    next(e);
  }
});

/** DELETE /media/cover */
router.delete('/cover', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const user = await prisma.user.update({
      where: { id: req.userId! },
      data: { coverUrl: null },
      select: {
        id: true,
        fullName: true,
        avatarUrl: true,
        coverUrl: true,
        avatarLetter: true,
      },
    });
    res.json({ user });
  } catch (e) {
    next(e);
  }
});

export default router;
