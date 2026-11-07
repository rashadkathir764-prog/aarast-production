import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { AdminRole, PrismaClient, UserRole, UserStatus } from "@prisma/client";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { AssistantReportService } from "../../src/modules/identity/infrastructure/assistant-report.service";
import { ASSISTANT_OPEN_REPORTS_PER_ACCOUNT } from "../../src/modules/identity/public/assistant-report.port";
import { OutboxService } from "../../src/platform/outbox/outbox.service";
import { adminService, notificationsService, ownerPorts } from "./support/owner-ports";

// RA-ST-04 (D95) on a real database: a reported assistant answer reaches the
// moderation team (what was asked, the answer, why; the reporter unnamed);
// «تمت المراجعة» moves it to the reviewed list once and only with the
// reports permission; an account holds at most 20 open reports; the reports
// leave with the account. The route itself is in assistant-smoke.js.

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

  try {
    assert.equal(
      await reports.recordAnswerReport(reader.id, {
        kind: "QUESTION",
        question: "وش نسيت؟",
        answer: "جواب أول",
        reason: "كلام مسيء",
      }),
      true,
    );
    assert.equal(
      await reports.recordAnswerReport(reader.id, {
        kind: "PLAN",
        question: null,
        answer: "جواب ثاني",
        reason: "معلومة غلط أو تضر",
      }),
      true,
    );
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
