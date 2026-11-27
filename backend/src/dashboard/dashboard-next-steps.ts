import { Prisma, WeddingTaskPriority } from "@prisma/client";
import type {
  DashboardDueMoneyItem,
  DashboardImportantItemResponse,
  DashboardTaskRecord,
} from "./dashboard.contracts";
import type {
  DashboardNextStepResponse,
  DashboardNextStepType,
} from "./dashboard-setup.contracts";
import {
  AFTER_WEDDING_TIERS,
  BEFORE_WEDDING_TIERS,
  LATE_TASK_WINDOW_DAYS,
  type NextStepKind,
  orderNextSteps,
  PAYMENT_SOON_DAYS,
  type RankedNextStep,
  SETUP_STEPS_AFTER_DAYS,
  UNCONFIRMED_BOOKING_WINDOW_DAYS,
} from "./dashboard-priority";
import type { PlanEssential, PlanEssentialKey } from "./plan-essentials";
import {
  type AddressedText,
  type AddressForm,
  textFor,
} from "../shared-kernel/voice/address-form";
import {
  dayCountWords,
  daysBetween,
  weekdayDayMonthWords,
  whenWords,
} from "../shared-kernel/voice/day-words";
import { planWord } from "../shared-kernel/voice/plan-word";
import { NEXT_STEP_COPY } from "../shared-kernel/copy/next-steps.ar";

/** A booking the customer asked for and its provider has not confirmed. */
export interface UnconfirmedBookingFact {
  quoteRequestId: string;
  providerName: string;
  eventDate: Date;
}

/** The owner's loan still owed (the owner alone reads his funding). */
export interface OutstandingLoanFact {
  /** Exact decimal string, above zero. */
  outstanding: string;
  /** The source of the nearest planned repayment, if one is planned. */
  fundingSourceId: string | null;
  nextDueDate: Date | null;
}

export interface NextStepFacts {
  weddingPlanId: string;
  /** The plan's wedding day; null before one is set. */
  weddingDate: Date | null;
  /**
   * The open tasks due today or late (the window is enforced here too: a
   * task late by more than seven days is never a step).
   */
  tasks: DashboardTaskRecord[];
  /** The plan's nearest open task due after today (or none). */
  nextTask?: DashboardTaskRecord | null;
  /** G23's first essential still open and not answered away. */
  missingEssential?:
    | (Pick<PlanEssential, "key" | "budgetCategoryId"> & {
        /** The plan's own item name; the fixed word when it is missing. */
        name?: string | null;
      })
    | null;
  /** The pending payment dates the reader may see (none without money rights). */
  paymentSchedules: DashboardDueMoneyItem[];
  /** The plan's bookings asked for and not confirmed, their day not passed. */
  unconfirmedBookings?: UnconfirmedBookingFact[];
  today: Date;
  receivedQuotes: number;
  hasLocation: boolean;
  hasBudget: boolean;
  guestCount: number;
  quoteRequestsCount: number;
  acceptedProviders: number;
  /**
   * After the wedding: the providers the reader may rate now and has not
   * rated (`countPlanProvidersToRate`). Absent before the wedding.
   */
  providersToRate?: number;
  /**
   * RA-MO-147: every step of D78's chain is offered only to a reader who may
   * take it, as the guests' already was (RA-BE-121). «أكمل موقع الزفاف» was
   * asked of a viewer the server then refused.
   */
  canManagePlan: boolean;
  /** A reader who may record a payment is offered that; others only read it. */
  canManageMoney: boolean;
  /** «أضف أول ضيف» opens the adding: only for a reader who may add (RA-BE-121). */
  canManageGuests: boolean;
  /**
   * «اطلب أول عرض سعر» sends a request, and the providers' own pages (a
   * request, the reviews) open only for this reader on the phone.
   */
  canManageProviders: boolean;
  /** The reader's form (B5): the next steps speak to them. */
  form: AddressForm;
  /** Whose wedding the plan is: the bride's guests are «الضيفات». */
  planPersona: string | null;
  /**
   * Whether the plan's mahr is recorded; null when the reader may not record
   * or see it (only the owner records it), so no step is invented.
   */
  mahrRecorded?: boolean | null;
  /**
   * The plan's wedding agreements, the mahr's not counted; null for a reader
   * who does not see the plan's money.
   */
  weddingCostsCount?: number | null;
  /** D114: the groom chose to count the mahr in his budget. */
  mahrInsideBudget?: boolean;
  /**
   * What is left on the owner with no day to pay it (finance's undated dues,
   * the owner's part); null for a reader who does not see the owner's money.
   */
  undatedOwnerDebt?: string | null;
  /** The owner's loan still owed; null for anyone else, or none owed. */
  loan?: OutstandingLoanFact | null;
}

