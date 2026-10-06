import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { generateCompletionCode, verifyPassword } from '../utils/auth';
import { requireAuth, AuthRequest } from '../middleware/auth';
import { notifyUser } from '../utils/notify';

const router = Router();

// Post a job (client)
router.post('/', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const data = z
      .object({
        title: z.string().min(3),
        description: z.string().optional(),
        category: z.string().min(2),
        budgetMin: z.number().optional(),
        budgetMax: z.number().optional(),
        city: z.string().optional(),
        area: z.string().optional(),
        whenNeeded: z.string().optional(),
        artisanId: z.string().optional(),
      })
      .parse(req.body);

const job = await prisma.job.create({
  data: {
    ...data,
    clientId: req.userId!,
    status: data.artisanId ? 'NEGOTIATING' : 'OPEN',
  } as any,
});

    // Notify artisans who offer this skill (available + approved)
    if (!data.artisanId) {
      try {
        const skill = data.category.trim();
        const matches = await prisma.artisanProfile.findMany({
          where: {
            verificationStatus: 'APPROVED',
            isAvailable: true,
            primarySkill: { contains: skill },
            userId: { not: req.userId! },
          },
          take: 40,
          select: { userId: true },
        });
        const when = data.whenNeeded ? ` · needed: ${data.whenNeeded}` : '';
        for (const m of matches) {
          await notifyUser({
            userId: m.userId,
            type: 'job',
            title: `New ${skill} job`,
            body: `"${job.title}"${when}. Open your inbox to respond.`,
            data: { jobId: job.id },
          });
        }
      } catch (e) {
        console.error('notify matching artisans failed', e);
      }
    }

    res.status(201).json(job);
  } catch (e) {
    next(e);
  }
});


// Open jobs board (artisans browse work matching their skill)
router.get('/open', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const skill = (req.query.skill as string | undefined)?.trim();
    const jobs = await prisma.job.findMany({
      where: {
        status: 'OPEN',
        ...(skill ? { category: { contains: skill } } : {}),
      },
      include: {
        client: {
          select: { id: true, fullName: true, area: true, city: true, avatarLetter: true },
        },
      },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
    res.json({ jobs });
  } catch (e) {
    next(e);
  }
});

// List my jobs (client or artisan)
router.get('/mine', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const as = (req.query.as as string) || 'client';
    if (as === 'artisan') {
      const profile = await prisma.artisanProfile.findUnique({
        where: { userId: req.userId! },
      });
      if (!profile) return res.json({ jobs: [] });
      const jobs = await prisma.job.findMany({
        where: { artisanId: profile.id },
        include: {
          client: {
            select: { id: true, fullName: true, avatarLetter: true, avatarUrl: true, area: true },
          },
        },
        orderBy: { updatedAt: 'desc' },
      });
      return res.json({ jobs });
    }

    const jobs = await prisma.job.findMany({
      where: { clientId: req.userId! },
      include: {
        artisan: {
          select: {
            id: true,
            businessName: true,
            primarySkill: true,
            ratingAvg: true,
          },
        },
      },
      orderBy: { updatedAt: 'desc' },
    });
    res.json({ jobs });
  } catch (e) {
    next(e);
  }
});

router.get('/:id', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const job = await prisma.job.findUnique({
      where: { id: req.params.id },
      include: {
        client: {
          select: { id: true, fullName: true, avatarLetter: true, avatarUrl: true, area: true },
        },
        artisan: {
          include: {
            user: {
              select: {
                id: true,
                fullName: true,
                avatarLetter: true,
                avatarUrl: true,
              },
            },
          },
        },
        messages: {
          orderBy: { createdAt: 'asc' },
          include: {
            sender: { select: { id: true, fullName: true, avatarLetter: true, avatarUrl: true } },
          },
        },
      },
    });
    if (!job) return res.status(404).json({ error: 'Job not found' });

    // Completion code is only for the assigned artisan — never for the client
    const isArtisanViewer =
      job.artisan?.userId === req.userId ||
      job.artisan?.user?.id === req.userId;
    const payload: Record<string, unknown> = { ...job };
    if (!isArtisanViewer) {
      delete payload.completionCode;
    }
    res.json(payload);
  } catch (e) {
    next(e);
  }
});

