import {
  NotificationPriority,
  NotificationType,
  PaymentScheduleStatus,
  PlanProviderLinkStatus,
  Prisma,
  SharedMemberRole,
  WeddingPlanStatus,
  WeddingTaskStatus,
} from "@prisma/client";
import { WeddingLocationResponse } from "../wedding-plans/wedding-location";

export interface DashboardPermissionSummary {
  isOwner: boolean;
  role: "OWNER" | SharedMemberRole | null;
  canViewMoney: boolean;
  canManageMoney: boolean;
  canManageTasks: boolean;
  canManageGuests: boolean;
  canManageProviders: boolean;
  canManageMembers: boolean;
  canManagePlan: boolean;
}

export interface WeddingPlanDashboardSummaryResponse {
  dataScope: "ACCOUNT_BACKED";
  accountBacked: true;
  planId: string;
  title: string;
  currency: string;
  weddingDate: Date | null;
  city: string | null;
  location: WeddingLocationResponse | null;
  status: WeddingPlanStatus;
  daysRemaining: number | null;
  progressPercentage: number;
  budgetTotal: string | null;
  confirmedCostTotal: string | null;
  paidTotal: string | null;
  outstandingTotal: string | null;
  remainingBudget: string | null;
  duePaymentSchedulesCount: number | null;
  totalTasks: number;
  completedTasks: number;
  overdueTasks: number;
  todayTasks: number;
  guestCount: number;
  confirmedGuests: number;
  pendingGuests: number;
  declinedGuests: number;
  incompleteGuestsCount: number;
  providerCount: number;
  quoteRequestsCount: number;
  pendingQuoteRequests: number;
  receivedQuotes: number;
  acceptedProviders: number;
  acceptedProvidersCount: number;
  quoteStatusBreakdown: {
    pending: number;
    offered: number;
    accepted: number;
    rejectedClosed: number;
  };
  nextProviderAction: string;
  participantCount: number;
  pendingInvites: number;
  unreadNotificationsCount: number;
  highPriorityNotificationsCount: number;
  importantItems: DashboardImportantItemResponse[];
  nextBestActions: DashboardImportantItemResponse[];
  planProviders: DashboardProviderPreviewResponse[];
  importantNotifications: DashboardNotificationPreviewResponse[];
  latestImportantNotification: DashboardNotificationPreviewResponse | null;
  nextTask: {
    id: string;
    title: string;
    dueAt: Date | null;
    status: WeddingTaskStatus;
  } | null;
  nextPaymentScheduleDue: {
    id: string;
    weddingCostId: string;
    title: string;
    amount: string;
    dueDate: Date;
    status: PaymentScheduleStatus;
  } | null;
  moneySummary: {
    totalBudget: string | null;
    confirmedCost: string | null;
    paid: string | null;
    outstanding: string | null;
    remainingBudget: string | null;
    overBudget: boolean | null;
  };
  financialWarnings: {
    type:
      | "BUDGET_EXCEEDED"
      | "PAYMENT_SCHEDULE_OVERDUE"
      | "PAYMENT_SCHEDULE_DUE_SOON";
    severity: "WARNING" | "DANGER";
    message: string;
    count: number | null;
    amount: string | null;
  }[];
  taskSummary: {
    total: number;
    completed: number;
    pendingInProgress: number;
    overdue: number;
    dueToday: number;
  };
  guestSummary: {
    total: number;
    confirmed: number;
    pending: number;
    declined: number;
    incompleteGuestsCount: number;
  };
  providerQuoteSummary: {
    pending: number;
    received: number;
    offered: number;
    accepted: number;
    rejectedClosed: number;
    nextAction: string;
  };
  participantSummary: {
    count: number;
    pendingInvites: number;
    currentUserRole: "OWNER" | SharedMemberRole | null;
  };
  notificationSummary: { unread: number; highPriority: number };
  generatedAt: Date;
  currentUserRole: "OWNER" | SharedMemberRole | null;
  permissions: DashboardPermissionSummary;
}

export type DashboardImportantItemType =
  | "TASK_OVERDUE"
  | "TASK_TODAY"
  | "PAYMENT_SCHEDULE_DUE"
  | "PLAN_PROVIDER"
  | "QUOTE_RECEIVED"
  | "INVITE_PENDING"
  | "SET_LOCATION"
  | "SET_BUDGET"
  | "ADD_GUESTS"
  | "REQUEST_QUOTE";

export interface DashboardImportantItemResponse {
  id: string;
  type: DashboardImportantItemType;
  title: string;
  subtitle: string;
  body: string | null;
  icon: "calendar" | "wallet" | "provider";
  tone: "danger" | "warning" | "success" | "info";
  priority: "URGENT" | "HIGH" | "NORMAL" | "LOW";
  actionLabel: string;
  dueDate: Date | null;
  amount: string | null;
  route: string | null;
  routeTarget: string | null;
  entityId: string | null;
  data: Record<string, string | null>;
}

export interface DashboardProviderPreviewResponse {
  id: string;
  providerId: string;
  businessName: string;
  categoryName: string | null;
  serviceTitle: string | null;
  imageUrl: string | null;
  ratingAverage: string;
  ratingCount: number;
  status: PlanProviderLinkStatus;
}

export interface DashboardNotificationPreviewResponse {
  id: string;
  type: NotificationType;
  priority: NotificationPriority;
  title: string;
  body: string;
  readAt: Date | null;
  createdAt: Date;
  data: Prisma.JsonValue | null;
  entityType: string | null;
  entityId: string | null;
  routeTarget: string | null;
}

export interface DashboardTaskRecord {
  id: string;
  title: string;
  dueDate: Date | null;
  priority: Prisma.WeddingTaskGetPayload<object>["priority"];
}

export interface DashboardNotificationRecord {
  id: string;
  type: NotificationType;
  priority: NotificationPriority;
  title: string;
  body: string;
  readAt: Date | null;
  createdAt: Date;
  data: Prisma.JsonValue | null;
  entityType: string | null;
  entityId: string | null;
  routeTarget: string | null;
}

export interface DashboardPaymentScheduleRecord {
  id: string;
  weddingCostId: string;
  amount: Prisma.Decimal;
  dueDate: Date;
  status: PaymentScheduleStatus;
  weddingCost: { title: string };
}

export interface DashboardDueMoneyItem {
  id: string;
  weddingCostId: string;
  title: string;
  amount: Prisma.Decimal;
  dueDate: Date;
  status: PaymentScheduleStatus;
}

export interface DashboardPlanProviderLinkRecord {
  id: string;
  providerId: string;
  status: PlanProviderLinkStatus;
  provider: {
    id: string;
    businessName: string;
    coverUrl: string | null;
    logoUrl: string | null;
    ratingAverage: { toString(): string };
    ratingCount: number;
    primaryCategory: { nameAr: string } | null;
    services: { title: string; images: { imageUrl: string }[] }[];
  };
}