/** A catalog line in the reader's form (B5). */
type Say = (text: AddressedText) => string;
type Ranked = RankedNextStep<DashboardNextStepResponse>;

/**
 * REFINEMENT_SPEC 2.1: the home's next steps, first first, decided here
 * alone; the phone shows the first one and up to two more under it. Before
 * the wedding (or with no date) and after it, each in the spec's order
 * (`dashboard-priority.ts`). A step is offered only to a reader who may take
 * it, and names the thing, says why it is first and offers the one action
 * that moves it; an amount stays data so «أخفِ المبالغ» can hide it.
 */
export function buildImportantItems(
  facts: NextStepFacts,
): DashboardNextStepResponse[] {
  const say: Say = (text) => textFor(facts.form, text);
  const daysToWedding = facts.weddingDate
    ? daysBetween(facts.today, facts.weddingDate)
    : null;
  return orderNextSteps(
    daysToWedding !== null && daysToWedding < 0
      ? afterWeddingSteps(facts, say)
      : beforeWeddingSteps(facts, daysToWedding, say),
  );
}

function beforeWeddingSteps(
  facts: NextStepFacts,
  daysToWedding: number | null,
  say: Say,
): Ranked[] {
  const tier = BEFORE_WEDDING_TIERS;
  const { weddingPlanId, today } = facts;
  const steps: Ranked[] = [];

  // 1 and 4: a payment due today or late, the oldest first and the larger
  // first on the same day; then one due within the week, by its day.
  for (const schedule of facts.paymentSchedules) {
    const days = daysBetween(today, schedule.dueDate);
    if (days > PAYMENT_SOON_DAYS) continue;
    steps.push(
      ranked(
        days <= 0 ? tier.PAYMENT_DUE : tier.PAYMENT_SOON,
        schedule.dueDate.getTime(),
        schedule.amount,
        "PAYMENT",
        paymentStep(weddingPlanId, schedule, days, facts.canManageMoney, say),
      ),
    );
  }

  // 2: a booking its provider has not confirmed, with the wedding this week.
  if (
    facts.canManageProviders &&
    daysToWedding !== null &&
    daysToWedding <= UNCONFIRMED_BOOKING_WINDOW_DAYS
  ) {
    for (const booking of facts.unconfirmedBookings ?? []) {
      steps.push(
        ranked(
          tier.BOOKING_UNCONFIRMED,
          booking.eventDate.getTime(),
          null,
          "OTHER",
          unconfirmedBookingStep(
            weddingPlanId,
            booking,
            daysToWedding,
            facts.form,
          ),
        ),
      );
    }
  }

  // 3 and 8: a task due today, then one late by up to seven days, the
  // nearest day first. One late by more stays in the tasks' counts only.
  for (const task of facts.tasks) {
    if (!task.dueDate) continue;
    const days = daysBetween(today, task.dueDate);
    if (days > 0 || days < -LATE_TASK_WINDOW_DAYS) continue;
    steps.push(
      ranked(
        tier.TASK_DUE,
        -days,
        null,
        "TASK",
        dueTaskStep(weddingPlanId, { ...task, dueDate: task.dueDate }, days, say),
      ),
    );
  }

  // 5: offers that arrived.
  if (facts.receivedQuotes > 0) {
    steps.push(
      ranked(
        tier.QUOTE_RECEIVED,
        0,
        null,
        "QUOTE",
        receivedQuotesStep(weddingPlanId, facts.receivedQuotes, say),
      ),
    );
  }

  // 6: D78's chain, only while the wedding is more than thirty days away or
  // has no day; each step only while it is missing.
  const setup =
    daysToWedding === null || daysToWedding > SETUP_STEPS_AFTER_DAYS
      ? setupSteps(facts, say)
      : [];
  setup.forEach((step, index) =>
    steps.push(ranked(tier.SETUP, index, null, "OTHER", step)),
  );

  // 7: the nearest task with a day, then the first essential the plan still
  // has open, in G23's order (the venue first). Review 2026-11-18: beside
  // «اطلب أول عرض سعر» a missing essential said the same step twice.
  const upcoming = facts.nextTask;
  if (upcoming?.dueDate) {
    const days = daysBetween(today, upcoming.dueDate);
    if (days > 0) {
      steps.push(
        ranked(
          tier.LATER,
          0,
          null,
          "TASK",
          upcomingTaskStep(
            weddingPlanId,
            { ...upcoming, dueDate: upcoming.dueDate },
            days,
            say,
          ),
        ),
      );
    }
  }
  const asksQuotes = setup.some((step) => step.type === "REQUEST_QUOTE");
  const essential = facts.missingEssential;
  if (
    !asksQuotes &&
    essential?.budgetCategoryId &&
    facts.canManageMoney &&
    facts.canManageProviders
  ) {
    steps.push(
      ranked(
        tier.LATER,
        1,
        null,
        "OTHER",
        missingEssentialStep(
          weddingPlanId,
          essential.budgetCategoryId,
          essential.name?.trim() ||
            essentialName(essential.key, facts.planPersona),
          essential.key,
          say,
        ),
      ),
    );
  }
  return steps;
}