// Artisan accepts / is assigned
router.post('/:id/assign', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const profile = await prisma.artisanProfile.findUnique({
      where: { userId: req.userId! },
    });
    if (!profile) return res.status(400).json({ error: 'Not an artisan' });

    const job = await prisma.job.update({
      where: { id: req.params.id },
      data: { artisanId: profile.id, status: 'NEGOTIATING' },
    });
    await notifyUser({
      userId: job.clientId,
      type: 'job',
      title: 'Artisan joined your job',
      body: 'An artisan accepted your request and is ready to chat.',
      data: { jobId: job.id },
    });
    res.json(job);
  } catch (e) {
    next(e);
  }
});

// Start job — hold funds in escrow (client PIN required)
router.post('/:id/start', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const { amount, pin } = z
      .object({ amount: z.number().positive(), pin: z.string().length(4) })
      .parse(req.body);

    const job = await prisma.job.findUnique({ where: { id: req.params.id } });
    if (!job) return res.status(404).json({ error: 'Job not found' });
    if (job.clientId !== req.userId) {
      return res.status(403).json({ error: 'Only the client can fund this job' });
    }
    if (!job.artisanId) {
      return res.status(400).json({ error: 'No artisan assigned' });
    }

    const wallet = await prisma.wallet.findUnique({ where: { userId: req.userId! } });
    if (!wallet) return res.status(400).json({ error: 'No wallet' });
    if (!wallet.pinHash) return res.status(400).json({ error: 'Set wallet PIN first' });
    if (!(await verifyPassword(pin, wallet.pinHash))) {
      return res.status(401).json({ error: 'Invalid PIN' });
    }
    if (wallet.balance < amount) {
      return res.status(400).json({ error: 'Insufficient balance' });
    }

    const code = generateCompletionCode();

    const [updatedJob] = await prisma.$transaction([
      prisma.job.update({
        where: { id: job.id },
        data: {
          agreedAmount: amount,
          status: 'IN_PROGRESS',
          completionCode: code,
          startedAt: new Date(),
        },
      }),
      prisma.wallet.update({
        where: { id: wallet.id },
        data: { balance: { decrement: amount } },
      }),
      prisma.transaction.create({
        data: {
          walletId: wallet.id,
          jobId: job.id,
          type: 'ESCROW_HOLD',
          amount,
          status: 'COMPLETED',
          description: `Escrow hold for job ${job.title}`,
        },
      }),
    ]);

    // Notify both sides (never fails the payment)
    if (job.artisanId) {
      const art = await prisma.artisanProfile.findUnique({ where: { id: job.artisanId } });
      if (art) {
        await notifyUser({
          userId: art.userId,
          type: 'job',
          title: 'Job funded — money is on hold',
          body: `Client funded "${job.title}". Open chat for the completion code (share only when work is done).`,
          data: { jobId: job.id },
        });
      }
    }
    await notifyUser({
      userId: job.clientId,
      type: 'job',
      title: 'Payment on hold',
      body: `You paid for "${job.title}". Money stays safe until you confirm the job is complete.`,
      data: { jobId: job.id },
    });

    res.json({
      job: { ...updatedJob, completionCode: undefined },
      message: 'Job started. Funds held in escrow.',
    });
  } catch (e) {
    next(e);
  }
});

