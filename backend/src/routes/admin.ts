import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { requireAdmin } from '../middleware/admin';
import { notifyUser } from '../utils/notify';

const router = Router();
router.use(requireAdmin);

router.get('/stats', async (_req, res, next) => {
  try {
    const [users, artisans, jobs, openDisputes, openReports] = await Promise.all([
      prisma.user.count(),
      prisma.artisanProfile.count(),
      prisma.job.count(),
      prisma.dispute.count({ where: { status: 'OPEN' } }),
      prisma.report.count({ where: { status: 'OPEN' } }),
    ]);
    res.json({ users, artisans, jobs, openDisputes, openReports });
  } catch (e) {
    next(e);
  }
});

router.get('/verifications', async (_req, res, next) => {
  try {
    const list = await prisma.artisanProfile.findMany({
      where: { verificationStatus: 'PENDING' },
      include: {
        user: { select: { id: true, fullName: true, phone: true, email: true, city: true } },
      },
      orderBy: { updatedAt: 'asc' },
    });
    res.json({ pending: list });
  } catch (e) {
    next(e);
  }
});

router.post('/verifications/:id', async (req, res, next) => {
  try {
    const { status, note } = z
      .object({
        status: z.enum(['APPROVED', 'REJECTED']),
        note: z.string().optional(),
      })
      .parse(req.body);
    const profile = await prisma.artisanProfile.update({
      where: { id: req.params.id },
      data: { verificationStatus: status, verificationNote: note || null },
    });
    await notifyUser({
      userId: profile.userId,
      type: 'verification',
      title: status === 'APPROVED' ? 'You are verified' : 'Verification update',
      body:
        status === 'APPROVED'
          ? 'Your artisan profile was approved. Clients can trust your badge.'
          : `Verification was not approved.${note ? ' ' + note : ''}`,
    });
    res.json({ profile });
  } catch (e) {
    next(e);
  }
});

router.get('/disputes', async (_req, res, next) => {
  try {
    const list = await prisma.dispute.findMany({
      where: { status: 'OPEN' },
      include: {
        job: true,
        openedBy: { select: { id: true, fullName: true } },
      },
      orderBy: { createdAt: 'asc' },
    });
    res.json({ disputes: list });
  } catch (e) {
    next(e);
  }
});

router.post('/disputes/:id/resolve', async (req, res, next) => {
  try {
    const { outcome, resolution } = z
      .object({
        outcome: z.enum(['RESOLVED_CLIENT', 'RESOLVED_ARTISAN', 'CLOSED']),
        resolution: z.string().min(3),
      })
      .parse(req.body);

    const dispute = await prisma.dispute.findUnique({
      where: { id: req.params.id },
      include: { job: { include: { artisan: true } } },
    });
    if (!dispute) return res.status(404).json({ error: 'Dispute not found' });
    if (dispute.status !== 'OPEN') return res.status(400).json({ error: 'Already resolved' });

    const job = dispute.job;
    const amount = job.agreedAmount || 0;

    await prisma.$transaction(async (tx) => {
      await tx.dispute.update({
        where: { id: dispute.id },
        data: { status: outcome, resolution },
      });

      if (outcome === 'RESOLVED_CLIENT' && amount > 0) {
        // Refund client
        const clientWallet = await tx.wallet.findUnique({ where: { userId: job.clientId } });
        if (clientWallet) {
          await tx.wallet.update({
            where: { id: clientWallet.id },
            data: { balance: { increment: amount } },
          });
          await tx.transaction.create({
            data: {
              walletId: clientWallet.id,
              jobId: job.id,
              type: 'REFUND',
              amount,
              status: 'COMPLETED',
              description: `Dispute refund — ${job.title}`,
            },
          });
        }
        await tx.job.update({
          where: { id: job.id },
          data: { status: 'CANCELLED' },
        });
      } else if (outcome === 'RESOLVED_ARTISAN' && amount > 0 && job.artisan?.userId) {
        let artWallet = await tx.wallet.findUnique({ where: { userId: job.artisan.userId } });
        if (!artWallet) {
          artWallet = await tx.wallet.create({ data: { userId: job.artisan.userId, balance: 0 } });
        }
        await tx.wallet.update({
          where: { id: artWallet.id },
          data: { balance: { increment: amount } },
        });
        await tx.transaction.create({
          data: {
            walletId: artWallet.id,
            jobId: job.id,
            type: 'ESCROW_RELEASE',
            amount,
            status: 'COMPLETED',
            description: `Dispute release — ${job.title}`,
          },
        });
        await tx.job.update({
          where: { id: job.id },
          data: { status: 'COMPLETED', completedAt: new Date() },
        });
      } else {
        await tx.job.update({
          where: { id: job.id },
          data: { status: 'CANCELLED' },
        });
      }
    });

    await notifyUser({
      userId: job.clientId,
      type: 'dispute',
      title: 'Dispute resolved',
      body: resolution,
      data: { jobId: job.id },
    });
    if (job.artisan?.userId) {
      await notifyUser({
        userId: job.artisan.userId,
        type: 'dispute',
        title: 'Dispute resolved',
        body: resolution,
        data: { jobId: job.id },
      });
    }

    res.json({ ok: true, outcome });
  } catch (e) {
    next(e);
  }
});

router.get('/reports', async (_req, res, next) => {
  try {
    const list = await prisma.report.findMany({
      where: { status: 'OPEN' },
      include: { reporter: { select: { id: true, fullName: true } } },
      orderBy: { createdAt: 'asc' },
    });
    res.json({ reports: list });
  } catch (e) {
    next(e);
  }
});

router.post('/reports/:id', async (req, res, next) => {
  try {
    const { status } = z.object({ status: z.enum(['REVIEWED', 'DISMISSED']) }).parse(req.body);
    await prisma.report.update({
      where: { id: req.params.id },
      data: { status },
    });
    res.json({ ok: true });
  } catch (e) {
    next(e);
  }
});

export default router;