function afterWeddingSteps(facts: NextStepFacts, say: Say): Ranked[] {
  const tier = AFTER_WEDDING_TIERS;
  const { weddingPlanId, today } = facts;
  const steps: Ranked[] = [];

  // 1: a payment due today or late, the oldest first.
  for (const schedule of facts.paymentSchedules) {
    const days = daysBetween(today, schedule.dueDate);
    if (days > 0) continue;
    steps.push(
      ranked(
        tier.PAYMENT_DUE,
        schedule.dueDate.getTime(),
        schedule.amount,
        "PAYMENT",
        paymentStep(weddingPlanId, schedule, days, facts.canManageMoney, say),
      ),
    );
  }

  // 2: the nearest payment still to come, whatever its day.
  const next = [...facts.paymentSchedules]
    .filter((schedule) => daysBetween(today, schedule.dueDate) > 0)
    .sort(
      (a, b) =>
        a.dueDate.getTime() - b.dueDate.getTime() ||
        b.amount.comparedTo(a.amount),
    )[0];
  if (next) {
    steps.push(
      ranked(
        tier.PAYMENT_NEXT,
        0,
        null,
        "PAYMENT",
        paymentStep(
          weddingPlanId,
          next,
          daysBetween(today, next.dueDate),
          facts.canManageMoney,
          say,
        ),
      ),
    );
  }

  // 3: what is owed with no day to pay it.
  if (
    facts.undatedOwnerDebt &&
    new Prisma.Decimal(facts.undatedOwnerDebt).greaterThan(0)
  ) {
    steps.push(
      ranked(
        tier.DEBT_UNDATED,
        0,
        null,
        "PAYMENT",
        undatedDebtStep(
          weddingPlanId,
          facts.undatedOwnerDebt,
          facts.canManageMoney,
          facts.form,
        ),
      ),
    );
  }

  // 4: a loan still owed.
  if (facts.loan && new Prisma.Decimal(facts.loan.outstanding).greaterThan(0)) {
    steps.push(
      ranked(
        tier.LOAN_OUTSTANDING,
        0,
        null,
        "PAYMENT",
        loanStep(weddingPlanId, facts.loan, today, facts.form),
      ),
    );
  }

  // 5: the providers the reader may rate and has not rated. It was asked of
  // every reader with a provider linked to the plan: of one whose booking
  // was never confirmed (the server then refused the review), of a partner
  // who sent no request, and for ever after every review was written.
  if ((facts.providersToRate ?? 0) > 0) {
    steps.push(
      ranked(
        tier.RATE_PROVIDERS,
        0,
        null,
        "OTHER",
        rateProvidersStep(weddingPlanId, facts.form),
      ),
    );
  }
  return steps;
}

