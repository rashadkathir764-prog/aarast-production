import assert from "node:assert/strict";
import { readdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { test } from "node:test";
import { Prisma } from "@prisma/client";
import { composeMoneyPlan } from "../src/modules/finance/domain/money-plan-policy";
import { summarizeFunding } from "../src/modules/finance/infrastructure/money-picture";
import {
  presentMoneyPlan,
  presentPlanItem,
} from "../src/modules/finance/infrastructure/money-plan.presenter";

// The money tab's answers for fixed plans (D102-D109), as the server works
// them out. The phone's copy for a plan kept on the phone
// (`finance_local_money_plan.dart`) must give the same answers on the same
// plans (`money_plan_parity_test.dart`). This test fails when the committed
// fixtures drift from the server's rules; regenerate them with
// `npm run contracts:money-plan`.

const FIXTURES = path.resolve(
  __dirname,
  "../../mobile/test/fixtures/money_plan_fixtures.json",
);

type Json = Record<string, unknown>;
interface Scenario {
  name: string;
  input: Json;
}

const item = (id: string, over: Json = {}) => ({
  id,
  kind: "WEDDING",
  allocatedAmount: null,
  estimatedAmount: null,
  notNeeded: false,
  ...over,
});
const cost = (id: string, totalAmount: string, over: Json = {}) => ({
  id,
  budgetCategoryId: id,
  title: id,
  totalAmount,
  paid: "0",
  payer: "GROOM",
  payerName: null,
  ownerMoney: true,
  estimateCover: "WHOLE",
  estimatePart: null,
  ...over,
});
let created = 0;
const schedule = (id: string, weddingCostId: string, amount: string, dueDate: string, over: Json = {}) => ({
  id,
  weddingCostId,
  amount,
  dueDate,
  status: "PENDING",
  note: null,
  remindAt: null,
  rescheduledFrom: null,
  partlyPaid: "0",
  createdAt: `2026-10-01T00:00:${String((created += 1) % 60).padStart(2, "0")}.000Z`,
  ...over,
});
const source = (id: string, kind: string, amount: string, over: Json = {}) => ({
  id,
  kind,
  sourceName: id,
  contributorName: null,
  amount,
  status: "RECEIVED",
  expectedAt: null,
  repayments: [],
  ...over,
});

const SCENARIOS: Scenario[] = [
  {
    // The money smoke's plan: estimates, a part agreement, an expense, the
    // father's photographer, the mahr late, a loan, a promise on time, one
    // with no day and one whose day passed.
    name: "groom plan",
    input: {
      today: "2026-11-09",
      budget: "5000",
      mahrPays: true,
      items: [
        item("hall", { estimatedAmount: "2000" }),
        item("food", { estimatedAmount: "1600" }),
        item("dress", { allocatedAmount: "300" }),
        item("photo", { estimatedAmount: "2500", allocatedAmount: "800" }),
        item("car"),
        // RA-BE-112: dropped with an allocation, it expects nothing.
        item("gold", { notNeeded: true, allocatedAmount: "400" }),
        item("mahr", { kind: "MAHR" }),
      ],
      costs: [
        cost("hall", "1800", { paid: "1200" }),
        cost("food", "700", { estimateCover: "PART", estimatePart: "600" }),
        cost("dress", "150", { paid: "150", estimateCover: "PART", estimatePart: "150" }),
        cost("photo", "900", { payer: "FAMILY", payerName: "الوالد", ownerMoney: false, paid: "100" }),
        cost("mahr", "3000", { paid: "2000" }),
      ],
      schedules: [
        schedule("s1", "hall", "1000", "2026-11-19", { status: "PAID" }),
        schedule("s2", "hall", "800", "2026-12-19", { remindAt: "2026-12-18" }),
        schedule("m1", "mahr", "1000", "2026-11-01"),
      ],
      sources: [
        source("savings", "SAVINGS", "1000"),
        source("father-support", "FAMILY_SUPPORT", "500", { contributorName: "الوالد" }),
        source("father-promise", "FAMILY_SUPPORT", "800", {
          contributorName: " الوالد ",
          status: "PLEDGED",
          expectedAt: "2026-11-29",
        }),
        source("uncle", "LOAN", "400", {
          repayments: [
            { id: "r1", amount: "100", dueDate: "2026-11-14", status: "PAID", note: null },
            { id: "r2", amount: "200", dueDate: "2027-01-08", status: "PLANNED", note: "الأولى" },
          ],
        }),
        source("friend", "OTHER", "300", { status: "PLEDGED" }),
        source("late", "GIFT", "200", { status: "PLEDGED", expectedAt: "2026-11-01" }),
        // D108: recorded as «الوالدة» with no contributor named: hers.
        source("mother", "FAMILY_SUPPORT", "250", { sourceName: " الوالدة " }),
      ],
    },
  },
  {
    // Enough in total, too late: short on the hall's day.
    name: "timing short",
    input: {
      today: "2026-11-09",
      budget: null,
      mahrPays: true,
      items: [item("hall")],
      costs: [cost("hall", "1500")],
      schedules: [schedule("h1", "hall", "1500", "2026-12-01")],
      sources: [
        source("savings", "SAVINGS", "1000"),
        source("father", "FAMILY_SUPPORT", "1000", { status: "PLEDGED", expectedAt: "2026-12-10" }),
      ],
    },
  },
  {
    // Covered only if the promise comes on its day; one day, out before in.
    name: "covered if pledges",
    input: {
      today: "2026-11-09",
      budget: "3000",
      mahrPays: true,
      items: [item("hall", { estimatedAmount: "1500" }), item("food", { estimatedAmount: "900" })],
      costs: [cost("hall", "1500"), cost("food", "100", { estimateCover: "PART", estimatePart: "100" })],
      schedules: [
        schedule("h1", "hall", "1500", "2026-12-20"),
        schedule("f1", "food", "100", "2026-12-10"),
      ],
      sources: [
        source("savings", "SAVINGS", "1000"),
        source("father", "FAMILY_SUPPORT", "600", { status: "PLEDGED", expectedAt: "2026-12-10" }),
      ],
    },
  },
  {
    // A date lowered by a partial payment, two dates capped by what is left,
    // a moved date, and a promised loan that brings its repayment.
    name: "partial date and promised loan",
    input: {
      today: "2026-11-09",
      budget: "2000",
      mahrPays: true,
      items: [item("hall", { estimatedAmount: "1200" })],
      costs: [cost("hall", "1000", { paid: "300" })],
      schedules: [
        schedule("h1", "hall", "200", "2026-12-05", {
          partlyPaid: "300",
          rescheduledFrom: "2026-11-30",
        }),
        schedule("h2", "hall", "700", "2026-12-25"),
      ],
      sources: [
        source("loan", "LOAN", "1000", {
          status: "PLEDGED",
          expectedAt: "2026-12-01",
          repayments: [{ id: "r1", amount: "1000", dueDate: "2027-01-01", status: "PLANNED", note: null }],
        }),
        source("savings", "SAVINGS", "50.5"),
      ],
    },
  },
  {
    // The bride's plan, read by someone who may not see the sources: no
    // coverage and no family; the mahr's estimate is not her «if»; a cost of
    // an item the reader does not see counts as agreed.
    name: "bride, sources hidden",
    input: {
      today: "2026-11-09",
      budget: "4000",
      mahrPays: false,
      items: [
        item("dress", { estimatedAmount: "1000.25" }),
        item("mahr", { kind: "MAHR", estimatedAmount: "500" }),
      ],
      costs: [
        cost("dress", "400.75", { payer: "BRIDE", estimateCover: "PART", estimatePart: "250" }),
        cost("hidden", "300", { payer: "SHARED" }),
      ],
      schedules: [],
      sources: null,
    },
  },
  {
    // His money covers everything on its day.
    name: "covered",
    input: {
      today: "2026-11-09",
      budget: null,
      mahrPays: true,
      items: [item("hall")],
      costs: [cost("hall", "500")],
      schedules: [schedule("h1", "hall", "500", "2026-11-20")],
      sources: [source("savings", "SAVINGS", "2000")],
    },
  },
  {
    // Nothing left on him; an item with a part agreement and no estimate is
    // not known; one not needed is, even with an expense in it (RA-BE-122),
    // and a part left empty is its own amount (RA-BE-120).
    name: "nothing due",
    input: {
      today: "2026-11-09",
      budget: "100",
      mahrPays: true,
      items: [
        item("hall"),
        item("gold", { notNeeded: true }),
        item("photo"),
        item("decor", { notNeeded: true }),
      ],
      costs: [
        cost("hall", "100", { paid: "100" }),
        cost("photo", "50", { paid: "50", estimateCover: "PART", estimatePart: "50" }),
        cost("decor", "40", { paid: "40", estimateCover: "PART" }),
      ],
      schedules: [],
      sources: [source("savings", "SAVINGS", "500")],
    },
  },
];

const day = (value: unknown) =>
  value === null || value === undefined ? null : new Date(`${String(value)}T00:00:00+03:00`);
const dec = (value: unknown) => new Prisma.Decimal(String(value));
const decOrNull = (value: unknown) =>
  value === null || value === undefined ? null : dec(value);
const list = (value: unknown) => (Array.isArray(value) ? (value as Json[]) : []);

/** Dates as the day they fall on in Riyadh (D11), the way the phone keeps them. */
function plain(value: unknown): unknown {
  if (value instanceof Date) {
    return new Date(value.getTime() + 3 * 60 * 60 * 1000).toISOString().slice(0, 10);
  }
  if (Array.isArray(value)) return value.map(plain);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([key, entry]) => [key, plain(entry)]));
  }
  return value;
}

