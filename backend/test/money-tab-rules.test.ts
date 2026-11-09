import assert from "node:assert/strict";
import { test } from "node:test";
import { Prisma } from "@prisma/client";
import {
  estimateCoverOf,
  expectedItem,
  sumExpected,
} from "../src/modules/finance/domain/expected-cost-policy";
import {
  contributorKey,
  familyContributions,
} from "../src/modules/finance/domain/family-contributions-policy";
import {
  type Obligation,
  type TimelineCost,
  type TimelineSchedule,
  type TimelineSource,
  coverageOf,
  coverageVerdict,
  listObligations,
  openScheduleAmounts,
  riyadhDay,
  riyadhMonth,
  weddingDuesByMonth,
} from "../src/modules/finance/domain/money-timeline-policy";

// The money tab's rules (D103-D109), as pure functions: what an item is
// expected to cost, what is still to pay and when, whether the owner's money
// covers his share in time, and the family person by person.

const d = (value: string | number) => new Prisma.Decimal(value);
const ZERO = d(0);
const s = (value: Prisma.Decimal | null | undefined) => (value == null ? null : value.toString());
// Midnight in Riyadh (D11) of a calendar day.
const day = (iso: string) => new Date(`${iso}T00:00:00+03:00`);
const TODAY = day("2026-11-09");

// ---------------------------------------------------------------- D105, D109

const item = (estimated: string | null, allocated: string | null = null, notNeeded = false) => ({
  estimatedAmount: estimated === null ? null : d(estimated),
  allocatedAmount: allocated === null ? null : d(allocated),
  notNeeded,
});
const agreement = (total: string, cover: "WHOLE" | "PART" = "WHOLE", part: string | null = null) => ({
  totalAmount: d(total),
  estimateCover: cover,
  estimatePart: part === null ? null : d(part),
});

test("D105: an item with only an estimate is expected at its estimate", () => {
  const x = expectedItem(item("2000000"), [], ZERO);
  assert.equal(s(x.expected), "2000000");
  assert.equal(s(x.estimateLeft), "2000000");
  assert.equal(x.estimateSource, "ESTIMATE");
  assert.equal(x.costKnown, true);
});

test("D105: an agreement for the whole item replaces its estimate, cheaper or dearer", () => {
  assert.equal(s(expectedItem(item("2000000"), [agreement("1500000")], ZERO).expected), "1500000");
  assert.equal(s(expectedItem(item("2000000"), [agreement("2600000")], ZERO).expected), "2600000");
  // Never the larger of the two (Rashad, 2026-11-09).
  assert.equal(s(expectedItem(item("2000000"), [agreement("200000")], ZERO).expected), "200000");
});

test("D105: an agreement for a part keeps the rest of the estimate, with no double count", () => {
  // Hospitality estimated 1,600,000; the lunch agreed at 700,000 for the part
  // estimated 600,000: 1,000,000 of the estimate is still expected.
  const x = expectedItem(item("1600000"), [agreement("700000", "PART", "600000")], ZERO);
  assert.equal(s(x.agreed), "700000");
  assert.equal(s(x.estimateLeft), "1000000");
  assert.equal(s(x.expected), "1700000");
  // Two parts that settle more than the estimate leave nothing of it.
  const y = expectedItem(
    item("1000000"),
    [agreement("500000", "PART", "700000"), agreement("400000", "PART", "500000")],
    ZERO,
  );
  assert.equal(s(y.estimateLeft), "0");
  assert.equal(s(y.expected), "900000");
});

test("D105: one whole agreement settles the item even beside parts", () => {
  const x = expectedItem(
    item("1000000"),
    [agreement("300000", "PART", "300000"), agreement("900000")],
    ZERO,
  );
  assert.equal(s(x.estimateLeft), "0");
  assert.equal(s(x.expected), "1200000");
});

