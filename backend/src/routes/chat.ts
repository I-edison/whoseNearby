import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { requireAuth, AuthRequest } from '../middleware/auth';
import { broadcastToJob, notifyUser as wsNotifyUser } from '../ws/hub';
import { notifyUser } from '../utils/notify';

const router = Router();

router.get('/conversations', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const profile = await prisma.artisanProfile.findUnique({
      where: { userId: req.userId! },
    });

    const jobs = await prisma.job.findMany({
      where: {
        OR: [
          { clientId: req.userId! },
          ...(profile ? [{ artisanId: profile.id }] : []),
        ],
        status: { in: ['NEGOTIATING', 'FUNDED', 'IN_PROGRESS', 'COMPLETED'] },
      },
      include: {
        client: {
          select: { id: true, fullName: true, avatarLetter: true, avatarUrl: true },
        },
        artisan: {
          select: {
            id: true,
            businessName: true,
            user: { select: { avatarLetter: true, avatarUrl: true } },
          },
        },
        messages: {
          orderBy: { createdAt: 'desc' },
          take: 1,
        },
      },
      orderBy: { updatedAt: 'desc' },
    });

    const raw = await Promise.all(
      jobs.map(async (j) => {
        const isClient = j.clientId === req.userId;
        const peerKey = isClient
          ? (j.artisan?.id || j.id)
          : j.clientId;
        const unread = await prisma.message.count({
          where: {
            jobId: j.id,
            senderId: { not: req.userId! },
            readAt: null,
          },
        });
        return {
          peerKey,
          jobId: j.id,
          status: j.status,
          title: j.title,
          peerName: isClient
            ? j.artisan?.businessName || 'Artisan'
            : j.client.fullName,
          peerLetter: isClient
            ? j.artisan?.user.avatarLetter || 'A'
            : j.client.avatarLetter,
          peerAvatarUrl: isClient
            ? j.artisan?.user.avatarUrl || null
            : j.client.avatarUrl || null,
          lastMessage: j.messages[0]?.body || null,
          lastMessageAt: j.messages[0]?.createdAt || j.updatedAt,
          agreedAmount: j.agreedAmount,
          unread,
        };
      })
    );

    // One row per peer (most recent job). Prevents same user appearing twice.
    const byPeer = new Map<string, (typeof raw)[0]>();
    for (const c of raw) {
      const prev = byPeer.get(c.peerKey);
      if (!prev || new Date(c.lastMessageAt).getTime() > new Date(prev.lastMessageAt).getTime()) {
        byPeer.set(c.peerKey, c);
      }
    }
    const conversations = Array.from(byPeer.values())
      .map(({ peerKey, ...rest }) => rest)
      .sort((a, b) => new Date(b.lastMessageAt).getTime() - new Date(a.lastMessageAt).getTime());

    res.json({ conversations });
  } catch (e) {
    next(e);
  }
});

router.get('/:jobId/messages', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const jobId = req.params.jobId;

    const marked = await prisma.message.updateMany({
      where: {
        jobId,
        senderId: { not: req.userId! },
        readAt: null,
      },
      data: { readAt: new Date() },
    });
    if (marked.count > 0) {
      broadcastToJob(jobId, {
        type: 'read',
        jobId,
        readerId: req.userId,
        at: new Date().toISOString(),
      });
    }

    const messages = await prisma.message.findMany({
      where: { jobId },
      orderBy: { createdAt: 'asc' },
      include: {
        sender: {
          select: { id: true, fullName: true, avatarLetter: true, avatarUrl: true },
        },
      },
    });
    res.json({ messages });
  } catch (e) {
    next(e);
  }
});

router.post('/:jobId/messages', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const { body, offerAmount } = z
      .object({
        body: z.string().min(1),
        offerAmount: z.number().positive().optional(),
      })
      .parse(req.body);

    const job = await prisma.job.findUnique({ where: { id: req.params.jobId } });
    if (!job) return res.status(404).json({ error: 'Job not found' });

    // Block duplicate price offers while one is still unanswered
    if (offerAmount != null) {
      if (job.status === 'IN_PROGRESS' || job.status === 'COMPLETED' || job.status === 'FUNDED') {
        return res.status(400).json({
          error: 'Job is already funded. Price can no longer be changed.',
        });
      }

      const lastOffer = await prisma.message.findFirst({
        where: {
          jobId: job.id,
          offerAmount: { not: null },
        },
        orderBy: { createdAt: 'desc' },
      });

      if (lastOffer) {
        // Has the other party replied after that offer?
        const replyAfterOffer = await prisma.message.findFirst({
          where: {
            jobId: job.id,
            senderId: { not: lastOffer.senderId },
            createdAt: { gt: lastOffer.createdAt },
          },
          orderBy: { createdAt: 'asc' },
        });

        if (!replyAfterOffer) {
          const isOwnPending = lastOffer.senderId === req.userId;
          return res.status(400).json({
            error: isOwnPending
              ? 'You already sent a price offer. Wait for a reply before sending another.'
              : 'There is already a price offer waiting for a reply. Answer it first (or wait for them to respond).',
            pendingOffer: {
              amount: lastOffer.offerAmount,
              fromYou: isOwnPending,
              messageId: lastOffer.id,
            },
          });
        }
      }
    }

    const message = await prisma.message.create({
      data: {
        jobId: job.id,
        senderId: req.userId!,
        body,
        offerAmount,
      },
      include: {
        sender: {
          select: { id: true, fullName: true, avatarLetter: true, avatarUrl: true },
        },
      },
    });

    await prisma.job.update({
      where: { id: job.id },
      data: {
        updatedAt: new Date(),
        ...(job.status === 'OPEN' ? { status: 'NEGOTIATING' } : {}),
      },
    });

    // Notify offline peer
    try {
      const profile = job.artisanId
        ? await prisma.artisanProfile.findUnique({ where: { id: job.artisanId } })
        : null;
      const peerId =
        job.clientId === req.userId! ? profile?.userId : job.clientId;
      if (peerId) {
        await notifyUser({
          userId: peerId,
          type: 'chat',
          title: offerAmount != null ? 'New price offer' : 'New message',
          body:
            offerAmount != null
              ? `Offer: ₦${offerAmount.toLocaleString()} — ${body.slice(0, 80)}`
              : body.slice(0, 120),
          data: { jobId: job.id },
        });
      }
    } catch (_) {}

    // Real-time push to everyone in this job chat
    broadcastToJob(job.id, { type: 'message', message });
    // Notify other party for conversation list refresh
    const otherIds = new Set<string>();
    if (job.clientId !== req.userId) otherIds.add(job.clientId);
    if (job.artisanId) {
      const art = await prisma.artisanProfile.findUnique({ where: { id: job.artisanId } });
      if (art && art.userId !== req.userId) otherIds.add(art.userId);
    }
    for (const uid of otherIds) {
      wsNotifyUser(uid, { type: 'conversation_updated', jobId: job.id });
    }

    res.status(201).json(message);
  } catch (e) {
    next(e);
  }
});

router.post('/:jobId/read', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const result = await prisma.message.updateMany({
      where: {
        jobId: req.params.jobId,
        senderId: { not: req.userId! },
        readAt: null,
      },
      data: { readAt: new Date() },
    });
    if (result.count > 0) {
      broadcastToJob(req.params.jobId, {
        type: 'read',
        jobId: req.params.jobId,
        readerId: req.userId,
        at: new Date().toISOString(),
      });
    }
    res.json({ marked: result.count });
  } catch (e) {
    next(e);
  }
});

export default router;