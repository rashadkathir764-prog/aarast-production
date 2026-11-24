import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test, type TestContext } from "node:test";
import { BadRequestException } from "@nestjs/common";
import { WeddingPlanStatus } from "@prisma/client";
import { WeddingPlansService } from "../src/wedding-plans/wedding-plans.service";
import { TasksService } from "../src/tasks/tasks.service";
import {
  collaborationHistory,
  collaborationPermissions,
  planningOwnerPorts,
} from "./support/owner-ports";

// RA-BE-182, RA-BE-183, RA-BE-184 (Q-46, Q-47): the wedding's day moves the
// events and the open tasks from today on, never into the past; a wedding
// postponed with no new day has none; and no day before today is set.

const planId = "plan-wedding-date";
const ownerUserId = "owner-user";
const owner = { id: ownerUserId } as any;
// 2027-03-01 09:00 in Sana'a.
const now = new Date("2027-03-01T06:00:00.000Z");

const storedPlan = {
  id: planId,
  ownerUserId,
  title: "عرس محمد",
  city: "صنعاء",
  location: null,
  weddingDate: new Date("2027-04-10T00:00:00.000Z"),
  priorities: [],
  estimatedBudget: null,
  budgetIncludesMahr: false,
  currency: "YER",
  onboardingPath: null,
  persona: null,
  onboardingCompletedAt: null,
  status: WeddingPlanStatus.PLANNING,
  createdAt: new Date("2026-08-01T00:00:00.000Z"),
  updatedAt: new Date("2026-08-01T00:00:00.000Z"),
} as any;

type Statement = { sql: string; values: unknown[] };

function pinClock(t: TestContext) {
  t.mock.timers.enable({ apis: ["Date"], now });
}

function serviceFor(plan: any) {
  const statements: Statement[] = [];
  const written: Record<string, unknown>[] = [];
  const tx = {
    weddingPlan: {
      update: async ({ data }: { data: Record<string, unknown> }) => {
        written.push(data);
        return { ...plan, ...data, updatedAt: now };
      },
    },
    $executeRaw: async (strings: readonly string[], ...values: unknown[]) => {
      statements.push({ sql: strings.join("?"), values });
      return 0;
    },
    $queryRaw: async (strings: readonly string[], ...values: unknown[]) => {
      statements.push({ sql: strings.join("?"), values });
      return [];
    },
  };
  const context = { plan, isOwner: true, sharedMember: null };
  const service = new WeddingPlansService(
    {
      $transaction: async (work: (client: any) => Promise<unknown>) => work(tx),
    } as any,
    collaborationPermissions({
      assertPlanManageableForUpdateInTransaction: async () => context,
      canViewMoney: () => true,
    }) as any,
    collaborationHistory({
      recordForContextInTransaction: async () => ({}),
    }) as any,
    ...planningOwnerPorts,
  );
  return { service, statements, written };
}

function shiftOf(statements: Statement[], table: string): Statement {
  const found = statements.find(
    (statement) =>
      statement.sql.includes(`UPDATE "${table}"`) &&
      !statement.sql.includes("'WEDDING'"),
  );
  assert.ok(found, `no shift of ${table}`);
  return found;
}

function assertRefusedAsPast(error: unknown) {
  assert.ok(error instanceof BadRequestException);
  const body = error.getResponse() as Record<string, unknown>;
  assert.equal(body.code, "WEDDING_DATE_IN_PAST");
  assert.equal(typeof body.message, "string");
  return true;
}

test("moving the wedding moves only the events dated from today in Sana'a", async (t) => {
  pinClock(t);
  const { service, statements } = serviceFor(storedPlan);

  await service.update(owner, planId, { weddingDate: "2027-04-24" });

  const shift = shiftOf(statements, "PlanEvent");
  // The contract signed in February stays where it was.
  assert.match(shift.sql, /"date" >= \?::date/);
  assert.ok(shift.values.includes(14));
  assert.ok(shift.values.includes("2027-03-01"));
});