function ranked(
  tier: number,
  key: number,
  amount: Prisma.Decimal | null,
  kind: NextStepKind,
  step: DashboardNextStepResponse,
): Ranked {
  return { tier, key, amount, kind, step };
}

function paymentStep(
  weddingPlanId: string,
  schedule: DashboardDueMoneyItem,
  days: number,
  canManageMoney: boolean,
  say: Say,
): DashboardNextStepResponse {
  const copy = NEXT_STEP_COPY.payment;
  const overdue = days < 0;
  const scheduleRoute = `/wedding-plans/${weddingPlanId}/money/costs/${schedule.weddingCostId}/schedules/${schedule.id}`;
  const routeTarget = canManageMoney ? `${scheduleRoute}/pay` : scheduleRoute;
  return {
    id: schedule.id,
    type: "PAYMENT_SCHEDULE_DUE",
    title: schedule.title,
    // RA-MO-161: «القاعة · موعدها بعد 5 أيام» read as the hall's day;
    // it is a payment to it.
    subtitle: overdue
      ? copy.overdue(dayCountWords(-days))
      : copy.due(whenWords(days)),
    body: weekdayDayMonthWords(schedule.dueDate),
    icon: "wallet",
    tone: overdue ? "danger" : days <= PAYMENT_SOON_DAYS ? "warning" : "info",
    priority: overdue
      ? "URGENT"
      : days <= PAYMENT_SOON_DAYS
        ? "HIGH"
        : "NORMAL",
    actionLabel: say(canManageMoney ? copy.record : copy.open),
    dueDate: schedule.dueDate,
    amount: schedule.amount.toString(),
    route: routeTarget,
    routeTarget,
    entityId: schedule.id,
    data: {
      weddingPlanId,
      weddingCostId: schedule.weddingCostId,
      paymentScheduleId: schedule.id,
    },
  };
}

function unconfirmedBookingStep(
  weddingPlanId: string,
  booking: UnconfirmedBookingFact,
  daysToWedding: number,
  form: AddressForm,
): DashboardNextStepResponse {
  const copy = NEXT_STEP_COPY.bookingUnconfirmed;
  const route = `/wedding-plans/${weddingPlanId}/providers/requests?quote=${encodeURIComponent(booking.quoteRequestId)}`;
  return {
    id: `booking-unconfirmed:${booking.quoteRequestId}`,
    type: "BOOKING_UNCONFIRMED",
    title: copy.title(booking.providerName),
    subtitle: textFor(form, copy.reason(whenWords(daysToWedding))),
    body: weekdayDayMonthWords(booking.eventDate),
    icon: "provider",
    tone: "danger",
    priority: "URGENT",
    actionLabel: textFor(form, copy.action),
    dueDate: booking.eventDate,
    amount: null,
    route,
    routeTarget: route,
    entityId: booking.quoteRequestId,
    data: { weddingPlanId, quoteRequestId: booking.quoteRequestId },
  };
}

function dueTaskStep(
  weddingPlanId: string,
  task: DashboardTaskRecord & { dueDate: Date },
  days: number,
  say: Say,
): DashboardNextStepResponse {
  const isOverdue = days < 0;
  const taskRoute = `/wedding-plans/${weddingPlanId}/tasks/${task.id}`;
  return {
    id: task.id,
    type: isOverdue ? "TASK_OVERDUE" : "TASK_TODAY",
    title: task.title,
    subtitle: isOverdue
      ? NEXT_STEP_COPY.task.overdue(dayCountWords(-days))
      : NEXT_STEP_COPY.task.due(whenWords(days)),
    body: weekdayDayMonthWords(task.dueDate),
    icon: "calendar",
    tone: isOverdue ? "danger" : toneForTaskPriority(task.priority),
    priority: isOverdue ? "URGENT" : "HIGH",
    actionLabel: say(NEXT_STEP_COPY.task.open),
    dueDate: task.dueDate,
    amount: null,
    route: taskRoute,
    routeTarget: taskRoute,
    entityId: task.id,
    data: { weddingPlanId, taskId: task.id },
  };
}

