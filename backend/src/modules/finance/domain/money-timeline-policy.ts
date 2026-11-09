import type { Prisma } from '@prisma/client';

type Amount = Prisma.Decimal;

const RIYADH_OFFSET_MS = 3 * 60 * 60 * 1000;

/**
 * The day in Riyadh (D11) a moment falls on, as YYYY-MM-DD: the one rule the
 * money's dates, their reminder days and the reminders' keys agree on
 * (other contexts read it through the finance port).
 */
export function riyadhDay(moment: Date): string {
  return new Date(moment.getTime() + RIYADH_OFFSET_MS).toISOString().slice(0, 10);
}

/** The month in Riyadh a moment falls on, as YYYY-MM. */
export function riyadhMonth(moment: Date): string {
  return riyadhDay(moment).slice(0, 7);
}

// ---------------------------------------------------------------------------
// What is still to pay (D102, D106)
// ---------------------------------------------------------------------------

export interface TimelineCost {
  id: string;
  budgetCategoryId: string;
  title: string;
  totalAmount: Amount;
  /** Net of reversals. */
  paid: Amount;
  payer: string | null;
  payerName: string | null;
  /** D59: its payments come out of the owner's money. */
  ownerMoney: boolean;
  mahr: boolean;
}

export interface TimelineSchedule {
  id: string;
  weddingCostId: string;
  /** Its amount now: a partial payment lowered it (D106). */
  amount: Amount;
  dueDate: Date;
  status: 'PENDING' | 'PAID' | 'CANCELLED';
  note: string | null;
  remindAt: Date | null;
  rescheduledFrom: Date | null;
  /** What live partial payments took off it (D106): amount + this = as agreed. */
  partlyPaid: Amount;
  createdAt: Date;
}

export interface TimelineRepayment {
  id: string;
  amount: Amount;
  dueDate: Date | null;
  status: 'PLANNED' | 'PAID' | 'CANCELLED';
  note: string | null;
}

export interface TimelineSource {
  id: string;
  kind: string;
  sourceName: string;
  amount: Amount;
  status: 'RECEIVED' | 'PLEDGED';
  expectedAt: Date | null;
  repayments: readonly TimelineRepayment[];
}

export type ObligationKind = 'DUE' | 'UNDATED' | 'LOAN_REPAYMENT' | 'LOAN_UNPLANNED';

export interface Obligation {
  kind: ObligationKind;
  /** The schedule (DUE), the agreement (UNDATED), the repayment, or the loan (LOAN_UNPLANNED). */
  id: string;
  weddingCostId: string | null;
  budgetCategoryId: string | null;
  fundingSourceId: string | null;
  title: string;
  note: string | null;
  /** What is still to pay on it now. */
  amount: Amount;
  /** DUE: the date's amount as agreed, before partial payments (D106). */
  scheduledAmount: Amount;
  /** DUE: what was already paid towards it (partial payments). */
  paidTowards: Amount;
  dueDate: Date | null;
  isOverdue: boolean;
  remindAt: Date | null;
  rescheduledFrom: Date | null;
  payer: string | null;
  payerName: string | null;
  /** On the owner (D59): his agreements, and his loans. */
  ownerMoney: boolean;
  mahr: boolean;
}

/**
 * The open part of each pending date of one agreement (RA-BE-53): dates are
 * reminders, not reservations, so together they never ask for more than the
 * agreement still owes. Earlier dates come first; each takes the lesser of
 * its amount and what the earlier ones left.
 */
