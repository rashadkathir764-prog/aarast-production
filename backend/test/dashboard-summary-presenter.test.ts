import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { test } from "node:test";
import {
  InstallmentStatus,
  NotificationPriority,
  NotificationType,
  PlanProviderLinkStatus,
  Prisma,
  WeddingTaskPriority,
} from "@prisma/client";
import * as dashboardPresenter from "../src/dashboard/dashboard-summary.presenter";

type ServiceDashboardResponse =
  import("../src/dashboard/dashboard.service").WeddingPlanDashboardSummaryResponse;
type ContractDashboardResponse =
  import("../src/dashboard/dashboard.contracts").WeddingPlanDashboardSummaryResponse;
type PreservesDashboardResponseExport =
  ServiceDashboardResponse extends ContractDashboardResponse
    ? ContractDashboardResponse extends ServiceDashboardResponse
      ? true
      : false
    : false;

const preservesDashboardResponseExport: PreservesDashboardResponseExport = true;

function currentPresenter() {
  return dashboardPresenter;
}

test("dashboard extraction keeps service wiring, import compatibility and size boundary", () => {
  const sourceRoot = resolve(__dirname, "../src/dashboard");
  const serviceSource = readFileSync(
    resolve(sourceRoot, "dashboard.service.ts"),
    "utf8",
  );
  const presenterSource = readFileSync(
    resolve(sourceRoot, "dashboard-summary.presenter.ts"),
    "utf8",
  );
  const moduleSource = readFileSync(
    resolve(sourceRoot, "dashboard.module.ts"),
    "utf8",
  );
  const controllerSource = readFileSync(
    resolve(sourceRoot, "dashboard.controller.ts"),
    "utf8",
  );

  assert.equal(preservesDashboardResponseExport, true);
  assert.ok(
    serviceSource.split(/\r?\n/).length <= 800,
    "DashboardService must stay below the agreed 800-line boundary",
  );
  assert.match(serviceSource, /private readonly prisma: PrismaService/);
  assert.match(serviceSource, /private readonly permissions: PermissionService/);
  assert.doesNotMatch(
    presenterSource,
    /@nestjs|PrismaService|PermissionService|this\.prisma/,
  );
  assert.match(moduleSource, /providers:\s*\[DashboardService\]/);
  assert.match(
    controllerSource,
    /constructor\(private readonly dashboardService: DashboardService\)/,
  );
});