function receivedQuotesStep(
  weddingPlanId: string,
  receivedQuotes: number,
  say: Say,
): DashboardNextStepResponse {
  const copy = NEXT_STEP_COPY.quotesReceived;
  const providersRoute = `/wedding-plans/${weddingPlanId}/providers`;
  return {
    id: `quote-received:${weddingPlanId}`,
    type: "QUOTE_RECEIVED",
    title: copy.title(receivedQuotes),
    subtitle: say(copy.reason(receivedQuotes)),
    body: null,
    icon: "provider",
    tone: "warning",
    priority: "HIGH",
    actionLabel: say(copy.action(receivedQuotes)),
    dueDate: null,
    amount: null,
    route: providersRoute,
    routeTarget: providersRoute,
    entityId: null,
    data: { weddingPlanId },
  };
}

/**
 * D78's chain in its one order (J1-04): the date, the place, the budget, the
 * mahr, the first agreement, the guests, the first quote; each only while it
 * is missing and only for a reader who may record it. Rashad 2026-11-17: an
 * invitation that waits on the person invited is no step of the reader's.
 */
function setupSteps(
  facts: NextStepFacts,
  say: Say,
): DashboardNextStepResponse[] {
  const { weddingPlanId, planPersona } = facts;
  const copy = NEXT_STEP_COPY;
  const steps: DashboardNextStepResponse[] = [];
  if (facts.canManagePlan && facts.weddingDate === null) {
    steps.push(
      setupAction(
        weddingPlanId,
        "SET_DATE",
        say(copy.setDate.title),
        copy.setDate.reason,
        say(copy.setDate.action),
        `/wedding-plans/${weddingPlanId}/plan-center`,
      ),
    );
  }
  if (facts.canManagePlan && !facts.hasLocation) {
    steps.push(
      setupAction(
        weddingPlanId,
        "SET_LOCATION",
        say(copy.setLocation.title),
        copy.setLocation.reason,
        say(copy.setLocation.action),
        `/wedding-plans/${weddingPlanId}/plan-center`,
      ),
    );
  }
  if (facts.canManageMoney && !facts.hasBudget) {
    steps.push(
      setupAction(
        weddingPlanId,
        "SET_BUDGET",
        say(copy.setBudget.title),
        say(copy.setBudget.reason),
        say(copy.setBudget.action),
        `/wedding-plans/${weddingPlanId}/money/budget`,
      ),
    );
  }
  // J1-04: the mahr (a groom's or a bride's plan, outside the wedding
  // budget), then the first agreement.
  const planHasMahrSide = planPersona === "GROOM" || planPersona === "BRIDE";
  if (facts.canManageMoney && planHasMahrSide && facts.mahrRecorded === false) {
    steps.push(
      setupAction(
        weddingPlanId,
        "RECORD_MAHR",
        copy.recordMahr.title,
        say(
          facts.mahrInsideBudget
            ? copy.recordMahr.reasonInsideBudget
            : copy.recordMahr.reasonOutsideBudget,
        ),
        say(copy.recordMahr.action),
        `/wedding-plans/${weddingPlanId}/money/mahr`,
      ),
    );
  }
  if (facts.canManageMoney && facts.weddingCostsCount === 0) {
    steps.push(
      setupAction(
        weddingPlanId,
        "ADD_FIRST_COST",
        say(copy.addFirstCost.title),
        planWord(planPersona, copy.addFirstCost.reason),
        say(copy.addFirstCost.action),
        `/wedding-plans/${weddingPlanId}/money/costs/create`,
      ),
    );
  }
  if (facts.canManageGuests && facts.guestCount === 0) {
    // D55: the verb follows the reader, the guests follow the plan: the
    // bride's are «الضيفات», so her first one is «ضيفة».
    steps.push(
      setupAction(
        weddingPlanId,
        "ADD_GUESTS",
        say(planWord(planPersona, copy.addGuests.title)),
        planWord(planPersona, copy.addGuests.reason),
        say(planWord(planPersona, copy.addGuests.action)),
        // RA-MO-63: «أضف أول ضيف» opens the adding, not the empty list.
        `/wedding-plans/${weddingPlanId}/guests/add`,
      ),
    );
  }
  if (
    facts.canManageProviders &&
    facts.quoteRequestsCount === 0 &&
    facts.acceptedProviders === 0
  ) {
    steps.push(
      setupAction(
        weddingPlanId,
        "REQUEST_QUOTE",
        say(copy.requestQuote.title),
        copy.requestQuote.reason,
        say(copy.requestQuote.action),
        `/wedding-plans/${weddingPlanId}/providers`,
      ),
    );
  }
  // RA-MO-147: «مزود في خطتك · عرض الملف» closed this list once the chain
  // was done, and the home drew it as «الخطوة التالية». It is no step; the
  // plan's providers have their own list (`planProviders`).
  return steps;
}

