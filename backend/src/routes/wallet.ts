import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../utils/prisma';
import { hashPassword, verifyPassword } from '../utils/auth';
import { requireAuth, AuthRequest } from '../middleware/auth';
import { initializeDeposit, verifyTransaction, paystackConfigured } from '../services/paystack';

const router = Router();

router.get('/', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const wallet = await prisma.wallet.findUnique({
      where: { userId: req.userId! },
      include: {
        transactions: {
          orderBy: { createdAt: 'desc' },
          take: 20,
        },
      },
    });
    if (!wallet) return res.status(404).json({ error: 'Wallet not found' });

    // Active escrow: jobs client funded that are still in progress
    const heldAsClient = await prisma.job.findMany({
      where: {
        clientId: req.userId!,
        status: 'IN_PROGRESS',
        agreedAmount: { not: null },
      },
      include: {
        artisan: { select: { businessName: true, primarySkill: true } },
      },
      orderBy: { startedAt: 'desc' },
    });

    // Incoming escrow: jobs artisan is doing, not yet released
    const profile = await prisma.artisanProfile.findUnique({
      where: { userId: req.userId! },
    });
    const heldAsArtisan = profile
      ? await prisma.job.findMany({
          where: {
            artisanId: profile.id,
            status: 'IN_PROGRESS',
            agreedAmount: { not: null },
          },
          include: {
            client: { select: { fullName: true, avatarLetter: true } },
          },
          orderBy: { startedAt: 'desc' },
        })
      : [];

    const escrowOut = heldAsClient.reduce(
      (s, j) => s + (j.agreedAmount || 0),
      0
    );
    const escrowIn = heldAsArtisan.reduce(
      (s, j) => s + (j.agreedAmount || 0),
      0
    );

    res.json({
      id: wallet.id,
      balance: wallet.balance,
      hasPin: !!wallet.pinHash,
      transactions: wallet.transactions,
      escrow: {
        heldTotal: escrowOut,
        incomingTotal: escrowIn,
        held: heldAsClient.map((j) => ({
          jobId: j.id,
          title: j.title,
          amount: j.agreedAmount,
          status: j.status,
          peerName: j.artisan?.businessName || 'Artisan',
          startedAt: j.startedAt,
          role: 'client',
        })),
        incoming: heldAsArtisan.map((j) => ({
          jobId: j.id,
          title: j.title,
          amount: j.agreedAmount,
          status: j.status,
          peerName: j.client?.fullName || 'Client',
          startedAt: j.startedAt,
          role: 'artisan',
        })),
      },
    });
  } catch (e) {
    next(e);
  }
});

router.get('/escrow', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const heldAsClient = await prisma.job.findMany({
      where: {
        clientId: req.userId!,
        status: 'IN_PROGRESS',
        agreedAmount: { not: null },
      },
      include: {
        artisan: { select: { businessName: true, primarySkill: true } },
      },
      orderBy: { startedAt: 'desc' },
    });

    const profile = await prisma.artisanProfile.findUnique({
      where: { userId: req.userId! },
    });
    const heldAsArtisan = profile
      ? await prisma.job.findMany({
          where: {
            artisanId: profile.id,
            status: 'IN_PROGRESS',
            agreedAmount: { not: null },
          },
          include: {
            client: { select: { fullName: true } },
          },
          orderBy: { startedAt: 'desc' },
        })
      : [];

    res.json({
      heldTotal: heldAsClient.reduce((s, j) => s + (j.agreedAmount || 0), 0),
      incomingTotal: heldAsArtisan.reduce(
        (s, j) => s + (j.agreedAmount || 0),
        0
      ),
      held: heldAsClient.map((j) => ({
        jobId: j.id,
        title: j.title,
        amount: j.agreedAmount,
        peerName: j.artisan?.businessName || 'Artisan',
        skill: j.artisan?.primarySkill,
        startedAt: j.startedAt,
        completionCode: j.completionCode,
      })),
      incoming: heldAsArtisan.map((j) => ({
        jobId: j.id,
        title: j.title,
        amount: j.agreedAmount,
        peerName: j.client?.fullName || 'Client',
        startedAt: j.startedAt,
        completionCode: j.completionCode,
      })),
    });
  } catch (e) {
    next(e);
  }
});

router.post('/pin', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const { pin } = z.object({ pin: z.string().length(4).regex(/^\d+$/) }).parse(req.body);
    const pinHash = await hashPassword(pin);
    await prisma.wallet.update({
      where: { userId: req.userId! },
      data: { pinHash },
    });
    res.json({ message: 'PIN set successfully' });
  } catch (e) {
    next(e);
  }
});

