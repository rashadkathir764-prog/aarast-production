import 'reflect-metadata';

import { OtpPurpose, PrismaClient } from '@prisma/client';
import { UsersService } from '../../src/users/users.service';

// Real-DB validation for account deletion: seeds a user, an owned plan and the
// Restrict-protected child chain (budgetCategory <- financialCommitment /
// paymentRecord, plus expense + guest), keyless rows (idempotency + OTP), then
// runs the SHIPPED UsersService.deleteMe against Postgres and asserts nothing
// is left. Self-cleaning on failure so the dev DB is not polluted.
async function main() {
  const prisma = new PrismaClient();
  const svc = new UsersService(prisma as unknown as never);
  const tag = `deltest-${Date.now()}`;
  const phone = `+96771${String(Date.now()).slice(-7)}`;
  let userId = '';

  try {
    const user = await prisma.user.create({
      data: { name: 'DELETION SMOKE', phone, passwordHash: 'x' },
    });
    userId = user.id;
    const plan = await prisma.weddingPlan.create({
      data: { ownerUserId: user.id, title: `${tag}-plan` },
    });
    const cat = await prisma.budgetCategory.create({
      data: { weddingPlanId: plan.id, name: `${tag}-cat` },
    });
    const commitment = await prisma.financialCommitment.create({
      data: {
        weddingPlanId: plan.id,
        budgetCategoryId: cat.id,
        title: `${tag}-commit`,
        totalAmount: 1000,
      },
    });
    await prisma.financialPaymentRecord.create({
      data: {
        weddingPlanId: plan.id,
        financialCommitmentId: commitment.id,
        budgetCategoryId: cat.id,
        title: `${tag}-pay`,
        amount: 100,
      },
    });
    await prisma.expense.create({
      data: { weddingPlanId: plan.id, title: `${tag}-exp`, amount: 50 },
    });
    await prisma.guest.create({
      data: {
        weddingPlanId: plan.id,
        name: `${tag}-guest`,
        normalizedName: `${tag}-guest`,
      },
    });
    await prisma.idempotencyKey.create({
      data: { userId: user.id, key: `${tag}-key`, method: 'POST', path: '/x' },
    });
    await prisma.otpCode.create({
      data: {
        phone,
        codeHash: 'x',
        purpose: OtpPurpose.LOGIN,
        expiresAt: new Date(Date.now() + 60_000),
      },
    });

    console.log('seeded user + owned plan + Restrict chain; running deleteMe...');
    await svc.deleteMe({ id: user.id, phone } as never);

    const remaining = {
      user: await prisma.user.count({ where: { id: user.id } }),
      plan: await prisma.weddingPlan.count({ where: { id: plan.id } }),
      budgetCategory: await prisma.budgetCategory.count({
        where: { weddingPlanId: plan.id },
      }),
      financialCommitment: await prisma.financialCommitment.count({
        where: { weddingPlanId: plan.id },
      }),
      financialPaymentRecord: await prisma.financialPaymentRecord.count({
        where: { weddingPlanId: plan.id },
      }),
      expense: await prisma.expense.count({ where: { weddingPlanId: plan.id } }),
      guest: await prisma.guest.count({ where: { weddingPlanId: plan.id } }),
      idempotencyKey: await prisma.idempotencyKey.count({
        where: { userId: user.id },
      }),
      otpCode: await prisma.otpCode.count({ where: { phone } }),
    };

    const leftover = Object.entries(remaining).filter(([, n]) => n > 0);
    if (leftover.length === 0) {
      console.log('PASS: account and every owned row removed against real Postgres.');
      console.log(JSON.stringify(remaining));
      await prisma.$disconnect();
      process.exit(0);
    }
    console.error('FAIL: leftover rows:', JSON.stringify(remaining));
    await prisma.$disconnect();
    process.exit(1);
  } catch (error) {
    console.error('ERROR during smoke:', error);
    if (userId) {
      try {
        const plans = await prisma.weddingPlan.findMany({
          where: { ownerUserId: userId },
          select: { id: true },
        });
        const ids = plans.map((p) => p.id);
        if (ids.length) {
          const w = { weddingPlanId: { in: ids } };
          await prisma.financialPaymentRecord.deleteMany({ where: w });
          await prisma.financialInstallment.deleteMany({ where: w });
          await prisma.expense.deleteMany({ where: w });
          await prisma.financialCommitment.deleteMany({ where: w });
          await prisma.debt.deleteMany({ where: w });
          await prisma.weddingTask.deleteMany({ where: w });
          await prisma.guest.deleteMany({ where: w });
          await prisma.guestGroup.deleteMany({ where: w });
          await prisma.planProviderLink.deleteMany({ where: w });
          await prisma.sharedMember.deleteMany({ where: w });
          await prisma.planInvite.deleteMany({ where: w });
          await prisma.budgetCategory.deleteMany({ where: w });
          await prisma.weddingPlan.deleteMany({ where: { id: { in: ids } } });
        }
        await prisma.idempotencyKey.deleteMany({ where: { userId } });
        await prisma.otpCode.deleteMany({ where: { phone } });
        await prisma.user.deleteMany({ where: { id: userId } });
        console.error('cleaned up seeded rows after failure.');
      } catch (cleanupError) {
        console.error('cleanup failed; manual removal needed for', phone, cleanupError);
      }
    }
    await prisma.$disconnect();
    process.exit(1);
  }
}

void main();