function upcomingTaskStep(
  weddingPlanId: string,
  task: DashboardTaskRecord & { dueDate: Date },
  days: number,
  say: Say,
): DashboardNextStepResponse {
  const taskRoute = `/wedding-plans/${weddingPlanId}/tasks/${task.id}`;
  return {
    id: task.id,
    type: "TASK_UPCOMING",
    title: task.title,
    subtitle: NEXT_STEP_COPY.task.due(whenWords(days)),
    body: weekdayDayMonthWords(task.dueDate),
    icon: "calendar",
    tone: toneForTaskPriority(task.priority),
    priority: "NORMAL",
    actionLabel: say(NEXT_STEP_COPY.task.open),
    dueDate: task.dueDate,
    amount: null,
    route: taskRoute,
    routeTarget: taskRoute,
    entityId: task.id,
    data: { weddingPlanId, taskId: task.id },
  };
}

function missingEssentialStep(
  weddingPlanId: string,
  itemId: string,
  // The item's own name (review 2026-11-18): a fixed word named «البدلة
  // والكسوة» an item called «فستان» in a helper's plan.
  itemName: string,
  key: PlanEssentialKey,
  say: Say,
): DashboardNextStepResponse {
  const copy = NEXT_STEP_COPY.missingEssential;
  const itemRoute = `/wedding-plans/${weddingPlanId}/providers/requests?item=${encodeURIComponent(itemId)}`;
  return {
    id: `essential:${key}:${weddingPlanId}`,
    type: "ESSENTIAL_MISSING",
    title: say(copy.title(itemName)),
    subtitle: say(copy.reason),
    body: null,
    icon: "provider",
    tone: "info",
    priority: "NORMAL",
    actionLabel: say(copy.action),
    dueDate: null,
    amount: null,
    route: itemRoute,
    routeTarget: itemRoute,
    // The money item it reads; the home's suggestions keep it, with its
    // «⋯», the place to answer it (review 2026-11-18).
    entityId: itemId,
    data: { weddingPlanId, budgetCategoryId: itemId },
  };
}

function undatedDebtStep(
  weddingPlanId: string,
  amount: string,
  canManageMoney: boolean,
  form: AddressForm,
): DashboardNextStepResponse {
  const copy = NEXT_STEP_COPY.debtUndated;
  const moneyRoute = `/wedding-plans/${weddingPlanId}/money`;
  return {
    id: `debt-undated:${weddingPlanId}`,
    type: "DEBT_UNDATED",
    title: copy.title,
    subtitle: canManageMoney
      ? textFor(form, copy.reasonToPlan)
      : copy.reasonToRead,
    body: null,
    icon: "wallet",
    tone: "warning",
    priority: "NORMAL",
    actionLabel: textFor(form, canManageMoney ? copy.plan : copy.read),
    dueDate: null,
    amount,
    route: moneyRoute,
    routeTarget: moneyRoute,
    entityId: null,
    data: { weddingPlanId },
  };
}