test("D107: an expense is a part of the estimate at its own value", () => {
  const cover = estimateCoverOf({ entryKind: "EXPENSE", totalAmount: d("150000") });
  assert.deepEqual({ cover: cover.estimateCover, part: s(cover.estimatePart) }, { cover: "PART", part: "150000" });
  const x = expectedItem(item("300000"), [agreement("150000", cover.estimateCover, "150000")], ZERO);
  assert.equal(s(x.expected), "300000");
  // An agreement with no choice settles the whole item (every agreement before D105).
  assert.deepEqual(estimateCoverOf({ entryKind: "AGREEMENT", totalAmount: d("1") }), {
    estimateCover: "WHOLE",
    estimatePart: null,
  });
  // A part with no amount is the agreement's own value; WHOLE carries none.
  assert.equal(s(estimateCoverOf({ entryKind: "AGREEMENT", totalAmount: d("9"), estimateCover: "PART" }).estimatePart), "9");
  assert.equal(
    estimateCoverOf({ entryKind: "EXPENSE", totalAmount: d("9"), estimateCover: "WHOLE", estimatePart: d("3") }).estimatePart,
    null,
  );
});

test("D105: an agreement written before D105 (no choice) settles the whole item", () => {
  const x = expectedItem(item("2500000"), [{ totalAmount: d("2000000") }], ZERO);
  assert.equal(s(x.expected), "2000000");
  // A part with no amount written is a part at the agreement's own value.
  const y = expectedItem(item("2500000"), [{ totalAmount: d("2000000"), estimateCover: "PART" }], ZERO);
  assert.equal(s(y.expected), "2500000");
});

test("D109: without an estimate the allocation stands in; the owner's estimate wins", () => {
  const byAllocation = expectedItem(item(null, "800000"), [], ZERO);
  assert.equal(byAllocation.estimateSource, "ALLOCATION");
  assert.equal(s(byAllocation.expected), "800000");
  const both = expectedItem(item("1200000", "800000"), [], ZERO);
  assert.equal(both.estimateSource, "ESTIMATE");
  assert.equal(s(both.expected), "1200000");
});

test("D105: an item's cost is unknown until an estimate or a whole agreement covers it", () => {
  assert.equal(expectedItem(item(null), [], ZERO).costKnown, false);
  // A part agreement with no estimate: the rest of the item is unknown.
  assert.equal(expectedItem(item(null), [agreement("500000", "PART", "500000")], ZERO).costKnown, false);
  assert.equal(expectedItem(item(null), [agreement("500000")], ZERO).costKnown, true);
  // «ما أحتاجها» with nothing in it is not missing; zero is an answer.
  assert.equal(expectedItem(item(null, null, true), [], ZERO).costKnown, true);
  assert.equal(expectedItem(item("0"), [], ZERO).costKnown, true);
});

test("D105: the plan's expected cost sums its items and counts the unknown ones", () => {
  const total = sumExpected(
    [
      expectedItem(item("2000000"), [agreement("1800000")], ZERO),
      expectedItem(item("1600000"), [agreement("700000", "PART", "600000")], ZERO),
      expectedItem(item(null), [], ZERO),
    ],
    ZERO,
  );
  assert.equal(s(total.agreed), "2500000");
  assert.equal(s(total.estimateLeft), "1000000");
  assert.equal(s(total.expected), "3500000");
  assert.equal(total.unknownCount, 1);
});

// ----------------------------------------------------------- D102, D106

const cost = (over: Partial<TimelineCost> & { id: string }): TimelineCost => ({
  budgetCategoryId: "cat",
  title: over.id,
  totalAmount: d(0),
  paid: d(0),
  payer: "GROOM",
  payerName: null,
  ownerMoney: true,
  mahr: false,
  ...over,
});
let createdSeq = 0;
const schedule = (over: Partial<TimelineSchedule> & { id: string; weddingCostId: string }): TimelineSchedule => ({
  amount: d(0),
  dueDate: TODAY,
  status: "PENDING",
  note: null,
  remindAt: null,
  rescheduledFrom: null,
  partlyPaid: d(0),
  createdAt: new Date(Date.UTC(2026, 0, 1, 0, 0, (createdSeq += 1))),
  ...over,
});
const source = (over: Partial<TimelineSource> & { id: string }): TimelineSource => ({
  kind: "SAVINGS",
  sourceName: over.id,
  amount: d(0),
  status: "RECEIVED",
  expectedAt: null,
  repayments: [],
  ...over,
});

test("RA-BE-53: dates of one agreement never ask together for more than it owes", () => {
  const c = cost({ id: "hall", totalAmount: d("1000000"), paid: d("800000") });
  const open = openScheduleAmounts(c, [
    schedule({ id: "b", weddingCostId: "hall", amount: d("500000"), dueDate: day("2026-12-20") }),
    schedule({ id: "a", weddingCostId: "hall", amount: d("150000"), dueDate: day("2026-12-01") }),
    schedule({ id: "paid", weddingCostId: "hall", amount: d("50000"), status: "PAID" }),
  ]);
  assert.equal(s(open.get("a")), "150000");
  assert.equal(s(open.get("b")), "50000");
  assert.equal(open.has("paid"), false);
});

