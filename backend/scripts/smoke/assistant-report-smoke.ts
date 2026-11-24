import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { AdminRole, PrismaClient, UserRole, UserStatus } from "@prisma/client";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { AssistantQuotaService } from "../../src/modules/identity/infrastructure/assistant-quota.service";
import {
  AssistantReportService,
  removeReviewedAssistantReports,
} from "../../src/modules/identity/infrastructure/assistant-report.service";
import { ASSISTANT_OPEN_REPORTS_PER_ACCOUNT } from "../../src/modules/identity/public/assistant-report.port";
import { OutboxService } from "../../src/platform/outbox/outbox.service";
import { adminService, notificationsService, ownerPorts } from "./support/owner-ports";

const { futureDay } = require("./smoke-utils.js") as {
  futureDay: (daysFromNow: number, now?: Date) => string;
};

// RA-ST-04 (D95) on a real database: a reported assistant answer reaches the
// moderation team (what was asked, the answer, why; the reporter unnamed);
// «تمت المراجعة» moves it to the reviewed list once and only with the
// reports permission; an account holds at most 20 open reports; the reports
// leave with the account. RA-BE-166: one report per answer id, and a
// reviewed report leaves 90 days after its review. RA-BE-165: the quota's
// reservation holds its caps under concurrent questions. The route itself is
// in assistant-smoke.js.

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (environment: NodeJS.ProcessEnv) => unknown;
};

assertManagedSmokeEnvironment(process.env);
const runId = process.env.AARAST_SMOKE_RUN_ID!;
const prisma = new PrismaClient();
const label = `Assistant report ${runId}`;

function passwordHash(value: string): string {
  return createHash("sha256").update(`${runId}:assistant-report:${value}`).digest("hex");
}