function loanStep(
  weddingPlanId: string,
  loan: OutstandingLoanFact,
  today: Date,
  form: AddressForm,
): DashboardNextStepResponse {
  const copy = NEXT_STEP_COPY.loanOutstanding;
  const fundingRoute = loan.fundingSourceId
    ? `/wedding-plans/${weddingPlanId}/money/funding?source=${encodeURIComponent(loan.fundingSourceId)}`
    : `/wedding-plans/${weddingPlanId}/money/funding`;
  const days = loan.nextDueDate ? daysBetween(today, loan.nextDueDate) : null;
  const late = days !== null && days < 0;
  return {
    id: `loan-outstanding:${weddingPlanId}`,
    type: "LOAN_OUTSTANDING",
    title: copy.title,
    subtitle:
      days === null
        ? textFor(form, copy.noPlan)
        : late
          ? copy.lateRepayment(dayCountWords(-days))
          : copy.nextRepayment(whenWords(days)),
    body: loan.nextDueDate ? weekdayDayMonthWords(loan.nextDueDate) : null,
    icon: "wallet",
    tone: late ? "danger" : "info",
    priority: late ? "URGENT" : "NORMAL",
    actionLabel: textFor(form, copy.action),
    dueDate: loan.nextDueDate,
    amount: loan.outstanding,
    route: fundingRoute,
    routeTarget: fundingRoute,
    entityId: loan.fundingSourceId,
    data: { weddingPlanId, fundingSourceId: loan.fundingSourceId },
  };
}

function rateProvidersStep(
  weddingPlanId: string,
  form: AddressForm,
): DashboardNextStepResponse {
  const copy = NEXT_STEP_COPY.rateProviders;
  const reviewsRoute = `/wedding-plans/${weddingPlanId}/providers/reviews`;
  return {
    id: `rate-providers:${weddingPlanId}`,
    type: "RATE_PROVIDERS",
    title: textFor(form, copy.title),
    subtitle: copy.reason,
    body: null,
    icon: "provider",
    tone: "info",
    priority: "LOW",
    actionLabel: textFor(form, copy.action),
    dueDate: null,
    amount: null,
    route: reviewsRoute,
    routeTarget: reviewsRoute,
    entityId: null,
    data: { weddingPlanId },
  };
}

/** An essential's name as the home's suggestions say it. */
function essentialName(
  key: PlanEssentialKey,
  planPersona: string | null,
): string {
  return planWord<string>(planPersona, NEXT_STEP_COPY.essentialNames[key]);
}

function setupAction(
  weddingPlanId: string,
  type: Extract<
    DashboardNextStepType,
    | "SET_DATE"
    | "SET_LOCATION"
    | "SET_BUDGET"
    | "RECORD_MAHR"
    | "ADD_FIRST_COST"
    | "ADD_GUESTS"
    | "REQUEST_QUOTE"
  >,
  title: string,
  reason: string,
  actionLabel: string,
  routeTarget: string,
): DashboardNextStepResponse {
  const moneyStep =
    type === "SET_BUDGET" ||
    type === "RECORD_MAHR" ||
    type === "ADD_FIRST_COST";
  return {
    id: `${type.toLowerCase()}:${weddingPlanId}`,
    type,
    title,
    subtitle: reason,
    body: null,
    icon: moneyStep ? "wallet" : "calendar",
    tone: "info",
    priority: "LOW",
    actionLabel,
    dueDate: null,
    amount: null,
    route: routeTarget,
    routeTarget,
    entityId: weddingPlanId,
    data: { weddingPlanId },
  };
}

function toneForTaskPriority(
  priority: WeddingTaskPriority,
): DashboardImportantItemResponse["tone"] {
  if (priority === WeddingTaskPriority.URGENT) return "danger";
  if (priority === WeddingTaskPriority.HIGH) return "warning";
  return "info";
}