test("D102: the obligations list every pending date, the undated rest, and the owner's loans", () => {
  const lines = listObligations({
    today: TODAY,
    zero: ZERO,
    costs: [
      cost({ id: "hall", totalAmount: d("2000000"), paid: d("500000") }),
      cost({ id: "photo", totalAmount: d("600000"), payer: "FAMILY", payerName: "الوالد", ownerMoney: false }),
    ],
    schedules: [
      schedule({ id: "hall-1", weddingCostId: "hall", amount: d("1000000"), dueDate: day("2026-12-01") }),
      schedule({ id: "photo-late", weddingCostId: "photo", amount: d("200000"), dueDate: day("2026-11-01") }),
    ],
    sources: [
      source({
        id: "loan",
        kind: "LOAN",
        sourceName: "خالي أحمد",
        amount: d("1000000"),
        repayments: [
          { id: "r1", amount: d("300000"), dueDate: day("2027-02-01"), status: "PAID", note: null },
          { id: "r2", amount: d("300000"), dueDate: day("2027-03-01"), status: "PLANNED", note: null },
          { id: "r3", amount: d("100000"), dueDate: null, status: "PLANNED", note: null },
        ],
      }),
      // G33: a promised loan is not owed yet.
      source({ id: "loan2", kind: "LOAN", status: "PLEDGED", amount: d("500000"), expectedAt: day("2026-12-05") }),
    ],
  });
  assert.deepEqual(
    lines.map((line) => [line.kind, line.id, s(line.amount), line.dueDate ? riyadhDay(line.dueDate) : null]),
    [
      ["DUE", "photo-late", "200000", "2026-11-01"],
      ["DUE", "hall-1", "1000000", "2026-12-01"],
      ["LOAN_REPAYMENT", "r2", "300000", "2027-03-01"],
      ["UNDATED", "hall", "500000", null],
      ["UNDATED", "photo", "400000", null],
      ["LOAN_REPAYMENT", "r3", "100000", null],
      ["LOAN_UNPLANNED", "loan", "300000", null],
    ],
  );
  assert.equal(lines[0].isOverdue, true);
  assert.equal(lines[0].ownerMoney, false);
});

test("D106: a date lowered by a partial payment says what was paid towards it", () => {
  const [line] = listObligations({
    today: TODAY,
    zero: ZERO,
    costs: [cost({ id: "hall", totalAmount: d("1000000"), paid: d("300000") })],
    schedules: [
      schedule({
        id: "s",
        weddingCostId: "hall",
        amount: d("200000"),
        partlyPaid: d("300000"),
        dueDate: day("2026-12-01"),
        rescheduledFrom: day("2026-11-20"),
        remindAt: day("2026-11-28"),
      }),
    ],
    sources: null,
  });
  assert.equal(s(line.amount), "200000");
  assert.equal(s(line.scheduledAmount), "500000");
  assert.equal(s(line.paidTowards), "300000");
  assert.equal(riyadhDay(line.rescheduledFrom as Date), "2026-11-20");
  assert.equal(riyadhDay(line.remindAt as Date), "2026-11-28");
});

test("D102: a fully paid agreement owes nothing and lists nothing", () => {
  const lines = listObligations({
    today: TODAY,
    zero: ZERO,
    costs: [cost({ id: "dress", totalAmount: d("150000"), paid: d("150000") })],
    schedules: [],
    sources: null,
  });
  assert.equal(lines.length, 0);
});