function answer(input: Json) {
  const zero = new Prisma.Decimal(0);
  const today = day(input.today) as Date;
  const items = list(input.items).map((row) => ({
    id: String(row.id),
    kind: row.kind as "WEDDING" | "MAHR",
    allocatedAmount: decOrNull(row.allocatedAmount),
    estimatedAmount: decOrNull(row.estimatedAmount),
    notNeeded: row.notNeeded === true,
  }));
  const costs = list(input.costs).map((row) => ({
    id: String(row.id),
    budgetCategoryId: String(row.budgetCategoryId),
    title: String(row.title),
    totalAmount: dec(row.totalAmount),
    paid: dec(row.paid),
    payer: (row.payer as string | null) ?? null,
    payerName: (row.payerName as string | null) ?? null,
    ownerMoney: row.ownerMoney !== false,
    estimateCover: row.estimateCover as "WHOLE" | "PART",
    estimatePart: decOrNull(row.estimatePart),
  }));
  const sources = input.sources === null
    ? null
    : list(input.sources).map((row) => ({
        id: String(row.id),
        kind: String(row.kind),
        sourceName: String(row.sourceName),
        contributorName: (row.contributorName as string | null) ?? null,
        amount: dec(row.amount),
        status: row.status as "RECEIVED" | "PLEDGED",
        expectedAt: day(row.expectedAt),
        repayments: list(row.repayments).map((repayment) => ({
          id: String(repayment.id),
          amount: dec(repayment.amount),
          dueDate: day(repayment.dueDate),
          status: repayment.status as "PLANNED" | "PAID" | "CANCELLED",
          note: (repayment.note as string | null) ?? null,
        })),
      }));
  // «معك» as the money read works it out (D104).
  const funding = sources
    ? summarizeFunding(sources as unknown as Parameters<typeof summarizeFunding>[0], {
        paidByOwner: costs
          .filter((row) => row.ownerMoney)
          .reduce((sum, row) => sum.plus(row.paid), zero),
        today,
      })
    : null;
  const plan = composeMoneyPlan({
    today,
    zero,
    budget: decOrNull(input.budget),
    mahrPays: input.mahrPays === true,
    items,
    costs,
    schedules: list(input.schedules).map((row) => ({
      id: String(row.id),
      weddingCostId: String(row.weddingCostId),
      amount: dec(row.amount),
      dueDate: day(row.dueDate) as Date,
      status: row.status as "PENDING" | "PAID" | "CANCELLED",
      note: (row.note as string | null) ?? null,
      remindAt: day(row.remindAt),
      rescheduledFrom: day(row.rescheduledFrom),
      partlyPaid: dec(row.partlyPaid),
      createdAt: new Date(String(row.createdAt)),
    })),
    sources,
    cash: funding ? dec(funding.availableCash) : null,
  });
  return plain({
    items: items.map((row) => presentPlanItem(plan, row)),
    ...presentMoneyPlan(plan),
  });
}