async function main(): Promise<void> {
  const [reader, moderator, support] = await Promise.all(
    [
      ["reader", UserRole.USER, null],
      ["moderator", UserRole.ADMIN, AdminRole.MODERATOR],
      ["support", UserRole.ADMIN, AdminRole.SUPPORT],
    ].map(([name, role, adminRole]) =>
      prisma.user.create({
        data: {
          name: `${label} ${name}`,
          passwordHash: passwordHash(name as string),
          role: role as UserRole,
          adminRole: adminRole as AdminRole | null,
          status: UserStatus.ACTIVE,
        },
      }),
    ),
  );
  const reports = new AssistantReportService(prisma as any);
  const permissions = new PermissionService(prisma as any, ownerPorts.plans);
  const notifications = notificationsService(prisma, permissions, new OutboxService());
  const admins = adminService(prisma, { revokeConversationAccess: () => {} }, notifications);
  const asAdmin = (user: typeof moderator) =>
    ({ ...user, adminMfa: true, sessionScope: "admin" }) as any;

  const firstAnswerId = randomUUID();
  try {
    assert.equal(
      await reports.recordAnswerReport(reader.id, {
        answerId: firstAnswerId,
        kind: "QUESTION",
        question: "وش نسيت؟",
        answer: "جواب أول",
        reason: "كلام مسيء",
      }),
      true,
    );
    assert.equal(
      await reports.recordAnswerReport(reader.id, {
        answerId: randomUUID(),
        kind: "PLAN",
        question: null,
        answer: "جواب ثاني",
        reason: "معلومة غلط أو تضر",
      }),
      true,
    );
    // RA-BE-166: the same answer reported again is kept once.
    assert.equal(
      await reports.recordAnswerReport(reader.id, {
        answerId: firstAnswerId,
        kind: "QUESTION",
        question: "وش نسيت؟",
        answer: "جواب أول",
        reason: "كلام مسيء",
      }),
      true,
    );
    assert.equal(await prisma.assistantAnswerReport.count({ where: { answerId: firstAnswerId } }), 1);
    console.log("PASS - an answer reported twice is kept once");
    const open = await admins.listAssistantAnswerReports({ status: "OPEN" } as any);
    assert.equal(open.total, 2);
    const first = open.items.find((item: any) => item.answer === "جواب أول") as any;
    const second = open.items.find((item: any) => item.answer === "جواب ثاني") as any;
    assert.equal(first.kind, "QUESTION");
    assert.equal(first.question, "وش نسيت؟");
    assert.equal(first.reason, "كلام مسيء");
    assert.equal(first.status, "OPEN");
    assert.equal(second.question, null);
    assert.ok(open.items.every((item: any) => !("reporterUserId" in item) && !("reporter" in item)));
    console.log("PASS - the team reads what was asked, the answer and why; the reporter stays unnamed");

    const resolved = (await admins.resolveAssistantAnswerReport(asAdmin(moderator), first.id)) as any;
    assert.equal(resolved.status, "RESOLVED");
    await assert.rejects(
      admins.resolveAssistantAnswerReport(asAdmin(moderator), first.id),
      (error: any) => error?.status === 404,
    );
    const stillOpen = await admins.listAssistantAnswerReports({ status: "OPEN" } as any);
    assert.deepEqual(stillOpen.items.map((item: any) => item.id), [second.id]);
    const reviewed = await admins.listAssistantAnswerReports({ status: "RESOLVED" } as any);
    assert.deepEqual(reviewed.items.map((item: any) => item.id), [first.id]);
    console.log("PASS - «تمت المراجعة» moves it to the reviewed list once; again is 404");

    // RA-BE-166: 90 days after its review the report leaves; an open one stays.
    const dayMs = 24 * 60 * 60 * 1000;
    const reviewedAt = (await prisma.assistantAnswerReport.findUniqueOrThrow({ where: { id: first.id } })).resolvedAt!;
    assert.equal(await removeReviewedAssistantReports(prisma as any, new Date(reviewedAt.getTime() + 89 * dayMs)), 0);
    assert.equal(await removeReviewedAssistantReports(prisma as any, new Date(reviewedAt.getTime() + 91 * dayMs)), 1);
    assert.equal(await prisma.assistantAnswerReport.count({ where: { id: first.id } }), 0);
    assert.equal(await prisma.assistantAnswerReport.count({ where: { id: second.id } }), 1);
    console.log("PASS - a reviewed report leaves 90 days after its review; open ones stay");

    await assert.rejects(
      admins.resolveAssistantAnswerReport(asAdmin(support), second.id),
      (error: any) => error?.status === 403,
    );
    assert.equal(
      await prisma.assistantAnswerReport.count({ where: { id: second.id, resolvedAt: null } }),
      1,
    );
    console.log("PASS - an admin without the reports permission cannot resolve one");

    for (let open = 1; open < ASSISTANT_OPEN_REPORTS_PER_ACCOUNT; open++) {
      assert.equal(
        await reports.recordAnswerReport(reader.id, {
          answerId: randomUUID(),
          kind: "CHEAPER",
          question: null,
          answer: `جواب ${open}`,
          reason: "كلام مسيء",
        }),
        true,
      );
    }
    assert.equal(
      await reports.recordAnswerReport(reader.id, {
        answerId: randomUUID(),
        kind: "CHEAPER",
        question: null,
        answer: "جواب زائد",
        reason: "كلام مسيء",
      }),
      false,
    );
    assert.equal(
      await prisma.assistantAnswerReport.count({ where: { reporterUserId: reader.id, resolvedAt: null } }),
      ASSISTANT_OPEN_REPORTS_PER_ACCOUNT,
    );
    console.log(`PASS - an account holds at most ${ASSISTANT_OPEN_REPORTS_PER_ACCOUNT} open reports`);

    // RA-BE-165: twenty questions at once against a cap five reservations
    // reach: five pass and the rest are refused, whatever the interleaving;
    // another account goes on; a timeout keeps its reserved cost.
    const quota = new AssistantQuotaService(prisma as any);
    const quotaDay = futureDay(30);
    const month = { dailyLimit: 100, monthStart: `${quotaDay.slice(0, 7)}-01`, serviceMonthlyBudgetMicroUsd: 10_000_000n };
    const reservations = await Promise.all(
      Array.from({ length: 20 }, () =>
        quota.reserveQuestion(reader.id, quotaDay, { ...month, reserveMicroUsd: 100_000n, userMonthlyBudgetMicroUsd: 500_000n }),
      ),
    );
    assert.equal(reservations.filter((item) => item.outcome === "RESERVED").length, 5);
    assert.ok(reservations.every((item) => item.outcome === "RESERVED" || item.outcome === "USER_BUDGET_REACHED"));
    const other = await quota.reserveQuestion(moderator.id, quotaDay, { ...month, reserveMicroUsd: 100_000n, userMonthlyBudgetMicroUsd: 500_000n });
    assert.equal(other.outcome, "RESERVED");
    await quota.settleQuestion(reader.id, quotaDay, 100_000n, { inputTokens: 10, outputTokens: 5, costMicroUsd: 3_000n });
    await quota.releaseQuestion(reader.id, quotaDay, 100_000n);
    await quota.releaseQuestion(reader.id, quotaDay, 0n);
    const usage = await prisma.assistantUsageDay.findUniqueOrThrow({
      where: { userId_day: { userId: reader.id, day: new Date(quotaDay) } },
    });
    assert.equal(usage.requests, 3);
    assert.equal(usage.costMicroUsd, 303_000n);
    console.log("PASS - the reservation holds the account's cap under concurrency; a timeout keeps its cost");

    await prisma.user.delete({ where: { id: reader.id } });
    assert.equal(await prisma.assistantAnswerReport.count({ where: { reporterUserId: reader.id } }), 0);
    console.log("PASS - the reports leave with the account");
  } finally {
    await prisma.user.deleteMany({ where: { id: { in: [reader.id, moderator.id, support.id] } } });
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