test("D102: the wedding's dues by month leave loans out and keep the owner's part", () => {
  const lines = listObligations({
    today: TODAY,
    zero: ZERO,
    costs: [
      cost({ id: "hall", totalAmount: d("1500000") }),
      cost({ id: "photo", totalAmount: d("600000"), payer: "FAMILY", ownerMoney: false }),
    ],
    schedules: [
      schedule({ id: "h1", weddingCostId: "hall", amount: d("500000"), dueDate: day("2026-11-30") }),
      schedule({ id: "h2", weddingCostId: "hall", amount: d("500000"), dueDate: day("2026-12-01") }),
      schedule({ id: "p1", weddingCostId: "photo", amount: d("600000"), dueDate: day("2026-12-15") }),
      schedule({ id: "late", weddingCostId: "hall", amount: d("100000"), dueDate: day("2026-11-01") }),
    ],
    sources: [
      source({
        id: "loan",
        kind: "LOAN",
        amount: d("200000"),
        repayments: [{ id: "r", amount: d("200000"), dueDate: day("2026-12-20"), status: "PLANNED", note: null }],
      }),
    ],
  });
  const months = weddingDuesByMonth(lines, ZERO);
  assert.deepEqual(
    months.months.map((m) => [m.month, s(m.amount), s(m.ownerAmount), m.count]),
    [
      ["2026-11", "500000", "500000", 1],
      ["2026-12", "1100000", "500000", 2],
    ],
  );
  assert.deepEqual([s(months.overdue.amount), months.overdue.count], ["100000", 1]);
  assert.deepEqual([s(months.undated.amount), months.undated.count], ["400000", 1]);
});

test("months and days are Riyadh's, not the server's clock", () => {
  // 23:30 on 30 November in Riyadh is 20:30 UTC: still November.
  assert.equal(riyadhMonth(new Date("2026-11-30T20:30:00Z")), "2026-11");
  assert.equal(riyadhDay(new Date("2026-11-30T21:30:00Z")), "2026-12-01");
});

// ----------------------------------------------------------------- D103

const ob = (over: Partial<Obligation> & { id: string; amount: Prisma.Decimal }): Obligation => ({
  kind: "DUE",
  weddingCostId: over.id,
  budgetCategoryId: "cat",
  fundingSourceId: null,
  title: over.id,
  note: null,
  scheduledAmount: over.amount,
  paidTowards: d(0),
  dueDate: null,
  isOverdue: false,
  remindAt: null,
  rescheduledFrom: null,
  payer: "GROOM",
  payerName: null,
  ownerMoney: true,
  mahr: false,
  ...over,
});

test("D103: enough in total but late: the shortfall is on the day it falls", () => {
  // In hand 1,000,000; the hall wants 1,500,000 on 1 December; the father's
  // 1,000,000 arrives on 10 December. The sum covers it, the timing does not.
  const c = coverageOf({
    cash: d("1000000"),
    today: TODAY,
    obligations: [ob({ id: "hall", amount: d("1500000"), dueDate: day("2026-12-01") })],
    sources: [source({ id: "father", status: "PLEDGED", amount: d("1000000"), expectedAt: day("2026-12-10") })],
  });
  assert.equal(riyadhDay(c.withPledges.firstShort?.date as Date), "2026-12-01");
  assert.equal(s(c.withPledges.firstShort?.amount), "500000");
  assert.equal(s(c.withPledges.end), "500000");
  assert.equal(s(c.withoutPledges.end), "-500000");
  // What would bridge it: 500,000 on 1 December.
  assert.equal(s(c.withPledges.deepest?.amount), "500000");
});

test("D103: the deepest dip is what is needed, not the first one", () => {
  const c = coverageOf({
    cash: d("1000000"),
    today: TODAY,
    obligations: [
      ob({ id: "hall", amount: d("1500000"), dueDate: day("2026-12-01") }),
      ob({ id: "food", amount: d("1000000"), dueDate: day("2026-12-20") }),
    ],
    sources: [],
  });
  assert.equal(s(c.withPledges.firstShort?.amount), "500000");
  assert.equal(c.withPledges.deepest?.id, "food");
  assert.equal(s(c.withPledges.deepest?.amount), "1500000");
  assert.equal(s(c.withPledges.end), "-1500000");
});

test("D103: a pledge on time covers; without it the day it falls short is named", () => {
  const c = coverageOf({
    cash: d("1000000"),
    today: TODAY,
    obligations: [ob({ id: "hall", amount: d("1500000"), dueDate: day("2026-12-20") })],
    sources: [source({ id: "father", status: "PLEDGED", amount: d("1000000"), expectedAt: day("2026-12-10") })],
  });
  assert.equal(c.withPledges.firstShort, null);
  assert.equal(s(c.withPledges.end), "500000");
  assert.equal(riyadhDay(c.withoutPledges.firstShort?.date as Date), "2026-12-20");
  assert.equal(s(c.withoutPledges.firstShort?.amount), "500000");
  assert.deepEqual(c.pledgesCounted.map((p) => p.id), ["father"]);
});

