// Local demo data: fills the development database with the designs' own data
// (the groom, the bride, the providers and the admin team) so every journey can
// be walked in the real app and compared to the prototype like for like.
//
//   cd backend && npx ts-node prisma/demo-seed.ts
//
// Safe to run again: every row has a stable id and is updated in place. It
// refuses to run in production or against any database that is not on this
// machine. See docs/qa/DEMO_DATA.md for the accounts and what each holds.
import { PrismaClient } from '@prisma/client';
import { DEMO_ACCOUNTS, seedAccounts } from './demo-seed/accounts';
import { removeAdHocRows, seedAdminAudit, seedNotifications } from './demo-seed/extras';
import { seedMarketplace } from './demo-seed/marketplace';
import { expectedTotals, seedPlanCosts, seedPlanCore } from './demo-seed/plan';
import { BRIDE_PLAN, GROOM_PLAN } from './demo-seed/plan-data';
import { assertLocalDevelopmentDatabase, resolveDemoPassword } from './demo-seed/support';

async function main() {
  assertLocalDevelopmentDatabase();
  const prisma = new PrismaClient();
  try {
    const { password, generated } = resolveDemoPassword();

    const removed = await removeAdHocRows(prisma);
    console.log(`تنظيف الصفوف اليدوية القديمة: ${JSON.stringify(removed)}`);

    await seedAccounts(prisma, password);
    // Local sign-in locks from earlier failed attempts are not worth keeping.
    await prisma.loginThrottle.deleteMany();

    await seedPlanCore(prisma, GROOM_PLAN);
    await seedPlanCore(prisma, BRIDE_PLAN);
    await seedMarketplace(prisma);
    await seedPlanCosts(prisma, GROOM_PLAN);
    await seedPlanCosts(prisma, BRIDE_PLAN);
    await seedNotifications(prisma);
    await seedAdminAudit(prisma);

    for (const plan of [GROOM_PLAN, BRIDE_PLAN]) {
      const totals = expectedTotals(plan);
      console.log(
        `${plan.title}: ميزانية ${totals.budget.toLocaleString('en-US')} ر.ي، بنود ${totals.items.toLocaleString('en-US')}، ` +
          `مدفوع ${totals.paid.toLocaleString('en-US')}، ضيوف ${totals.guests} (أكدوا ${totals.confirmed})، مهام ${totals.tasks}`,
      );
    }
    console.log(
      '\nحسابات التجربة (الدخول برقم الجوال وكلمة السر؛ ولو طُلب رمز تحقق، ' +
        'فهو 123456 أو قيمة AUTH_DEV_OTP_CODE في بيئة التطوير):',
    );
    for (const account of DEMO_ACCOUNTS) {
      console.log(`  ${account.phone}  ${account.name}  -  ${account.roleAr}`);
    }
    if (generated) {
      console.log(`\nكلمة السر لكل الحسابات (للتجربة المحلية فقط، تتغير مع كل تشغيل): ${password}`);
    } else {
      console.log('\nكلمة السر لكل الحسابات هي قيمة DEMO_PASSWORD اللي أعطيتها.');
    }
    console.log('بيانات التجربة جاهزة.');
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
