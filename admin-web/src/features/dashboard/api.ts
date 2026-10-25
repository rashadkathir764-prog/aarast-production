import { apiRequest } from '../../platform/api/client';
import { toQuery } from '../../platform/api/query';

export type AdminStats = {
  totalUsers: number;
  totalProviders: number;
  pendingProviders: number;
  approvedProviders: number;
  rejectedProviders: number;
  needsChangesProviders: number;
  suspendedProviders: number;
  /** PENDING profiles sent back after changes (B-01); part of `pendingProviders`. */
  resubmittedProviders: number;
  /** Claims of a listing waiting for review (B-12). */
  pendingClaims: number;
  totalQuoteRequests: number;
  totalWeddingPlans: number;
  totalCities: number;
  totalProviderCategories: number;
};

export type AdminReport = {
  generatedAt: string;
  range: { from: string | null; to: string | null };
  users: {
    total: number;
    active: number;
    disabled: number;
    admins: number;
    providers: number;
    regularUsers: number;
  };
  providers: {
    total: number;
    pending: number;
    active: number;
    needsChanges: number;
    suspended: number;
    rejected: number;
    featured: number;
  };
  services: { total: number; active: number; disabled: number };
  reviews: { total: number; published: number; hidden: number; pending: number; averageRating: string };
  quotes: { total: number; byStatus: Array<{ status: string; count: number }> };
  notifications: { total: number; unread: number; archived: number; high: number; urgent: number };
  catalog: { cities: number; categories: number };
  weddingPlans: { total: number };
  source: string;
  paymentOrDepositDataIncluded: boolean;
};

type ReportQueryParams = {
  from?: string;
  to?: string;
};

export function getStats(): Promise<AdminStats> {
  return apiRequest<AdminStats>('/admin/dashboard/stats');
}

export function getReportOverview(
  params?: ReportQueryParams,
): Promise<AdminReport> {
  return apiRequest<AdminReport>(`/admin/reports/overview${toQuery(params ?? {})}`);
}

/** Success indicators and the market price report (V1 checklist 4.21). */
export type AdminSuccessReport = {
  generatedAt: string;
  activeUsers: { windowDays: number; active: number; total: number };
  costs: { recorded: number; plansWithCosts: number; perPlan: number | null };
  conversion: {
    windowDays: number;
    quoteRequests: number;
    confirmedBookings: number;
    rate: number | null;
  };
  visibleProviders: number;
  prices: Array<{
    cityId: string;
    categoryId: string;
    cityName: string | null;
    categoryName: string | null;
    currency: string;
    providers: number;
    services: number;
    min: string;
    median: string;
    max: string;
  }>;
};

export function getSuccessReport(): Promise<AdminSuccessReport> {
  return apiRequest<AdminSuccessReport>('/admin/reports/success');
}