test("D103: on one day, what goes out is counted before what comes in", () => {
  const c = coverageOf({
    cash: d("0"),
    today: TODAY,
    obligations: [ob({ id: "hall", amount: d("100"), dueDate: day("2026-12-01") })],
    sources: [source({ id: "p", status: "PLEDGED", amount: d("100"), expectedAt: day("2026-12-01") })],
  });
  assert.equal(s(c.withPledges.firstShort?.amount), "100");
  assert.equal(s(c.withPledges.end), "0");
});

test("D103: a pledge with no day, or one whose day passed, is not counted", () => {
  const c = coverageOf({
    cash: d("100"),
    today: TODAY,
    obligations: [ob({ id: "hall", amount: d("500"), dueDate: day("2026-12-01") })],
    sources: [
      source({ id: "nodate", status: "PLEDGED", amount: d("1000") }),
      source({ id: "late", status: "PLEDGED", amount: d("1000"), expectedAt: day("2026-11-01") }),
      source({ id: "today", status: "PLEDGED", amount: d("50"), expectedAt: TODAY }),
    ],
  });
  assert.deepEqual(c.pledgesIgnored.map((p) => [p.id, p.reason]), [["nodate", "NO_DATE"], ["late", "LATE"]]);
  assert.deepEqual(c.pledgesCounted.map((p) => p.id), ["today"]);
  assert.equal(s(c.withPledges.end), "-350");
});

test("D103: the family's share is not on the owner; the mahr and his loans are", () => {
  const c = coverageOf({
    cash: d("1000"),
    today: TODAY,
    obligations: [
      ob({ id: "photo", amount: d("5000"), dueDate: day("2026-12-01"), ownerMoney: false }),
      ob({ id: "mahr", amount: d("400"), dueDate: day("2026-12-02"), mahr: true }),
      ob({ id: "r", kind: "LOAN_REPAYMENT", amount: d("300"), dueDate: day("2027-01-01") }),
      ob({ id: "rest", kind: "UNDATED", amount: d("200") }),
    ],
    sources: [],
  });
  assert.equal(s(c.total), "900");
  assert.equal(s(c.undated), "200");
  assert.equal(c.hasLoan, true);
  assert.equal(riyadhDay(c.lastDate as Date), "2027-01-01");
  assert.deepEqual(c.withPledges.steps.map((x) => [x.kind, x.id, s(x.balance)]), [
    ["MAHR", "mahr", "600"],
    ["LOAN_REPAYMENT", "r", "300"],
    ["UNDATED", "rest", "100"],
  ]);
  assert.equal(c.withPledges.firstShort, null);
});

test("D103: a late line counts today, and says it was late", () => {
  const c = coverageOf({
    cash: d("100"),
    today: TODAY,
    obligations: [ob({ id: "late", amount: d("300"), dueDate: day("2026-10-01"), isOverdue: true })],
    sources: [],
  });
  const [step] = c.withPledges.steps;
  assert.equal(step.late, true);
  assert.equal(riyadhDay(step.date as Date), "2026-11-09");
  assert.equal(s(c.withPledges.firstShort?.amount), "200");
});

test("D103: a promised loan, when counted, brings its repayments with it", () => {
  const c = coverageOf({
    cash: d("0"),
    today: TODAY,
    obligations: [ob({ id: "hall", amount: d("800"), dueDate: day("2026-12-05") })],
    sources: [
      source({
        id: "loan",
        kind: "LOAN",
        status: "PLEDGED",
        amount: d("1000"),
        expectedAt: day("2026-12-01"),
        repayments: [{ id: "r", amount: d("1000"), dueDate: day("2027-01-01"), status: "PLANNED", note: null }],
      }),
    ],
  });
  assert.equal(c.withPledges.firstShort?.id, "r");
  assert.equal(s(c.withPledges.end), "-800");
  // Not owed while it has not arrived (G33): no loan in what is on him now.
  assert.equal(c.hasLoan, false);
});

test("D103: one verdict: nothing due, covered, covered if the promise comes, short", () => {
  const at = (cash: string, pledge: string | null) =>
    coverageVerdict(
      coverageOf({
        cash: d(cash),
        today: TODAY,
        obligations: [ob({ id: "hall", amount: d("1000"), dueDate: day("2026-12-20") })],
        sources: pledge
          ? [source({ id: "p", status: "PLEDGED", amount: d(pledge), expectedAt: day("2026-12-10") })]
          : [],
      }),
    );
  assert.equal(at("1000", null), "COVERED");
  assert.equal(at("600", "400"), "COVERED_IF_PLEDGES");
  assert.equal(at("600", "300"), "SHORT");
  assert.equal(
    coverageVerdict(coverageOf({ cash: d("5"), today: TODAY, obligations: [], sources: [] })),
    "NOTHING_DUE",
  );
});