test("moving the wedding moves only the open tasks dated from today, and never before it", async (t) => {
  pinClock(t);
  const { service, statements } = serviceFor(storedPlan);

  await service.update(owner, planId, {
    weddingDate: "2027-03-20",
    moveOpenTasks: true,
  });

  const shift = shiftOf(statements, "WeddingTask");
  const startOfToday = new Date("2027-02-28T21:00:00.000Z");
  // A task already late (due before today began in Sana'a) stays.
  assert.match(shift.sql, /"dueDate" >= \?::timestamp/);
  assert.ok(
    shift.values.some(
      (value) => value instanceof Date && value.getTime() === startOfToday.getTime(),
    ),
  );
  // Earlier by 21 days: a task due in a week lands on today (its day, as
  // the phone writes one), not 14 days ago.
  assert.match(
    shift.sql,
    /GREATEST\("dueDate" \+ make_interval\(days => \?::int\), \?::date::timestamp\)/,
  );
  assert.ok(shift.values.includes(-21));
  assert.ok(shift.values.includes("2027-03-01"));
});

test("the tasks' own «move them» follows the same rule", async (t) => {
  pinClock(t);
  const statements: Statement[] = [];
  const tx = {
    $queryRaw: async (strings: readonly string[], ...values: unknown[]) => {
      statements.push({ sql: strings.join("?"), values });
      return [];
    },
  };
  const tasks = Object.create(TasksService.prototype) as any;
  tasks.prisma = {
    $transaction: async (work: (client: any) => Promise<unknown>) => work(tx),
  };
  tasks.permissions = {
    assertTaskManageableInTransaction: async () => ({
      plan: storedPlan,
      isOwner: true,
      sharedMember: null,
    }),
  };

  await tasks.shiftOpenDueDates(owner, planId, -10);

  const shift = shiftOf(statements, "WeddingTask");
  assert.match(shift.sql, /"dueDate" >= \?::timestamp/);
  assert.match(shift.sql, /GREATEST/);
});

test("«تأجل وما حددنا موعد» clears the day and moves nothing", async (t) => {
  pinClock(t);
  const { service, statements, written } = serviceFor(storedPlan);

  const response = await service.update(owner, planId, {
    weddingDate: null,
    moveOpenTasks: true,
  });

  assert.equal(response.weddingDate, null);
  assert.equal(written[0].weddingDate, null);
  assert.equal(
    statements.some(
      (statement) =>
        statement.sql.includes('"date" + ') || statement.sql.includes('"WeddingTask"'),
    ),
    false,
  );
});

test("a wedding day before today is refused when it is set or changed", async (t) => {
  pinClock(t);
  const { service } = serviceFor(storedPlan);

  await assert.rejects(
    service.update(owner, planId, { weddingDate: "2027-02-28" }),
    assertRefusedAsPast,
  );
  await assert.rejects(
    service.create(owner, { title: "عرس", weddingDate: "2027-02-28" } as any),
    assertRefusedAsPast,
  );
  await assert.rejects(
    service.completeOnboarding(owner, { weddingDate: "2027-02-28" } as any),
    assertRefusedAsPast,
  );
});

test("today in Sana'a is not in the past, whatever the hour", async (t) => {
  pinClock(t);
  const { service, written } = serviceFor(storedPlan);

  await service.update(owner, planId, { weddingDate: "2027-03-01" });

  assert.equal(
    (written[0].weddingDate as Date).toISOString(),
    "2027-03-01T00:00:00.000Z",
  );
});

test("after the wedding, an edit that sends its own day again is not refused", async (t) => {
  pinClock(t);
  const married = {
    ...storedPlan,
    weddingDate: new Date("2027-01-21T00:00:00.000Z"),
  };
  const { service, written } = serviceFor(married);

  await service.update(owner, planId, {
    title: "عرس محمد وسارة",
    weddingDate: "2027-01-21",
  });

  assert.equal(written[0].title, "عرس محمد وسارة");
});

test("the server's process runs on UTC, so a day sent without a zone reads the same everywhere", () => {
  const dockerfile = readFileSync(join(__dirname, "..", "Dockerfile"), "utf8");
  const runtime = dockerfile.slice(dockerfile.indexOf(" AS runtime"));
  assert.match(runtime, /^ENV TZ=UTC$/m);
});
