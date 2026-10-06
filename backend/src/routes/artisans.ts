import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { haversineKm } from '../utils/auth';
import { requireAuth, AuthRequest } from '../middleware/auth';

const router = Router();

// Nearby / search verified artisans
router.get('/', async (req, res, next) => {
  try {
    const skill = (req.query.skill as string | undefined)?.trim();
    const q = ((req.query.q as string | undefined) || (req.query.name as string | undefined) || '').trim();
    const lat = req.query.lat ? Number(req.query.lat) : undefined;
    const lng = req.query.lng ? Number(req.query.lng) : undefined;
    const radiusKm = req.query.radius ? Number(req.query.radius) : 5;
    const availableOnly = req.query.available === 'true';

    const search = q || skill || '';

    const profiles = await prisma.artisanProfile.findMany({
      where: {
        verificationStatus: 'APPROVED',
        ...(availableOnly ? { isAvailable: true } : {}),
        ...(search
          ? {
              OR: [
                { primarySkill: { contains: search } },
                { businessName: { contains: search } },
                { user: { fullName: { contains: search } } },
              ],
            }
          : {}),
      },
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            city: true,
            area: true,
            latitude: true,
            longitude: true,
            avatarLetter: true,
            avatarUrl: true,
          },
        },
      },
      orderBy: { ratingAvg: 'desc' },
    });

    let results = profiles.map((p) => {
      let distanceKm: number | null = null;
      if (
        lat != null &&
        lng != null &&
        p.user.latitude != null &&
        p.user.longitude != null
      ) {
        distanceKm = haversineKm(
          lat,
          lng,
          p.user.latitude,
          p.user.longitude
        );
      }
      return {
        id: p.id,
        userId: p.userId,
        businessName: p.businessName,
        primarySkill: p.primarySkill,
        bio: p.bio,
        hourlyRate: p.hourlyRate,
        isAvailable: p.isAvailable,
        jobsDone: p.jobsDone,
        ratingAvg: p.ratingAvg,
        ratingCount: p.ratingCount,
        verificationStatus: p.verificationStatus,
        city: p.user.city,
        area: p.user.area,
        avatarLetter: p.user.avatarLetter,
        avatarUrl: p.user.avatarUrl,
        portfolio: (() => {
          try {
            return p.portfolioJson ? JSON.parse(p.portfolioJson) : [];
          } catch {
            return [];
          }
        })(),
        distanceKm: distanceKm != null ? Math.round(distanceKm * 10) / 10 : null,
      };
    });

    // Show everyone — sort by distance when we know the viewer's location.
    // Artisans without coordinates sink to the end (not excluded).
    results = results.sort((a, b) => {
      const da = a.distanceKm;
      const db = b.distanceKm;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da - db;
    });

    res.json({ artisans: results, count: results.length });
  } catch (e) {
    next(e);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const p = await prisma.artisanProfile.findUnique({
      where: { id: req.params.id },
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            city: true,
            area: true,
            latitude: true,
            longitude: true,
            avatarLetter: true,
            avatarUrl: true,
          },
        },
        ratings: {
          take: 10,
          orderBy: { createdAt: 'desc' },
          include: {
            client: { select: { fullName: true, avatarLetter: true } },
          },
        },
      },
    });
    if (!p) return res.status(404).json({ error: 'Artisan not found' });
    let portfolio: string[] = [];
    try {
      portfolio = p.portfolioJson ? JSON.parse(p.portfolioJson) : [];
    } catch {
      portfolio = [];
    }
    res.json({ ...p, portfolio });
  } catch (e) {
    next(e);
  }
});

// Current user's artisan profile
router.get('/profile', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const profile = await prisma.artisanProfile.findUnique({
      where: { userId: req.userId! },
      include: {
        user: {
          select: { fullName: true, city: true, area: true, avatarLetter: true },
        },
      },
    });
    if (!profile) return res.status(404).json({ error: 'No artisan profile' });
    res.json(profile);
  } catch (e) {
    next(e);
  }
});

// Create / update artisan profile (become provider)
// Create / update artisan profile (become provider)
router.post('/profile', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const data = z
      .object({
        businessName: z.string().min(2),
        primarySkill: z.string().min(2),
        bio: z.string().optional(),
        hourlyRate: z.number().positive().optional(),
      })
      .parse(req.body);

    const existing = await prisma.artisanProfile.findUnique({
      where: { userId: req.userId! },
    });

    if (existing) {
      const updated = await prisma.artisanProfile.update({
        where: { userId: req.userId! },
        data,
      });
      return res.json(updated);
    }

    const profile = await prisma.artisanProfile.create({
      data: {
        ...data,
        userId: req.userId!,
        verificationStatus: 'APPROVED', // auto-approve for MVP testing
      } as any,
    });

    await prisma.user.update({
      where: { id: req.userId! },
      data: { role: 'BOTH' },
    });

    res.status(201).json(profile);
  } catch (e) {
    next(e);
  }
});

router.patch('/profile/availability', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const { isAvailable } = z.object({ isAvailable: z.boolean() }).parse(req.body);
    const profile = await prisma.artisanProfile.update({
      where: { userId: req.userId! },
      data: { isAvailable },
    });
    res.json(profile);
  } catch (e) {
    next(e);
  }
});

// Demo: team approves verification
router.post('/:id/verify', requireAuth, async (req, res, next) => {
  try {
    const profile = await prisma.artisanProfile.update({
      where: { id: req.params.id },
      data: { verificationStatus: 'APPROVED' },
    });
    res.json(profile);
  } catch (e) {
    next(e);
  }
});


/** POST /artisans/me/verification — submit ID for review */
router.post('/me/verification', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const data = z
      .object({
        idDocUrl: z.string().min(3),
        selfieUrl: z.string().optional(),
        note: z.string().optional(),
      })
      .parse(req.body);
    const profile = await prisma.artisanProfile.findUnique({ where: { userId: req.userId! } });
    if (!profile) return res.status(400).json({ error: 'Create artisan profile first' });
    const updated = await prisma.artisanProfile.update({
      where: { id: profile.id },
      data: {
        idDocUrl: data.idDocUrl,
        selfieUrl: data.selfieUrl || null,
        verificationStatus: 'PENDING',
        verificationNote: data.note || null,
      },
    });
    res.json({ profile: updated, message: 'Submitted for review' });
  } catch (e) {
    next(e);
  }
});

/** PATCH /artisans/me/skills — primary + extra skills */
router.patch('/me/skills', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const data = z
      .object({
        primarySkill: z.string().min(2),
        skills: z.array(z.string()).max(12).optional(),
      })
      .parse(req.body);
    const profile = await prisma.artisanProfile.findUnique({ where: { userId: req.userId! } });
    if (!profile) return res.status(400).json({ error: 'No artisan profile' });
    const skills = data.skills?.length ? data.skills : [data.primarySkill];
    if (!skills.includes(data.primarySkill)) skills.unshift(data.primarySkill);
    const updated = await prisma.artisanProfile.update({
      where: { id: profile.id },
      data: {
        primarySkill: data.primarySkill,
        skillsJson: JSON.stringify(skills),
      },
    });
    res.json({ profile: updated, skills });
  } catch (e) {
    next(e);
  }
});


router.get('/:id/ratings', async (req, res, next) => {
  try {
    const list = await prisma.rating.findMany({
      where: { artisanId: req.params.id },
      include: {
        client: { select: { fullName: true, avatarLetter: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 30,
    });
    res.json({ ratings: list });
  } catch (e) {
    next(e);
  }
});

export default router;