export function openScheduleAmounts(
  cost: Pick<TimelineCost, 'totalAmount' | 'paid'>,
  schedules: readonly TimelineSchedule[],
): Map<string, Amount> {
  const pending = schedules
    .filter((schedule) => schedule.status === 'PENDING')
    .sort(
      (a, b) =>
        a.dueDate.getTime() - b.dueDate.getTime() ||
        a.createdAt.getTime() - b.createdAt.getTime() ||
        a.id.localeCompare(b.id),
    );
  const owed = cost.totalAmount.minus(cost.paid);
  let room = owed.gt(0) ? owed : owed.mul(0);
  const open = new Map<string, Amount>();
  for (const schedule of pending) {
    const amount = schedule.amount.lt(room) ? schedule.amount : room;
    open.set(schedule.id, amount);
    room = room.minus(amount);
  }
  return open;
}

/**
 * Everything still to pay, one line each: every pending date (its open part),
 * the undated rest of each agreement, and (for the owner, whose loans they
 * are) each planned loan repayment and the part of a loan with no plan yet.
 * A promised loan is owed only once it arrived (G33). Dated lines first by
 * day, undated after.
 */
export function listObligations(input: {
  costs: readonly TimelineCost[];
  schedules: readonly TimelineSchedule[];
  sources: readonly TimelineSource[] | null;
  today: Date;
  zero: Amount;
}): Obligation[] {
  const { today } = input;
  const ZERO = input.zero;
  const out: Obligation[] = [];
  const schedulesByCost = new Map<string, TimelineSchedule[]>();
  for (const schedule of input.schedules) {
    const list = schedulesByCost.get(schedule.weddingCostId) ?? [];
    list.push(schedule);
    schedulesByCost.set(schedule.weddingCostId, list);
  }
  for (const cost of input.costs) {
    const schedules = schedulesByCost.get(cost.id) ?? [];
    const open = openScheduleAmounts(cost, schedules);
    let dated = ZERO;
    for (const schedule of schedules) {
      const amount = open.get(schedule.id);
      if (!amount || amount.lte(0)) continue;
      dated = dated.plus(amount);
      out.push({
        kind: 'DUE',
        id: schedule.id,
        weddingCostId: cost.id,
        budgetCategoryId: cost.budgetCategoryId,
        fundingSourceId: null,
        title: cost.title,
        note: schedule.note,
        amount,
        scheduledAmount: schedule.amount.plus(schedule.partlyPaid),
        paidTowards: schedule.partlyPaid,
        dueDate: schedule.dueDate,
        isOverdue: schedule.dueDate < today,
        remindAt: schedule.remindAt,
        rescheduledFrom: schedule.rescheduledFrom,
        payer: cost.payer,
        payerName: cost.payerName,
        ownerMoney: cost.ownerMoney,
        mahr: cost.mahr,
      });
    }
    const rest = cost.totalAmount.minus(cost.paid).minus(dated);
    if (rest.gt(0)) {
      out.push({
        kind: 'UNDATED',
        id: cost.id,
        weddingCostId: cost.id,
        budgetCategoryId: cost.budgetCategoryId,
        fundingSourceId: null,
        title: cost.title,
        note: null,
        amount: rest,
        scheduledAmount: rest,
        paidTowards: ZERO,
        dueDate: null,
        isOverdue: false,
        remindAt: null,
        rescheduledFrom: null,
        payer: cost.payer,
        payerName: cost.payerName,
        ownerMoney: cost.ownerMoney,
        mahr: cost.mahr,
      });
    }
  }
  for (const source of input.sources ?? []) {
    if (source.kind !== 'LOAN' || source.status !== 'RECEIVED') continue;
    out.push(...loanObligations(source, today, ZERO));
  }
  return sortByDay(out, (line) => line.dueDate);
}