test("dashboard important items preserve priority, copy and route contracts", () => {
  const presenter = currentPresenter();
  const today = new Date(2026, 6, 11);
  const overdueTaskDate = new Date(2026, 6, 9);
  const overdueInstallmentDate = new Date(2026, 6, 10);

  const items = presenter.buildImportantItems({
    weddingPlanId: "plan-1",
    tasks: [
      {
        id: "task-1",
        title: "تأكيد القاعة",
        dueDate: overdueTaskDate,
        priority: WeddingTaskPriority.HIGH,
      },
    ],
    installments: [
      {
        id: "installment-1",
        financialCommitmentId: "commitment-1",
        title: "دفعة القاعة",
        amount: new Prisma.Decimal("2500"),
        dueDate: overdueInstallmentDate,
        status: InstallmentStatus.OVERDUE,
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
  });

  assert.deepEqual(
    items.map((item: { type: string }) => item.type),
    ["TASK_OVERDUE", "INSTALLMENT_DUE", "QUOTE_RECEIVED"],
  );
  assert.equal(items[0].title, "مهمة متأخرة");
  assert.equal(items[0].actionLabel, "تنفيذ الآن");
  assert.equal(items[0].routeTarget, "/wedding-plans/plan-1/tasks");
  assert.equal(items[1].title, "قسط متأخر");
  assert.equal(
    items[1].routeTarget,
    "/wedding-plans/plan-1/finance/commitments/commitment-1",
  );
  assert.equal(items[1].amount, "2500");
  assert.equal(items[2].subtitle, "2 عرض بانتظار قرارك");
  assert.equal(
    items[2].body,
    "راجع العرض الحقيقي ثم اقبله أو ارفضه من مركز الخطة.",
  );
});

test("dashboard setup actions and provider preview keep product wording", () => {
  const presenter = currentPresenter();
  const setupItems = presenter.buildImportantItems({
    weddingPlanId: "plan-1",
    tasks: [],
    installments: [],
    providers: [],
    today: new Date(2026, 6, 11),
    receivedQuotes: 0,
    pendingInvites: 0,
    hasLocation: false,
    hasBudget: false,
    guestCount: 0,
    quoteRequestsCount: 0,
    acceptedProviders: 0,
  });

  assert.deepEqual(
    setupItems.map((item: { type: string }) => item.type),
    ["SET_LOCATION", "SET_BUDGET", "ADD_GUESTS"],
  );
  assert.equal(setupItems[0].title, "أكمل موقع الزفاف");
  assert.equal(
    setupItems[0].routeTarget,
    "/wedding-plans/plan-1/plan-center",
  );
  assert.equal(setupItems[1].title, "حدد ميزانية الخطة");
  assert.equal(setupItems[1].routeTarget, "/wedding-plans/plan-1/finance");
  assert.equal(setupItems[2].title, "ابدأ قائمة الضيوف");

  const providerItems = presenter.buildImportantItems({
    weddingPlanId: "plan-1",
    tasks: [],
    installments: [],
    providers: [providerLink()],
    today: new Date(2026, 6, 11),
    receivedQuotes: 0,
    pendingInvites: 0,
    hasLocation: true,
    hasBudget: true,
    guestCount: 1,
    quoteRequestsCount: 1,
    acceptedProviders: 1,
  });

  assert.equal(providerItems.length, 1);
  assert.equal(providerItems[0].type, "PLAN_PROVIDER");
  assert.equal(providerItems[0].title, "مزود قريب منك");
  assert.equal(providerItems[0].subtitle, "قاعة النور");
  assert.equal(providerItems[0].body, "قاعات · تقييم 4.75");
  assert.equal(providerItems[0].routeTarget, "/providers/provider-1");
});

test("dashboard financial warnings preserve severity, amounts and copy", () => {
  const presenter = currentPresenter();
  assert.deepEqual(
    presenter.buildFinancialWarnings({
      remainingBudget: null,
      dueInstallmentsCount: null,
    }),
    [],
  );

  assert.deepEqual(
    presenter.buildFinancialWarnings({
      remainingBudget: -125.5,
      dueInstallmentsCount: 2,
    }),
    [
      {
        type: "BUDGET_EXCEEDED",
        severity: "DANGER",
        message: "Spent total is above the available wedding budget.",
        count: null,
        amount: "125.50",
      },
      {
        type: "INSTALLMENT_DUE_SOON",
        severity: "WARNING",
        message: "There are installments due soon.",
        count: 2,
        amount: null,
      },
    ],
  );
});

test("dashboard next provider action keeps precedence", () => {
  const presenter = currentPresenter();
  assert.equal(
    presenter.nextProviderAction(2, 1, 1),
    "REVIEW_RECEIVED_QUOTES",
  );
  assert.equal(
    presenter.nextProviderAction(2, 0, 1),
    "WAIT_FOR_PROVIDER_RESPONSE",
  );
  assert.equal(
    presenter.nextProviderAction(0, 0, 1),
    "MANAGE_ACCEPTED_PROVIDERS",
  );
  assert.equal(
    presenter.nextProviderAction(0, 0, 0),
    "REQUEST_FIRST_QUOTE",
  );
});

test("dashboard previews preserve public response shape", () => {
  const presenter = currentPresenter();
  assert.deepEqual(presenter.toProviderPreviewResponse(providerLink()), {
    id: "link-1",
    providerId: "provider-1",
    businessName: "قاعة النور",
    categoryName: "قاعات",
    serviceTitle: "الباقة الذهبية",
    imageUrl: "https://cdn.example.test/cover.webp",
    ratingAverage: "4.75",
    ratingCount: 18,
    status: PlanProviderLinkStatus.ACTIVE,
  });

  const createdAt = new Date("2026-07-11T08:00:00.000Z");
  assert.deepEqual(
    presenter.toNotificationPreview({
      id: "notification-1",
      type: NotificationType.QUOTE_OFFER_RECEIVED,
      priority: NotificationPriority.HIGH,
      title: "وصل عرض سعر",
      body: "راجع العرض",
      readAt: null,
      createdAt,
      data: { quoteRequestId: "quote-1" },
      entityType: "quote_request",
      entityId: "quote-1",
      routeTarget: "/wedding-plans/plan-1/plan-center",
    }),
    {
      id: "notification-1",
      type: NotificationType.QUOTE_OFFER_RECEIVED,
      priority: NotificationPriority.HIGH,
      title: "وصل عرض سعر",
      body: "راجع العرض",
      readAt: null,
      createdAt,
      data: { quoteRequestId: "quote-1" },
      entityType: "quote_request",
      entityId: "quote-1",
      routeTarget: "/wedding-plans/plan-1/plan-center",
    },
  );
});

test("dashboard numeric, date and installment helpers keep exact behavior", () => {
  const presenter = currentPresenter();
  const commitment = {
    id: "commitment-1",
    title: "دفعة القاعة",
  };
  const installment = {
    id: "installment-1",
    financialCommitmentId: "commitment-1",
    amount: new Prisma.Decimal("1500.25"),
    dueDate: new Date(2026, 6, 12),
    status: InstallmentStatus.PENDING,
  };

  assert.equal(
    presenter.toFinancialDueMoneyItem(
      installment,
      new Map([[commitment.id, commitment]]),
    ).title,
    "دفعة القاعة",
  );
  assert.equal(
    presenter.toFinancialDueMoneyItem(installment, new Map()).title,
    "مستحق مالي",
  );
  assert.equal(presenter.isOpenInstallment(InstallmentStatus.PENDING), true);
  assert.equal(presenter.isOpenInstallment(InstallmentStatus.OVERDUE), true);
  assert.equal(presenter.isOpenInstallment(InstallmentStatus.PAID), false);
  assert.ok(
    presenter.compareNullableDates(new Date(2026, 6, 11), null) < 0,
  );
  assert.equal(presenter.moneyOrNull(null), null);
  assert.equal(presenter.moneyOrNull(15.5), "15.50");
  assert.equal(presenter.decimalToNumber(new Prisma.Decimal("9.75")), 9.75);
  assert.equal(presenter.decimalToNumber({ toString: () => "invalid" }), 0);
  assert.equal(
    presenter.resolveBudgetTotal(
      { estimatedBudget: new Prisma.Decimal("9000") },
      [{ targetAmount: new Prisma.Decimal("100") }],
    ),
    9000,
  );
  assert.equal(
    presenter.resolveBudgetTotal(
      { estimatedBudget: null },
      [
        { targetAmount: new Prisma.Decimal("100") },
        { targetAmount: new Prisma.Decimal("250.5") },
      ],
    ),
    350.5,
  );
  const today = new Date(2026, 6, 11);
  assert.equal(presenter.daysRemaining(new Date(2026, 6, 13), today), 2);
  assert.equal(presenter.daysRemaining(null, today), null);
  assert.equal(presenter.progressPercentage(3, 1), 33);
  assert.equal(presenter.progressPercentage(0, 0), 0);

  const expectedArabicDate = new Intl.DateTimeFormat("ar-YE", {
    day: "numeric",
    month: "long",
  }).format(today);
  assert.equal(presenter.formatDateArabic(today), expectedArabicDate);
});

function providerLink() {
  return {
    id: "link-1",
    providerId: "provider-1",
    status: PlanProviderLinkStatus.ACTIVE,
    provider: {
      id: "provider-1",
      businessName: "قاعة النور",
      coverUrl: "https://cdn.example.test/cover.webp",
      logoUrl: "https://cdn.example.test/logo.webp",
      ratingAverage: new Prisma.Decimal("4.75"),
      ratingCount: 18,
      primaryCategory: { nameAr: "قاعات" },
      services: [
        {
          title: "الباقة الذهبية",
          images: [{ imageUrl: "https://cdn.example.test/service.webp" }],
        },
      ],
    },
  };
}
