import {
  InstallmentStatus,
  NotificationPriority,
  NotificationType,
  PlanProviderLinkStatus,
  Prisma,
  SharedMemberRole,
  WeddingPlanStatus,
  WeddingTaskStatus,
} from '@prisma/client';
import { WeddingLocationResponse } from '../wedding-plans/wedding-location';

export interface DashboardPermissionSummary {
  isOwner: boolean;
  role: 'OWNER' | SharedMemberRole | null;
  canViewBudget: boolean;
  canViewExpenses: boolean;
  canViewFinancialRecords: boolean;
  canManageTasks: boolean;
  canManageGuests: boolean;
  canManageProviders: boolean;
  canManageMembers: boolean;
  canManageFinancialRecords: boolean;
  canManagePlan: boolean;
}

export interface WeddingPlanDashboardSummaryResponse {
  dataScope: 'ACCOUNT_BACKED';
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
  spentTotal: string | null;
  remainingBudget: string | null;
  commitmentTotal: string | null;
  commitmentPaidTotal: string | null;
  commitmentOutstandingTotal: string | null;
  dueInstallmentsCount: number | null;
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
  nextInstallmentDue: {
    id: string;
    financialCommitmentId: string;
    amount: string;
    dueAt: Date | null;
    status: InstallmentStatus;
  } | null;
  moneySummary: {
    totalBudget: string | null;
    totalSpent: string | null;
    remainingBudget: string | null;
    totalCommitments: string | null;
    overBudget: boolean | null;
  };
  financialWarnings: {
    type: 'BUDGET_EXCEEDED' | 'INSTALLMENT_OVERDUE' | 'INSTALLMENT_DUE_SOON';
    severity: 'WARNING' | 'DANGER';
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
    currentUserRole: 'OWNER' | SharedMemberRole | null;
  };
  notificationSummary: {
    unread: number;
    highPriority: number;
  };
  generatedAt: Date;
  currentUserRole: 'OWNER' | SharedMemberRole | null;
  permissions: DashboardPermissionSummary;
}

export type DashboardImportantItemType =
  | 'TASK_OVERDUE'
  | 'TASK_TODAY'
  | 'INSTALLMENT_DUE'
  | 'PLAN_PROVIDER'
  | 'QUOTE_RECEIVED'
  | 'INVITE_PENDING'
  | 'SET_LOCATION'
  | 'SET_BUDGET'
  | 'ADD_GUESTS'
  | 'REQUEST_QUOTE';

export interface DashboardImportantItemResponse {
  id: string;
  type: DashboardImportantItemType;
  title: string;
  subtitle: string;
  body: string | null;
  icon: 'calendar' | 'wallet' | 'provider';
  tone: 'danger' | 'warning' | 'success' | 'info';
  priority: 'URGENT' | 'HIGH' | 'NORMAL' | 'LOW';
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
  priority: Prisma.WeddingTaskGetPayload<object>['priority'];
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

export interface DashboardFinancialCommitmentRecord {
  id: string;
  title: string;
}

export interface DashboardFinancialInstallmentRecord {
  id: string;
  financialCommitmentId: string;
  amount: Prisma.Decimal;
  dueDate: Date | null;
  status: InstallmentStatus;
}

export interface DashboardDueMoneyItem {
  id: string;
  financialCommitmentId: string;
  title: string;
  amount: Prisma.Decimal;
  dueDate: Date | null;
  status: InstallmentStatus;
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
    services: {
      title: string;
      images: { imageUrl: string }[];
    }[];
  };
}