function fixtures() {
  return {
    note:
      "Generated by backend/test/money-plan-fixtures.test.ts (npm run contracts:money-plan). " +
      "The server's answers; the phone's copy must give the same.",
    scenarios: SCENARIOS.map((scenario) => ({
      name: scenario.name,
      input: scenario.input,
      answer: answer(scenario.input),
    })),
  };
}

test("the phone's money fixtures are the server's answers", () => {
  const expected = `${JSON.stringify(fixtures(), null, 2)}\n`;
  if (process.env.WRITE_MONEY_PLAN_FIXTURES === "1") {
    writeFileSync(FIXTURES, expected);
  }
  assert.equal(
    readFileSync(FIXTURES, "utf8").replace(/\r\n/g, "\n"),
    expected,
    "mobile/test/fixtures/money_plan_fixtures.json is stale: npm run contracts:money-plan",
  );
});

test("the fixtures cover every verdict and the cases the phone must agree on", () => {
  const all = fixtures().scenarios.map((scenario) => scenario.answer as Json);
  const verdicts = new Set(
    all.map((entry) => (entry.coverage as Json | null)?.verdict ?? "NONE"),
  );
  for (const verdict of ["NOTHING_DUE", "COVERED", "COVERED_IF_PLEDGES", "SHORT", "NONE"]) {
    assert.ok(verdicts.has(verdict), `a scenario answers ${verdict}`);
  }
  const groom = all[0];
  // D104: 1,900 received − 3,350 his money paid (the hall's 1,200, the
  // dress's 150, the mahr's 2,000) − 100 repaid is below zero: «معك» is 0.
  assert.equal((groom.coverage as Json).cash, "0");
  assert.ok(
    ((groom.coverage as Json).pledgesIgnored as Json[]).some((pledge) => pledge.reason === "LATE"),
  );
});

// Review 2026-11-09 (AGENTS.md rule 11, one implementation of each thing):
// the money summary serves each item through the presenter these fixtures
// hold the phone to, and the day in Riyadh has one rule.
test("the money summary presents each item through presentPlanItem", () => {
  const picture = readFileSync(
    path.join(__dirname, "..", "src", "modules", "finance", "infrastructure", "money-picture.ts"),
    "utf8",
  );
  assert.match(picture, /presentPlanItem\(plan, category\)/);
  assert.doesNotMatch(picture, /expectedCost:\s*expected\.expected/);
});

test("D11: the day in Riyadh is worked out in one place", () => {
  const root = path.join(__dirname, "..", "src");
  const offenders: string[] = [];
  const walk = (dir: string) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.name.endsWith(".ts")) {
        const source = readFileSync(full, "utf8");
        if (/function riyadhDay\w*\(/.test(source)) offenders.push(path.relative(root, full));
      }
    }
  };
  walk(root);
  assert.deepEqual(offenders, [path.join("modules", "finance", "domain", "money-timeline-policy.ts")]);
});