test("D103: nothing on the owner covers trivially", () => {
  const c = coverageOf({ cash: d("70"), today: TODAY, obligations: [], sources: [] });
  assert.equal(s(c.total), "0");
  assert.equal(c.withPledges.firstShort, null);
  assert.equal(s(c.withPledges.end), "70");
  assert.equal(c.lastDate, null);
});

// ----------------------------------------------------------------- D108

test("D108: one line per person: what they gave, promised, paid for him, still owe", () => {
  const people = familyContributions({
    zero: ZERO,
    sources: [
      { contributorName: "الوالد", sourceName: "دعم الوالد", amount: d("2400000"), status: "RECEIVED", kind: "FAMILY_SUPPORT" },
      { contributorName: " الوالد  ", sourceName: "وعد الوالد", amount: d("500000"), status: "PLEDGED", kind: "FAMILY_SUPPORT" },
      { contributorName: "خالي أحمد", sourceName: "سلفة خالي", amount: d("1000000"), status: "RECEIVED", kind: "LOAN" },
      { contributorName: null, sourceName: "مدخراتي", amount: d("900000"), status: "RECEIVED", kind: "SAVINGS" },
    ],
    costs: [
      { totalAmount: d("3000000"), paid: d("1300000"), payer: "FAMILY", payerName: "الوالد", ownerMoney: false },
      { totalAmount: d("200000"), paid: d("0"), payer: "FAMILY", payerName: null, ownerMoney: false },
      { totalAmount: d("900000"), paid: d("900000"), payer: "GROOM", payerName: null, ownerMoney: true },
    ],
  });
  assert.deepEqual(
    people.map((p) => [p.name, p.payer, s(p.gave), s(p.promised), s(p.paid), s(p.left), p.costsCount]),
    [
      ["الوالد", "FAMILY", "2400000", "500000", "1300000", "1700000", 1],
      [null, "FAMILY", "0", "0", "0", "200000", 1],
    ],
  );
});

test("D108: names match after folding spaces and case, nothing else", () => {
  assert.equal(contributorKey("  أبو   محمد "), "أبو محمد");
  assert.equal(contributorKey("Ali"), contributorKey("ALI"));
  assert.equal(contributorKey("   "), null);
  assert.notEqual(contributorKey("الوالد"), contributorKey("والدي"));
});

test("D108: family support and gifts are from the one they were recorded as", () => {
  const people = familyContributions({
    zero: ZERO,
    sources: [
      // The form asks «من مين؟ الوالد» and sends no contributor: it is his.
      { contributorName: null, sourceName: "الوالد", amount: d("1000000"), status: "RECEIVED", kind: "FAMILY_SUPPORT" },
      { contributorName: null, sourceName: " خالي  ", amount: d("200000"), status: "PLEDGED", kind: "GIFT" },
      // A contributor named wins over what it was recorded as.
      { contributorName: "الوالدة", sourceName: "ذهب الوالدة", amount: d("300000"), status: "RECEIVED", kind: "GIFT" },
      // Savings, a loan, the mahr and anything else are no one's help.
      { contributorName: null, sourceName: "مدخراتي", amount: d("900000"), status: "RECEIVED", kind: "SAVINGS" },
      { contributorName: null, sourceName: "خالي", amount: d("400000"), status: "RECEIVED", kind: "LOAN" },
      { contributorName: null, sourceName: "صاحبي", amount: d("50000"), status: "RECEIVED", kind: "OTHER" },
    ],
    // Paid for him by «الوالد»: the same person as the source above.
    costs: [{ totalAmount: d("500000"), paid: d("100000"), payer: "FAMILY", payerName: "الوالد", ownerMoney: false }],
  });
  assert.deepEqual(
    people.map((p) => [p.name, s(p.gave), s(p.promised), s(p.paid), s(p.left)]),
    [
      ["الوالد", "1000000", "0", "100000", "400000"],
      ["الوالدة", "300000", "0", "0", "0"],
      ["خالي", "0", "200000", "0", "0"],
    ],
  );
});