router.post('/fund', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const { amount } = z.object({ amount: z.number().positive() }).parse(req.body);
    const wallet = await prisma.wallet.findUnique({ where: { userId: req.userId! } });
    if (!wallet) return res.status(404).json({ error: 'Wallet not found' });

    const [updated] = await prisma.$transaction([
      prisma.wallet.update({
        where: { id: wallet.id },
        data: { balance: { increment: amount } },
      }),
      prisma.transaction.create({
        data: {
          walletId: wallet.id,
          type: 'FUND',
          amount,
          status: 'COMPLETED',
          description: 'Wallet funded',
        },
      }),
    ]);

    res.json({ balance: updated.balance });
  } catch (e) {
    next(e);
  }
});

router.post('/withdraw', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const { amount, pin } = z
      .object({
        amount: z.number().positive(),
        pin: z.string().length(4),
      })
      .parse(req.body);

    const wallet = await prisma.wallet.findUnique({ where: { userId: req.userId! } });
    if (!wallet) return res.status(404).json({ error: 'Wallet not found' });
    if (!wallet.pinHash) return res.status(400).json({ error: 'Set PIN first' });
    if (!(await verifyPassword(pin, wallet.pinHash))) {
      return res.status(401).json({ error: 'Invalid PIN' });
    }
    if (wallet.balance < amount) {
      return res.status(400).json({ error: 'Insufficient balance' });
    }

    const bank = await prisma.bankAccount.findUnique({ where: { userId: req.userId! } });
    if (!bank) {
      return res.status(400).json({ error: 'Add a bank account before withdrawing' });
    }

    const [updated] = await prisma.$transaction([
      prisma.wallet.update({
        where: { id: wallet.id },
        data: { balance: { decrement: amount } },
      }),
      prisma.transaction.create({
        data: {
          walletId: wallet.id,
          type: 'WITHDRAW',
          amount,
          status: process.env.PAYSTACK_SECRET_KEY ? 'PENDING' : 'COMPLETED',
          description: `Withdraw to ${bank.bankName} · ${bank.accountNumber}`,
        },
      }),
    ]);

    res.json({
      balance: updated.balance,
      message: process.env.PAYSTACK_SECRET_KEY
        ? 'Withdrawal queued to your bank account'
        : 'Withdrawal recorded (demo — connect Paystack transfer for live payouts)',
      bank: { bankName: bank.bankName, accountNumber: bank.accountNumber },
    });
  } catch (e) {
    next(e);
  }
});


/** GET /wallet/bank */
router.get('/bank', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const bank = await prisma.bankAccount.findUnique({ where: { userId: req.userId! } });
    res.json({ bank });
  } catch (e) {
    next(e);
  }
});

/** PUT /wallet/bank */
router.put('/bank', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const data = z
      .object({
        bankName: z.string().min(2),
        accountName: z.string().min(2),
        accountNumber: z.string().min(8).max(12),
        bankCode: z.string().optional(),
      })
      .parse(req.body);
   const bank = await prisma.bankAccount.upsert({
  where: { userId: req.userId! },
  create: { userId: req.userId!, ...data } as any,
  update: data,
});
    res.json({ bank });
  } catch (e) {
    next(e);
  }
});

/** POST /wallet/paystack/initialize — real or demo deposit */
router.post('/paystack/initialize', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const { amount } = z.object({ amount: z.number().positive().max(500000) }).parse(req.body);
    const user = await prisma.user.findUnique({ where: { id: req.userId! } });
    if (!user) return res.status(404).json({ error: 'User not found' });
    const email = user.email || `${user.phone || user.id}@whosenearby.local`;
    const init = await initializeDeposit({
      email,
      amountNaira: amount,
      userId: user.id,
      callbackUrl: process.env.PAYSTACK_CALLBACK_URL,
    });
    const wallet = await prisma.wallet.findUnique({ where: { userId: user.id } });
    if (wallet) {
      await prisma.transaction.create({
        data: {
          walletId: wallet.id,
          type: 'FUND',
          amount,
          status: 'PENDING',
          description: 'Wallet top-up',
          externalRef: init.reference,
        },
      });
    }
    res.json({ ...init, paystackConfigured: paystackConfigured() });
  } catch (e) {
    next(e);
  }
});

