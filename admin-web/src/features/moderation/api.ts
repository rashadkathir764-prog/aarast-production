import { apiRequest } from '../../platform/api/client';
import { type Paginated, toQuery } from '../../platform/api/query';
import type { ProviderReference } from '../providers/api';

export type ProviderReview = {
  id: string;
  userId: string;
  user: {
    id: string;
    name: string;
  };
  providerId: string;
  provider?: ProviderReference;
  rating: number;
  comment: string | null;
  status: string;
  createdAt: string;
  updatedAt: string;
};

export type ConversationReport = {
  id: string;
  conversationId: string;
  reason: string;
  status: 'OPEN' | 'REVIEWED' | 'DISMISSED';
  createdAt: string;
  updatedAt: string;
  reporter: {
    id: string;
    name: string;
    phone: string | null;
    avatarUrl: string | null;
  };
  conversation: {
    provider: { id: string; businessName: string };
    quoteRequests: Array<{ id: string }>;
  };
};

type QueryParams = {
  status?: string;
  providerId?: string;
  search?: string;
  page?: number;
  limit?: number;
};

export function getReviews(params: QueryParams = {}) {
  return apiRequest<Paginated<ProviderReview>>(
    `/admin/reviews${toQuery(params)}`,
  );
}

export function updateReviewStatus(id: string, status: string) {
  return apiRequest<ProviderReview>(`/admin/reviews/${id}/status`, {
    method: 'PATCH',
    body: { status },
  });
}

export function hideReview(id: string) {
  return apiRequest<ProviderReview & { deleted?: boolean }>(
    `/admin/reviews/${id}`,
    { method: 'DELETE' },
  );
}

export function getConversationReports(params: QueryParams = {}) {
  return apiRequest<Paginated<ConversationReport>>(
    `/admin/conversation-reports${toQuery(params)}`,
  );
}

export function updateConversationReportStatus(
  id: string,
  status: ConversationReport['status'],
) {
  return apiRequest<ConversationReport>(
    `/admin/conversation-reports/${id}/status`,
    { method: 'PATCH', body: { status } },
  );
}