function loanObligations(source: TimelineSource, today: Date, ZERO: Amount): Obligation[] {
  const out: Obligation[] = [];
  let repaid = ZERO;
  let planned = ZERO;
  for (const repayment of source.repayments) {
    if (repayment.status === 'PAID') {
      repaid = repaid.plus(repayment.amount);
      continue;
    }
    if (repayment.status !== 'PLANNED') continue;
    planned = planned.plus(repayment.amount);
    out.push({
      kind: 'LOAN_REPAYMENT',
      id: repayment.id,
      weddingCostId: null,
      budgetCategoryId: null,
      fundingSourceId: source.id,
      title: source.sourceName,
      note: repayment.note,
      amount: repayment.amount,
      scheduledAmount: repayment.amount,
      paidTowards: ZERO,
      dueDate: repayment.dueDate,
      isOverdue: repayment.dueDate !== null && repayment.dueDate < today,
      remindAt: null,
      rescheduledFrom: null,
      payer: null,
      payerName: null,
      ownerMoney: true,
      mahr: false,
    });
  }
  const unplanned = source.amount.minus(repaid).minus(planned);
  if (unplanned.gt(0)) {
    out.push({
      kind: 'LOAN_UNPLANNED',
      id: source.id,
      weddingCostId: null,
      budgetCategoryId: null,
      fundingSourceId: source.id,
      title: source.sourceName,
      note: null,
      amount: unplanned,
      scheduledAmount: unplanned,
      paidTowards: ZERO,
      dueDate: null,
      isOverdue: false,
      remindAt: null,
      rescheduledFrom: null,
      payer: null,
      payerName: null,
      ownerMoney: true,
      mahr: false,
    });
  }
  return out;
}

/** Stable: by Riyadh day, undated last; the input order breaks ties. */
function sortByDay<T>(rows: readonly T[], dayOf: (row: T) => Date | null): T[] {
  return rows
    .map((row, index) => ({ row, index, day: dayOf(row) }))
    .sort((a, b) => {
      if (a.day === null || b.day === null) {
        return (a.day === null ? 1 : 0) - (b.day === null ? 1 : 0) || a.index - b.index;
      }
      const ak = riyadhDay(a.day);
      const bk = riyadhDay(b.day);
      return ak < bk ? -1 : ak > bk ? 1 : a.index - b.index;
    })
    .map((entry) => entry.row);
}

// ---------------------------------------------------------------------------
// The wedding's dues by month (D102): loans are not wedding dues.
// ---------------------------------------------------------------------------

export interface MonthTotal {
  month: string;
  amount: Amount;
  ownerAmount: Amount;
  count: number;
}

export interface DuesByMonth {
  months: MonthTotal[];
  overdue: { amount: Amount; ownerAmount: Amount; count: number };
  undated: { amount: Amount; ownerAmount: Amount; count: number };
}

export function weddingDuesByMonth(
  obligations: readonly Obligation[],
  zero: Amount,
): DuesByMonth {
  const ZERO = zero;
  const months = new Map<string, MonthTotal>();
  const overdue = { amount: ZERO, ownerAmount: ZERO, count: 0 };
  const undated = { amount: ZERO, ownerAmount: ZERO, count: 0 };
  const add = (bucket: { amount: Amount; ownerAmount: Amount; count: number }, line: Obligation) => {
    bucket.amount = bucket.amount.plus(line.amount);
    if (line.ownerMoney) bucket.ownerAmount = bucket.ownerAmount.plus(line.amount);
    bucket.count += 1;
  };
  for (const line of obligations) {
    if (line.kind !== 'DUE' && line.kind !== 'UNDATED') continue;
    if (line.dueDate === null) {
      add(undated, line);
      continue;
    }
    if (line.isOverdue) {
      add(overdue, line);
      continue;
    }
    const key = riyadhMonth(line.dueDate);
    const bucket = months.get(key) ?? { month: key, amount: ZERO, ownerAmount: ZERO, count: 0 };
    add(bucket, line);
    months.set(key, bucket);
  }
  return {
    months: [...months.values()].sort((a, b) => (a.month < b.month ? -1 : 1)),
    overdue,
    undated,
  };
}

// ---------------------------------------------------------------------------
// Will the owner's money cover what is on him, in time? (D103, D104)
// ---------------------------------------------------------------------------

export type CoverageStepKind =
  | 'DUE'
  | 'MAHR'
  | 'UNDATED'
  | 'LOAN_REPAYMENT'
  | 'LOAN_UNPLANNED'
  | 'PLEDGE';