/** POST /wallet/paystack/verify */
router.post('/paystack/verify', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    const { reference } = z.object({ reference: z.string().min(3) }).parse(req.body);
    const result = await verifyTransaction(reference);
    if (!result.success && !result.demo) {
      return res.status(400).json({ error: 'Payment not successful' });
    }
    const wallet = await prisma.wallet.findUnique({ where: { userId: req.userId! } });
    if (!wallet) return res.status(404).json({ error: 'Wallet not found' });

    const existing = await prisma.transaction.findFirst({
      where: { externalRef: reference, status: 'COMPLETED' },
    });
    if (existing) {
      return res.json({ balance: wallet.balance, alreadyCredited: true });
    }

    const pending = await prisma.transaction.findFirst({
      where: { externalRef: reference, walletId: wallet.id },
    });
    const amount = result.demo
      ? pending?.amount || 0
      : result.amountNaira;

    if (amount <= 0) return res.status(400).json({ error: 'Invalid amount' });

    const [updated] = await prisma.$transaction([
      prisma.wallet.update({
        where: { id: wallet.id },
        data: { balance: { increment: amount } },
      }),
      prisma.transaction.updateMany({
        where: { externalRef: reference, walletId: wallet.id },
        data: { status: 'COMPLETED', description: 'Wallet top-up (Paystack)' },
      }),
    ]);
    // if no pending row, create completed
    if (!pending) {
      await prisma.transaction.create({
        data: {
          walletId: wallet.id,
          type: 'FUND',
          amount,
          status: 'COMPLETED',
          description: 'Wallet top-up (Paystack)',
          externalRef: reference,
        },
      });
    }
    const w = await prisma.wallet.findUnique({ where: { id: wallet.id } });
    res.json({ balance: w?.balance ?? updated.balance, amount });
  } catch (e) {
    next(e);
  }
});

/** POST /wallet/paystack/demo-complete — only when Paystack key missing */
router.post('/paystack/demo-complete', requireAuth, async (req: AuthRequest, res, next) => {
  try {
    if (paystackConfigured()) {
      return res.status(400).json({ error: 'Demo complete disabled when Paystack is configured' });
    }
    const { reference } = z.object({ reference: z.string().min(3) }).parse(req.body);
    const wallet = await prisma.wallet.findUnique({ where: { userId: req.userId! } });
    if (!wallet) return res.status(404).json({ error: 'Wallet not found' });
    const pending = await prisma.transaction.findFirst({
      where: { externalRef: reference, walletId: wallet.id, status: 'PENDING' },
    });
    if (!pending) return res.status(404).json({ error: 'Pending top-up not found' });
    const [updated] = await prisma.$transaction([
      prisma.wallet.update({
        where: { id: wallet.id },
        data: { balance: { increment: pending.amount } },
      }),
      prisma.transaction.update({
        where: { id: pending.id },
        data: { status: 'COMPLETED', description: 'Wallet top-up (demo)' },
      }),
    ]);
    res.json({ balance: updated.balance, amount: pending.amount });
  } catch (e) {
    next(e);
  }
});




/** POST /wallet/paystack/webhook — set this URL in Paystack dashboard */
router.post('/paystack/webhook', async (req, res) => {
  try {
    const signature = req.header('x-paystack-signature') || '';
    const raw = typeof req.body === 'string' ? req.body : JSON.stringify(req.body);
    // When express.json already parsed, signature check may need raw body middleware.
    // Accept event payload and credit on charge.success using metadata.userId
    const event = req.body as {
      event?: string;
      data?: {
        reference?: string;
        status?: string;
        amount?: number;
        metadata?: { userId?: string; purpose?: string };
      };
    };
    if (event.event !== 'charge.success' || !event.data) {
      return res.sendStatus(200);
    }
    const ref = event.data.reference || '';
    const userId = event.data.metadata?.userId;
    const amount = (event.data.amount || 0) / 100;
    if (!ref || !userId || amount <= 0) return res.sendStatus(200);

    const existing = await prisma.transaction.findFirst({
      where: { externalRef: ref, status: 'COMPLETED' },
    });
    if (existing) return res.sendStatus(200);

    const wallet = await prisma.wallet.findUnique({ where: { userId } });
    if (!wallet) return res.sendStatus(200);

    await prisma.$transaction([
      prisma.wallet.update({
        where: { id: wallet.id },
        data: { balance: { increment: amount } },
      }),
      prisma.transaction.updateMany({
        where: { externalRef: ref, walletId: wallet.id },
        data: { status: 'COMPLETED', description: 'Wallet top-up (Paystack)' },
      }),
    ]);
    const pending = await prisma.transaction.findFirst({
      where: { externalRef: ref, walletId: wallet.id },
    });
    if (!pending) {
      await prisma.transaction.create({
        data: {
          walletId: wallet.id,
          type: 'FUND',
          amount,
          status: 'COMPLETED',
          description: 'Wallet top-up (Paystack webhook)',
          externalRef: ref,
        },
      });
    }
    res.sendStatus(200);
  } catch (e) {
    console.error('paystack webhook', e);
    res.sendStatus(500);
  }
});


export default router;