// Confirm completion — release escrow
router.post('/:id/complete', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const raw = z
      .object({
        code: z.union([z.string(), z.number()]),
      })
      .parse(req.body);
    const code = String(raw.code).replace(/\D/g, '');
    if (code.length !== 6) {
      return res.status(400).json({ error: 'Enter the 6-digit completion code from the artisan' });
    }

    const job = await prisma.job.findUnique({
      where: { id: req.params.id },
      include: { artisan: true },
    });
    if (!job) return res.status(404).json({ error: 'Job not found' });
    if (job.clientId !== req.userId) {
      return res.status(403).json({ error: 'Only the client can confirm completion' });
    }
    if (job.status === 'COMPLETED') {
      return res.json({ message: 'Already completed', amountReleased: job.agreedAmount });
    }
    if (job.status !== 'IN_PROGRESS') {
      return res.status(400).json({
        error: 'Job must be in progress (funded) before releasing payment',
      });
    }
    if (!job.completionCode || job.completionCode !== code) {
      return res.status(400).json({
        error: 'Invalid completion code. Ask the artisan for the code shown in their chat.',
      });
    }
    if (!job.agreedAmount || !job.artisanId || !job.artisan) {
      return res.status(400).json({ error: 'Job missing amount or artisan' });
    }

    // Ensure artisan has a wallet (older accounts may not)
    let artisanWallet = await prisma.wallet.findUnique({
      where: { userId: job.artisan.userId },
    });
    if (!artisanWallet) {
      artisanWallet = await prisma.wallet.create({
        data: { userId: job.artisan.userId, balance: 0 },
      });
    }

    const amount = job.agreedAmount;
    await prisma.$transaction([
      prisma.job.update({
        where: { id: job.id },
        data: { status: 'COMPLETED', completedAt: new Date() },
      }),
      prisma.wallet.update({
        where: { id: artisanWallet.id },
        data: { balance: { increment: amount } },
      }),
      prisma.transaction.create({
        data: {
          walletId: artisanWallet.id,
          jobId: job.id,
          type: 'ESCROW_RELEASE',
          amount,
          status: 'COMPLETED',
          description: `Payment received — ${job.title}`,
        },
      }),
      prisma.artisanProfile.update({
        where: { id: job.artisanId },
        data: { jobsDone: { increment: 1 } },
      }),
    ]);

    await notifyUser({
      userId: job.artisan.userId,
      type: 'payment',
      title: 'Payment released',
      body: `NGN ${amount} for "${job.title}" is in your wallet.`,
      data: { jobId: job.id },
    });
    await notifyUser({
      userId: job.clientId,
      type: 'job',
      title: 'Job complete',
      body: `You confirmed "${job.title}". Payment was released to the artisan.`,
      data: { jobId: job.id },
    });

    const updatedArtisanWallet = await prisma.wallet.findUnique({
      where: { id: artisanWallet.id },
    });

    res.json({
      ok: true,
      message: 'Job completed. Payment released to artisan.',
      amountReleased: amount,
      artisanBalance: updatedArtisanWallet?.balance ?? null,
    });
  } catch (e) {
    next(e);
  }
});

// Rate artisan
router.post('/:id/rate', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const { stars, comment } = z
      .object({
        stars: z.number().int().min(1).max(5),
        comment: z.string().optional(),
      })
      .parse(req.body);

    const job = await prisma.job.findUnique({ where: { id: req.params.id } });
    if (!job) return res.status(404).json({ error: 'Job not found' });
    if (job.clientId !== req.userId) {
      return res.status(403).json({ error: 'Only the client can rate' });
    }
    if (job.status !== 'COMPLETED') {
      return res.status(400).json({ error: 'Job must be completed first' });
    }
    if (!job.artisanId) {
      return res.status(400).json({ error: 'No artisan on job' });
    }

    const existing = await prisma.rating.findUnique({ where: { jobId: job.id } });
    if (existing) return res.status(409).json({ error: 'Already rated' });

    const rating = await prisma.rating.create({
      data: {
        jobId: job.id,
        artisanId: job.artisanId,
        clientId: req.userId!,
        stars,
        comment,
      },
    });

    const agg = await prisma.rating.aggregate({
      where: { artisanId: job.artisanId },
      _avg: { stars: true },
      _count: true,
    });

    await prisma.artisanProfile.update({
      where: { id: job.artisanId },
      data: {
        ratingAvg: agg._avg.stars || stars,
        ratingCount: agg._count,
      },
    });

    res.status(201).json(rating);
  } catch (e) {
    next(e);
  }
});

export default router;
