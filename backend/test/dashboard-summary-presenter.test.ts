import 'reflect-metadata';

import { startOfRiyadhDay } from '../src/shared-kernel/time/business-day';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { test } from 'node:test';
import {
  NotificationPriority,
  NotificationType,
  PaymentScheduleStatus,
  PlanProviderLinkStatus,
  Prisma,
  WeddingTaskPriority,
} from '@prisma/client';
import * as dashboardPresenter from '../src/dashboard/dashboard-summary.presenter';

type ServiceDashboardResponse =
  import('../src/dashboard/dashboard.service').WeddingPlanDashboardSummaryResponse;
type ContractDashboardResponse =
  import('../src/dashboard/dashboard.contracts').WeddingPlanDashboardSummaryResponse;
type PreservesDashboardResponseExport =
  ServiceDashboardResponse extends ContractDashboardResponse
    ? ContractDashboardResponse extends ServiceDashboardResponse
      ? true
      : false
    : false;

const preservesDashboardResponseExport: PreservesDashboardResponseExport = true;

test('dashboard extraction keeps service wiring, import compatibility and size boundary', () => {
  const sourceRoot = resolve(__dirname, '../src/dashboard');
  const serviceSource = readFileSync(
    resolve(sourceRoot, 'dashboard.service.ts'),
    'utf8',
  );
  const presenterSource = readFileSync(
    resolve(sourceRoot, 'dashboard-summary.presenter.ts'),
    'utf8',
  );
  const moduleSource = readFileSync(
    resolve(__dirname, '../src/modules/insights/internal/insights-services.internal.module.ts'),
    'utf8',
  );
  const controllerSource = readFileSync(
    resolve(sourceRoot, 'dashboard.controller.ts'),
    'utf8',
  );

  assert.equal(preservesDashboardResponseExport, true);
  assert.ok(
    serviceSource.split(/\r?\n/).length <= 800,
    'DashboardService must stay below the agreed 800-line boundary',
  );
  assert.match(serviceSource, /private readonly prisma: PrismaService/);
  assert.match(serviceSource, /private readonly permissions: PermissionService/);
  assert.doesNotMatch(
    presenterSource,
    /@nestjs|PrismaService|PermissionService|this\.prisma/,
  );
  // Insights owns no tables: the owners' ports the dashboard and timeline
  // compose are held by the insights-private InsightsReadPorts provider,
  // which the planning assistant (V1 checklist 4.12) composes as well.
  assert.match(
    moduleSource,
    /providers:\s*\[\s*InsightsReadPorts,\s*DashboardService,\s*TimelineService,\s*AssistantRuntime,\s*AssistantService,?\s*\]/,
  );
  assert.match(serviceSource, /private readonly owners: InsightsReadPorts/);
  assert.doesNotMatch(serviceSource, /tx\.[a-zA-Z]+\.(count|findMany|findFirst)\(/);
  assert.match(
    controllerSource,
    /constructor\(private readonly dashboardService: DashboardService\)/,
  );
});

test('dashboard maps a payment schedule to the canonical due-money contract', () => {
  const dueDate = new Date('2026-07-12T00:00:00.000Z');
  const item = dashboardPresenter.toPaymentScheduleDueMoneyItem({
    id: 'schedule-1',
    weddingCostId: 'cost-1',
    amount: new Prisma.Decimal('1500.25'),
    dueDate,
    status: PaymentScheduleStatus.PENDING,
    weddingCost: { title: 'تكلفة القاعة' },
  });

  assert.deepEqual(item, {
    id: 'schedule-1',
    weddingCostId: 'cost-1',
    title: 'تكلفة القاعة',
    amount: new Prisma.Decimal('1500.25'),
    dueDate,
    status: PaymentScheduleStatus.PENDING,
  });
});

test('dashboard important items use WeddingCost routes and preserve priority', () => {
  const today = new Date(2026, 6, 11);
  const items = dashboardPresenter.buildImportantItems({
    weddingPlanId: 'plan-1',
    tasks: [
      {
        id: 'task-1',
        title: 'تأكيد القاعة',
        dueDate: new Date(2026, 6, 9),
        priority: WeddingTaskPriority.HIGH,
      },
    ],
    paymentSchedules: [
      {
        id: 'schedule-1',
        weddingCostId: 'cost-1',
        title: 'دفعة القاعة',
        amount: new Prisma.Decimal('2500'),
        dueDate: new Date(2026, 6, 10),
        status: PaymentScheduleStatus.PENDING,
      },
    ],
    providers: [],
    today,
    receivedQuotes: 2,
    pendingInvites: 1,
    hasLocation: true,
    hasBudget: true,
    guestCount: 10,
    quoteRequestsCount: 1,
    acceptedProviders: 0,
    canManageMoney: true,
    form: 'MASCULINE',
    planPersona: 'GROOM',
  });

  assert.deepEqual(
    items.map((item) => item.type),
    ['TASK_OVERDUE', 'PAYMENT_SCHEDULE_DUE', 'QUOTE_RECEIVED'],
  );
  // A next step names the thing, says why, and offers its own action.
  assert.equal(items[0].title, 'تأكيد القاعة');
  assert.equal(items[0].subtitle, 'متأخرة يومين');
  assert.equal(items[0].actionLabel, 'افتح المهمة');
  assert.equal(items[0].routeTarget, '/wedding-plans/plan-1/tasks/task-1');
  assert.equal(items[1].title, 'دفعة القاعة');
  assert.equal(items[1].subtitle, 'فات موعدها من يوم واحد');
  assert.equal(items[1].actionLabel, 'سجّل الدفعة');
  assert.equal(items[1].amount, '2500');
  // The amount is data, so «أخفِ المبالغ» can hide it.
  assert.ok(!`${items[1].title}${items[1].subtitle}${items[1].body}`.includes('2500'));
  assert.equal(
    items[1].routeTarget,
    '/wedding-plans/plan-1/money/costs/cost-1/schedules/schedule-1/pay',
  );
  assert.deepEqual(items[1].data, {
    weddingPlanId: 'plan-1',
    weddingCostId: 'cost-1',
    paymentScheduleId: 'schedule-1',
  });
  assert.equal(items[2].title, 'وصلك عرضين');
  assert.equal(items[2].actionLabel, 'قارن العروض');
  assert.equal(items[2].routeTarget, '/wedding-plans/plan-1/providers');
});

test('dashboard next step: a reader who cannot record money only reads the payment', () => {
  const [item] = dashboardPresenter.buildImportantItems({
    weddingPlanId: 'plan-1',
    tasks: [],
    paymentSchedules: [
      {
        id: 'schedule-1',
        weddingCostId: 'cost-1',
        title: 'دفعة القاعة',
        amount: new Prisma.Decimal('2500'),
        dueDate: new Date(2026, 6, 16),
        status: PaymentScheduleStatus.PENDING,
      },
    ],
    providers: [],
    today: new Date(2026, 6, 11),
    receivedQuotes: 0,
    pendingInvites: 0,
    hasLocation: true,
    hasBudget: true,
    guestCount: 10,
    quoteRequestsCount: 1,
    acceptedProviders: 0,
    canManageMoney: false,
    form: 'FEMININE',
    planPersona: 'BRIDE',
  });

  assert.equal(item.subtitle, 'موعدها بعد 5 أيام');
  assert.equal(item.actionLabel, 'شوفي الدفعة');
  assert.equal(
    item.routeTarget,
    '/wedding-plans/plan-1/money/costs/cost-1/schedules/schedule-1',
  );
});

test('dashboard setup actions and provider preview keep current product wording', () => {
  const setupItems = dashboardPresenter.buildImportantItems({
    weddingPlanId: 'plan-1',
    tasks: [],
    paymentSchedules: [],
    providers: [],
    today: new Date(2026, 6, 11),
    receivedQuotes: 0,
    pendingInvites: 0,
    hasLocation: false,
    hasBudget: false,
    guestCount: 0,
    quoteRequestsCount: 0,
    acceptedProviders: 0,
    canManageMoney: true,
    form: 'MASCULINE',
    planPersona: 'GROOM',
  });

  assert.deepEqual(
    setupItems.map((item) => item.type),
    ['SET_LOCATION', 'SET_BUDGET', 'ADD_GUESTS'],
  );
  assert.equal(setupItems[0].routeTarget, '/wedding-plans/plan-1/plan-center');
  assert.equal(setupItems[1].routeTarget, '/wedding-plans/plan-1/money/budget');
  assert.equal(setupItems[2].routeTarget, '/wedding-plans/plan-1/guests');

  const providerItems = dashboardPresenter.buildImportantItems({
    weddingPlanId: 'plan-1',
    tasks: [],
    paymentSchedules: [],
    providers: [providerLink()],
    today: new Date(2026, 6, 11),
    receivedQuotes: 0,
    pendingInvites: 0,
    hasLocation: true,
    hasBudget: true,
    guestCount: 1,
    quoteRequestsCount: 1,
    acceptedProviders: 1,
    canManageMoney: true,
    form: 'MASCULINE',
    planPersona: 'GROOM',
  });

  assert.equal(providerItems.length, 1);
  assert.equal(providerItems[0].type, 'PLAN_PROVIDER');
  assert.equal(providerItems[0].subtitle, 'قاعة النور');
  assert.equal(providerItems[0].body, 'قاعات · تقييم 4.75');
  assert.equal(providerItems[0].routeTarget, '/providers/provider-1');
});

test('dashboard provider card describes a plan link without claiming proximity', () => {
  const items = dashboardPresenter.buildImportantItems({
    weddingPlanId: 'plan-1',
    tasks: [],
    paymentSchedules: [],
    providers: [providerLink()],
    today: new Date(2026, 6, 11),
    receivedQuotes: 0,
    pendingInvites: 0,
    hasLocation: true,
    hasBudget: true,
    guestCount: 1,
    quoteRequestsCount: 1,
    acceptedProviders: 1,
    canManageMoney: true,
    form: 'MASCULINE',
    planPersona: 'GROOM',
  });

  assert.equal(items[0].title, 'مزود في خطتك');
});

test('dashboard money warnings distinguish budget, overdue and due-soon states', () => {
  assert.deepEqual(
    dashboardPresenter.buildFinancialWarnings({
      remainingBudget: null,
      overdueCount: null,
      dueSoonCount: null,
    }),
    [],
  );

  assert.deepEqual(
    dashboardPresenter.buildFinancialWarnings({
      remainingBudget: -125.5,
      overdueCount: 1,
      dueSoonCount: 2,
    }),
    [
      {
        type: 'BUDGET_EXCEEDED',
        severity: 'DANGER',
        // D105: by the expected cost, and in the app's words.
        message: 'تكلفة العرس المتوقعة فاتت الميزانية.',
        count: null,
        amount: '125.50',
      },
      {
        type: 'PAYMENT_SCHEDULE_OVERDUE',
        severity: 'DANGER',
        message: 'لديك مواعيد دفع متأخرة تحتاج متابعة.',
        count: 1,
        amount: null,
      },
      {
        type: 'PAYMENT_SCHEDULE_DUE_SOON',
        severity: 'WARNING',
        message: 'لديك مواعيد دفع خلال الأيام السبعة القادمة.',
        count: 2,
        amount: null,
      },
    ],
  );
});

test('dashboard provider and notification helpers preserve public contracts', () => {
  assert.equal(
    dashboardPresenter.nextProviderAction(2, 1, 1),
    'REVIEW_RECEIVED_QUOTES',
  );
  assert.equal(
    dashboardPresenter.nextProviderAction(2, 0, 1),
    'WAIT_FOR_PROVIDER_RESPONSE',
  );
  assert.equal(
    dashboardPresenter.nextProviderAction(0, 0, 1),
    'MANAGE_ACCEPTED_PROVIDERS',
  );
  assert.equal(
    dashboardPresenter.nextProviderAction(0, 0, 0),
    'REQUEST_FIRST_QUOTE',
  );

  assert.deepEqual(dashboardPresenter.toProviderPreviewResponse(providerLink()), {
    id: 'link-1',
    providerId: 'provider-1',
    businessName: 'قاعة النور',
    categoryName: 'قاعات',
    serviceTitle: 'الباقة الذهبية',
    imageUrl: 'https://cdn.example.test/cover.webp',
    ratingAverage: '4.75',
    ratingCount: 18,
    status: PlanProviderLinkStatus.ACTIVE,
  });

  const createdAt = new Date('2026-07-11T08:00:00.000Z');
  assert.deepEqual(
    dashboardPresenter.toNotificationPreview({
      id: 'notification-1',
      type: NotificationType.QUOTE_OFFER_RECEIVED,
      priority: NotificationPriority.HIGH,
      title: 'وصل عرض سعر',
      body: 'راجع العرض',
      readAt: null,
      createdAt,
      data: { quoteRequestId: 'quote-1' },
      entityType: 'quote_request',
      entityId: 'quote-1',
      routeTarget: '/wedding-plans/plan-1/plan-center',
    }),
    {
      id: 'notification-1',
      type: NotificationType.QUOTE_OFFER_RECEIVED,
      priority: NotificationPriority.HIGH,
      title: 'وصل عرض سعر',
      body: 'راجع العرض',
      readAt: null,
      createdAt,
      data: { quoteRequestId: 'quote-1' },
      entityType: 'quote_request',
      entityId: 'quote-1',
      routeTarget: '/wedding-plans/plan-1/plan-center',
    },
  );
});

test('dashboard numeric and date helpers keep exact behavior', () => {
  const earlier = new Date(2026, 6, 10);
  const later = new Date(2026, 6, 11);
  assert.ok(dashboardPresenter.compareDates(earlier, later) < 0);
  assert.equal(dashboardPresenter.moneyOrNull(null), null);
  assert.equal(dashboardPresenter.moneyOrNull(15.5), '15.50');
  // decimalToNumber / resolveBudgetTotal (float money) were replaced by the
  // exact sumMoney / resolveBudgetDecimal helpers; see the decimal-sum test.
  assert.equal(
    dashboardPresenter.resolveBudgetDecimal({
      estimatedBudget: new Prisma.Decimal('9000'),
    })?.toString(),
    '9000',
  );
  assert.equal(
    dashboardPresenter.resolveBudgetDecimal({ estimatedBudget: null }),
    null,
  );
  assert.equal(dashboardPresenter.daysRemaining(new Date(2026, 6, 13), later), 2);
  assert.equal(dashboardPresenter.daysRemaining(null, later), null);
  assert.equal(dashboardPresenter.progressPercentage(3, 1), 33);
  assert.equal(dashboardPresenter.progressPercentage(0, 0), 0);
});

test('RA-BE-44: a provider card never falls back to a service photo nobody reviewed', () => {
  // D62: a service's own photos are not reviewed, so they are not shown;
  // RA-BE-12 stopped them in every public read but this card's fallback.
  const link = providerLink() as any;
  link.provider.coverUrl = null;
  link.provider.logoUrl = null;
  assert.equal(dashboardPresenter.toProviderPreviewResponse(link).imageUrl, null);
});

function providerLink() {
  return {
    id: 'link-1',
    providerId: 'provider-1',
    status: PlanProviderLinkStatus.ACTIVE,
    provider: {
      id: 'provider-1',
      businessName: 'قاعة النور',
      coverUrl: 'https://cdn.example.test/cover.webp',
      logoUrl: 'https://cdn.example.test/logo.webp',
      ratingAverage: new Prisma.Decimal('4.75'),
      ratingCount: 18,
      primaryCategory: { nameAr: 'قاعات' },
      services: [
        {
          title: 'الباقة الذهبية',
          images: [{ imageUrl: 'https://cdn.example.test/service.webp' }],
        },
      ],
    },
  };
}

test('dashboard money totals are exact decimal sums, never float accumulations', () => {
  // Finance sums Prisma.Decimal exactly; the dashboard must agree to the cent
  // at every magnitude numeric(14,2) allows. 132 costs of the pattern below
  // sum to 5,250,000,000,006.51 exactly; a float accumulation prints .50.
  const values = Array.from({ length: 132 }, (_, index) => new Prisma.Decimal(`${(index % 7) + 1}0000000000.0${(index % 9) + 1}`));
  const floatSum = values.reduce((sum, value) => sum + Number(value.toString()), 0).toFixed(2);
  assert.equal(floatSum, '5250000000006.50', 'the float accumulation loses a cent at this magnitude');
  const exact = dashboardPresenter.sumMoney(values);
  assert.ok(exact instanceof Prisma.Decimal);
  assert.equal(dashboardPresenter.moneyOrNull(exact), '5250000000006.51');
  assert.equal(dashboardPresenter.sumMoney([]).toFixed(2), '0.00');
  assert.equal(dashboardPresenter.sumMoney([new Prisma.Decimal('0.1'), new Prisma.Decimal('0.2')]).toFixed(2), '0.30');
  assert.equal(dashboardPresenter.moneyOrNull(new Prisma.Decimal('15.5')), '15.50');
  assert.equal(dashboardPresenter.resolveBudgetDecimal({ estimatedBudget: new Prisma.Decimal('9000') })?.toFixed(2), '9000.00');
  assert.equal(dashboardPresenter.resolveBudgetDecimal({ estimatedBudget: null }), null);
  // Warnings compare exactly as well.
  const [warning] = dashboardPresenter.buildFinancialWarnings({
    remainingBudget: new Prisma.Decimal('-0.01'),
    overdueCount: null,
    dueSoonCount: null,
  });
  assert.equal(warning.type, 'BUDGET_EXCEEDED');
  assert.equal(warning.amount, '0.01');
});

// J1-04: the home's next step is the first server item, so the setup steps
// come in one order, each only while it is missing: the budget, the mahr,
// the first agreement, the guests, then the first quote.
function setupItems(
  overrides: Partial<Parameters<typeof dashboardPresenter.buildImportantItems>[0]>,
) {
  return dashboardPresenter.buildImportantItems({
    weddingPlanId: 'plan-1',
    tasks: [],
    paymentSchedules: [],
    providers: [],
    today: new Date(2026, 6, 11),
    receivedQuotes: 0,
    pendingInvites: 0,
    hasLocation: true,
    hasBudget: true,
    guestCount: 0,
    quoteRequestsCount: 0,
    acceptedProviders: 0,
    canManageMoney: true,
    form: 'MASCULINE',
    planPersona: 'GROOM',
    mahrRecorded: false,
    weddingCostsCount: 0,
    ...overrides,
  });
}

test('dashboard next step: a new plan without its mahr asks for the mahr first', () => {
  const groom = setupItems({});
  assert.deepEqual(
    groom.map((item) => item.type),
    ['RECORD_MAHR', 'ADD_FIRST_COST', 'ADD_GUESTS'],
  );
  assert.equal(groom[0].title, 'اتفقتوا على المهر؟');
  assert.equal(groom[0].subtitle, 'نحسبه لحاله، برا ميزانية العرس.');
  assert.equal(groom[0].actionLabel, 'سجّل المهر');
  assert.equal(groom[0].routeTarget, '/wedding-plans/plan-1/money/mahr');
  assert.equal(groom[0].route, '/wedding-plans/plan-1/money/mahr');
  assert.equal(groom[0].icon, 'wallet');
  assert.equal(groom[0].priority, 'LOW');
  assert.equal(groom[0].id, 'record_mahr:plan-1');

  const [bride] = setupItems({ form: 'FEMININE', planPersona: 'BRIDE' });
  assert.equal(bride.type, 'RECORD_MAHR');
  assert.equal(bride.title, 'اتفقتوا على المهر؟');
  assert.equal(bride.actionLabel, 'سجّلي المهر');

  // The budget, while it is missing, still comes before the mahr.
  assert.deepEqual(
    setupItems({ hasBudget: false }).map((item) => item.type),
    ['SET_BUDGET', 'RECORD_MAHR', 'ADD_FIRST_COST'],
  );
});

test('dashboard next step: with the mahr recorded and no agreement, the first agreement comes first', () => {
  const groom = setupItems({ mahrRecorded: true });
  assert.deepEqual(
    groom.map((item) => item.type),
    ['ADD_FIRST_COST', 'ADD_GUESTS', 'REQUEST_QUOTE'],
  );
  assert.equal(groom[0].title, 'سجّل أول اتفاق');
  assert.equal(
    groom[0].subtitle,
    'القاعة أو الذهب أو الكسوة: أول رقم يخلي الباقي يبان',
  );
  assert.equal(groom[0].actionLabel, 'أضف اتفاق');
  assert.equal(
    groom[0].routeTarget,
    '/wedding-plans/plan-1/money/costs/create',
  );
  assert.equal(groom[0].icon, 'wallet');
  assert.equal(groom[0].priority, 'LOW');

  const [bride] = setupItems({
    mahrRecorded: true,
    form: 'FEMININE',
    planPersona: 'BRIDE',
  });
  assert.equal(bride.type, 'ADD_FIRST_COST');
  assert.equal(bride.title, 'سجّلي أول اتفاق');
  assert.equal(bride.actionLabel, 'أضيفي اتفاق');
});

test('dashboard next step: with agreements and no guests, the guests come first', () => {
  const groom = setupItems({ mahrRecorded: true, weddingCostsCount: 2 });
  assert.deepEqual(
    groom.map((item) => item.type),
    ['ADD_GUESTS', 'REQUEST_QUOTE'],
  );
  assert.equal(groom[0].actionLabel, 'أضف أول ضيف');

  // The bride's guests are «الضيفات»: her first one is «ضيفة».
  const [bride] = setupItems({
    mahrRecorded: true,
    weddingCostsCount: 2,
    form: 'FEMININE',
    planPersona: 'BRIDE',
  });
  assert.equal(bride.type, 'ADD_GUESTS');
  assert.equal(bride.title, 'ابدئي قائمة الضيفات');
  assert.equal(bride.actionLabel, 'أضيفي أول ضيفة');
  // D55: the groom reading the bride's plan is addressed as himself.
  const [groomInBridePlan] = setupItems({
    mahrRecorded: true,
    weddingCostsCount: 2,
    form: 'MASCULINE',
    planPersona: 'BRIDE',
  });
  assert.equal(groomInBridePlan.actionLabel, 'أضف أول ضيفة');
});

test('dashboard next step: a reader who cannot manage money gets neither money step', () => {
  const items = setupItems({ canManageMoney: false, form: 'FEMININE' });
  assert.deepEqual(
    items.map((item) => item.type),
    ['ADD_GUESTS', 'REQUEST_QUOTE'],
  );
});

test('dashboard next step: an unknown or inapplicable money fact asks for nothing', () => {
  // null: the reader may not see it (a contributor), or the plan has no
  // mahr side (a helper's plan); neither invents a step.
  assert.deepEqual(
    setupItems({ mahrRecorded: null, weddingCostsCount: null }).map(
      (item) => item.type,
    ),
    ['ADD_GUESTS', 'REQUEST_QUOTE'],
  );
  assert.deepEqual(
    setupItems({ planPersona: null, weddingCostsCount: 1 }).map(
      (item) => item.type,
    ),
    ['ADD_GUESTS', 'REQUEST_QUOTE'],
  );
});

// The wedding as a day in Sana'a (D11), as the countdown notice and the
// assistant count it. The app sends «2026-11-20T00:00:00.000» and a server
// in UTC keeps 2026-11-20T00:00Z; on 7 November in Sana'a the home said 14
// where the notice said 13, 1 on the wedding day and 0 the day after.
test('days to the wedding are Sana\'a days, the same as the countdown notice', () => {
  const today = startOfRiyadhDay(new Date('2026-11-07T09:00:00.000Z'));
  assert.equal(dashboardPresenter.daysRemaining(new Date('2026-11-20T00:00:00.000Z'), today), 13);
  assert.equal(dashboardPresenter.daysRemaining(new Date('2026-11-07T00:00:00.000Z'), today), 0);
  assert.equal(dashboardPresenter.daysRemaining(new Date('2026-11-06T00:00:00.000Z'), today), -1);
  // Late at night in Sana'a (still 7 November in UTC) is already the 8th.
  const lateNight = startOfRiyadhDay(new Date('2026-11-07T21:30:00.000Z'));
  assert.equal(dashboardPresenter.daysRemaining(new Date('2026-11-20T00:00:00.000Z'), lateNight), 12);
});