export interface CoverageStep {
  kind: CoverageStepKind;
  /** The obligation's or the pledge's id. */
  id: string;
  /** The day it counts on: a late line counts today; null goes last. */
  date: Date | null;
  /** The line was due before today (it counts today). */
  late: boolean;
  title: string;
  note: string | null;
  amount: Amount;
  /** In (a pledge arriving) or out. */
  inflow: boolean;
  /** What is left after it. */
  balance: Amount;
}

export interface CoverageRun {
  steps: CoverageStep[];
  /** The first line the money does not reach, and by how much on that day. */
  firstShort: { date: Date | null; amount: Amount; title: string; id: string } | null;
  /**
   * The deepest the money falls below zero, and on which line: what is
   * needed beyond it for everything to be paid on its day. Null: it never does.
   */
  deepest: { date: Date | null; amount: Amount; title: string; id: string } | null;
  /** What is left after everything (negative: short by that much in all). */
  end: Amount;
}

export interface CoveragePledge {
  id: string;
  sourceName: string;
  amount: Amount;
  expectedAt: Date | null;
}

export interface Coverage {
  /** «معك» now (D104). */
  cash: Amount;
  /** Everything on the owner: his share, the mahr with it, his loans. */
  total: Amount;
  /** Of `total`, what has no date (counted last). */
  undated: Amount;
  /** The last dated line on him. */
  lastDate: Date | null;
  hasLoan: boolean;
  /** Without any promised money. */
  withoutPledges: CoverageRun;
  /** With the promised money that has a day still to come. */
  withPledges: CoverageRun;
  pledgesCounted: CoveragePledge[];
  /** Promised money left out: no day, or its day passed. */
  pledgesIgnored: Array<CoveragePledge & { reason: 'NO_DATE' | 'LATE' }>;
}

/**
 * D103: starting from «معك», take off everything on the owner on its day (his
 * share of the agreements, the mahr with it, and his loans' repayments); add
 * promised money only when it has a day that has not passed. Undated lines go
 * last; a late line counts today. On one day, what goes out is counted before
 * what comes in (the cautious order). What is on the family is not his, and
 * estimates are an «if», not a commitment, so neither is counted here.
 * A promised loan, when its money is counted, brings its repayments with it.
 */
export function coverageOf(input: {
  cash: Amount;
  obligations: readonly Obligation[];
  sources: readonly TimelineSource[];
  today: Date;
}): Coverage {
  const { today } = input;
  const ZERO = input.cash.mul(0);
  const outflows: CoverageStep[] = input.obligations
    .filter((line) => line.ownerMoney)
    .map((line) => outflow(line, today, ZERO));
  const counted: Array<{ source: TimelineSource; pledge: CoveragePledge }> = [];
  const ignored: Coverage['pledgesIgnored'] = [];
  for (const source of input.sources) {
    if (source.status !== 'PLEDGED') continue;
    const pledge = {
      id: source.id,
      sourceName: source.sourceName,
      amount: source.amount,
      expectedAt: source.expectedAt,
    };
    if (source.expectedAt === null) ignored.push({ ...pledge, reason: 'NO_DATE' });
    else if (source.expectedAt < today) ignored.push({ ...pledge, reason: 'LATE' });
    else counted.push({ source, pledge });
  }
  const pledgeLines: CoverageStep[] = [];
  for (const { source, pledge } of counted) {
    pledgeLines.push({
      kind: 'PLEDGE',
      id: pledge.id,
      date: pledge.expectedAt,
      late: false,
      title: pledge.sourceName,
      note: null,
      amount: pledge.amount,
      inflow: true,
      balance: ZERO,
    });
    if (source.kind === 'LOAN') {
      for (const line of loanObligations({ ...source, status: 'RECEIVED' }, today, ZERO)) {
        pledgeLines.push(outflow(line, today, ZERO));
      }
    }
  }
  const dated = outflows.filter((line) => line.date !== null).map((line) => line.date as Date);
  return {
    cash: input.cash,
    total: outflows.reduce((sum, line) => sum.plus(line.amount), ZERO),
    undated: outflows
      .filter((line) => line.date === null)
      .reduce((sum, line) => sum.plus(line.amount), ZERO),
    lastDate: dated.length
      ? dated.reduce((last, day) => (day > last ? day : last))
      : null,
    hasLoan: outflows.some(
      (line) => line.kind === 'LOAN_REPAYMENT' || line.kind === 'LOAN_UNPLANNED',
    ),
    withoutPledges: run(input.cash, outflows),
    withPledges: run(input.cash, [...outflows, ...pledgeLines]),
    pledgesCounted: counted.map((entry) => entry.pledge),
    pledgesIgnored: ignored,
  };
}

