import 'reflect-metadata';

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
  // compose are held by the insights-private InsightsReadPorts provider.
  assert.match(
    moduleSource,
    /providers:\s*\[InsightsReadPorts,\s*DashboardService,\s*TimelineService\]/,
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
    currency: 'YER',
  });

  assert.deepEqual(
    items.map((item) => item.type),
    ['TASK_OVERDUE', 'PAYMENT_SCHEDULE_DUE', 'QUOTE_RECEIVED'],
  );
  assert.equal(items[0].title, 'مهمة متأخرة');
  assert.equal(items[0].routeTarget, '/wedding-plans/plan-1/tasks');
  assert.equal(items[1].title, 'موعد دفع متأخر');
  assert.equal(items[1].subtitle, 'دفعة القاعة');
  assert.equal(items[1].amount, '2500');
  assert.equal(
    items[1].routeTarget,
    '/wedding-plans/plan-1/money/costs/cost-1/schedules/schedule-1',
  );
  assert.deepEqual(items[1].data, {
    weddingPlanId: 'plan-1',
    weddingCostId: 'cost-1',
    paymentScheduleId: 'schedule-1',
  });
  assert.equal(items[2].subtitle, '2 عرض بانتظار قرارك');
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
    currency: 'YER',
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
    currency: 'YER',
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
    currency: 'YER',
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
        message: 'التكاليف المؤكدة تجاوزت الميزانية العامة.',
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

  const expectedArabicDate = new Intl.DateTimeFormat('ar-YE', {
    day: 'numeric',
    month: 'long',
  }).format(later);
  assert.equal(dashboardPresenter.formatDateArabic(later), expectedArabicDate);
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
