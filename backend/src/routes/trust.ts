import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { requireAuth, AuthRequest } from '../middleware/auth';
import { notifyUser } from '../utils/notify';

const router = Router();

/** POST /trust/report */
router.post('/report', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const data = z
      .object({
        targetId: z.string().min(1),
        reason: z.string().min(5),
        jobId: z.string().optional(),
      })
      .parse(req.body);
    if (data.targetId === req.userId) {
      return res.status(400).json({ error: 'Cannot report yourself' });
    }
    const report = await prisma.report.create({
      data: {
        reporterId: req.userId!,
        targetId: data.targetId,
        reason: data.reason,
        jobId: data.jobId,
      },
    });
    res.status(201).json({ report });
  } catch (e) {
    next(e);
  }
});

/** POST /trust/block */
router.post('/block', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const { targetId } = z.object({ targetId: z.string().min(1) }).parse(req.body);
    if (targetId === req.userId) {
      return res.status(400).json({ error: 'Cannot block yourself' });
    }
    const user = await prisma.user.findUnique({ where: { id: req.userId! } });
    let list: string[] = [];
    try {
      list = user?.blockedIds ? JSON.parse(user.blockedIds) : [];
    } catch {
      list = [];
    }
    if (!list.includes(targetId)) list.push(targetId);
    await prisma.user.update({
      where: { id: req.userId! },
      data: { blockedIds: JSON.stringify(list) },
    });
    res.json({ blocked: list });
  } catch (e) {
    next(e);
  }
});

/** POST /trust/dispute — open dispute on in-progress/funded job */
router.post('/dispute', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const data = z
      .object({
        jobId: z.string().min(1),
        reason: z.string().min(10),
      })
      .parse(req.body);

    const job = await prisma.job.findUnique({
      where: { id: data.jobId },
      include: { artisan: true, dispute: true },
    });
    if (!job) return res.status(404).json({ error: 'Job not found' });
    if (job.dispute) return res.status(400).json({ error: 'Dispute already open' });
    if (!['IN_PROGRESS', 'FUNDED'].includes(job.status)) {
      return res.status(400).json({ error: 'Can only dispute active funded jobs' });
    }
    const isParty =
      job.clientId === req.userId || job.artisan?.userId === req.userId;
    if (!isParty) return res.status(403).json({ error: 'Not a party to this job' });

    const [dispute] = await prisma.$transaction([
      prisma.dispute.create({
        data: {
          jobId: job.id,
          openedById: req.userId!,
          artisanId: job.artisanId,
          reason: data.reason,
        },
      }),
      prisma.job.update({
        where: { id: job.id },
        data: { status: 'DISPUTED' },
      }),
    ]);

    const otherId =
      job.clientId === req.userId ? job.artisan?.userId : job.clientId;
    if (otherId) {
      await notifyUser({
        userId: otherId,
        type: 'dispute',
        title: 'Dispute opened',
        body: `A dispute was opened on "${job.title}". Money stays on hold until resolved.`,
        data: { jobId: job.id },
      });
    }

    res.status(201).json({ dispute });
  } catch (e) {
    next(e);
  }
});

/** POST /trust/fcm-token */
router.post('/fcm-token', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const { token } = z.object({ token: z.string().min(10) }).parse(req.body);
    await prisma.user.update({
      where: { id: req.userId! },
      data: { fcmToken: token },
    });
    res.json({ ok: true });
  } catch (e) {
    next(e);
  }
});

export default router;