function outflow(line: Obligation, today: Date, ZERO: Amount): CoverageStep {
  const late = line.dueDate !== null && line.dueDate < today;
  return {
    kind:
      line.kind === 'DUE' ? (line.mahr ? 'MAHR' : 'DUE') : line.kind,
    id: line.id,
    date: line.dueDate === null ? null : late ? today : line.dueDate,
    late,
    title: line.title,
    note: line.note,
    amount: line.amount,
    inflow: false,
    balance: ZERO,
  };
}

function run(cash: Amount, lines: readonly CoverageStep[]): CoverageRun {
  const ordered = lines
    .map((line, index) => ({ line, index }))
    .sort((a, b) => {
      const ad = a.line.date;
      const bd = b.line.date;
      if (ad === null || bd === null) {
        return (ad === null ? 1 : 0) - (bd === null ? 1 : 0) || a.index - b.index;
      }
      const ak = riyadhDay(ad);
      const bk = riyadhDay(bd);
      if (ak !== bk) return ak < bk ? -1 : 1;
      return Number(a.line.inflow) - Number(b.line.inflow) || a.index - b.index;
    })
    .map((entry) => entry.line);
  let balance = cash;
  let firstShort: CoverageRun['firstShort'] = null;
  let deepest: CoverageRun['deepest'] = null;
  const steps = ordered.map((line) => {
    balance = line.inflow ? balance.plus(line.amount) : balance.minus(line.amount);
    if (balance.lt(0)) {
      const short = { date: line.date, amount: balance.negated(), title: line.title, id: line.id };
      firstShort = firstShort ?? short;
      if (!deepest || short.amount.gt(deepest.amount)) deepest = short;
    }
    return { ...line, balance };
  });
  return { steps, firstShort, deepest, end: balance };
}

export type CoverageVerdict = 'NOTHING_DUE' | 'COVERED' | 'COVERED_IF_PLEDGES' | 'SHORT';

/**
 * D103, the one verdict every screen and the assistant say: nothing is on
 * him; his money covers everything on its day; it does only if the promised
 * money arrives on its day; or it falls short (on `withPledges.firstShort`).
 */
export function coverageVerdict(coverage: Coverage): CoverageVerdict {
  if (coverage.total.lte(0)) return 'NOTHING_DUE';
  if (coverage.withoutPledges.deepest === null) return 'COVERED';
  if (coverage.withPledges.deepest === null) return 'COVERED_IF_PLEDGES';
  return 'SHORT';
}

/**
 * D103: what is missing, said only with the verdict that the money falls
 * short: the deepest it falls with the promised money counted. A promised
 * loan brings its repayments with it, and one set before the loan arrives
 * dips that run while the money in hand covers everything by itself
 * (RA-BE-115); every screen, warning and the assistant read it here.
 */
export function coverageShortfall(coverage: Coverage): Amount | null {
  return coverageVerdict(coverage) === 'SHORT'
    ? (coverage.withPledges.deepest?.amount ?? null)
    : null;
}
