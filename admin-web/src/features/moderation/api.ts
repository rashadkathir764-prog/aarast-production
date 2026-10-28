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
  /** B-09: the provider's one reply and whether customers read it. */
  reply?: { body: string; repliedAt: string; status: 'PUBLISHED' | 'HIDDEN' } | null;
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

/** a12 (B-40): a booking as the back office reads it; no amount, offer or payment. */
export type AdminBooking = {
  id: string;
  eventDate: string;
  status: 'REQUESTED' | 'CONFIRMED' | 'DECLINED' | 'CANCELLED' | 'EXPIRED';
  /** CONFIRMED whose day passed reads COMPLETED. */
  lifecycleStatus: AdminBooking['status'] | 'COMPLETED';
  provider: { id: string; businessName: string; status: string };
  customer: { userId: string; name: string | null; weddingPlanId: string | null };
  quoteRequestId: string;
  guestCount: number | null;
  cancelledBy: 'CUSTOMER' | 'PROVIDER' | null;
  /** The decline's or the cancel's reason. */
  note: string | null;
  requestedAt: string;
  confirmedAt: string | null;
  declinedAt: string | null;
  cancelledAt: string | null;
  expiredAt: string | null;
  updatedAt: string;
};

export type AdminBookingQuery = {
  providerId?: string;
  status?: string;
  from?: string;
  to?: string;
  page?: number;
  limit?: number;
};

export function getBookings(params: AdminBookingQuery = {}) {
  return apiRequest<Paginated<AdminBooking>>(`/admin/bookings${toQuery(params)}`);
}

export function getBooking(id: string) {
  return apiRequest<AdminBooking>(`/admin/bookings/${id}`);
}

/** n07 (B-16): a portfolio photo waiting for review, or decided. */
export type PortfolioPhoto = {
  id: string;
  /** Null once refused: the image is deleted. */
  imageUrl: string | null;
  album: string | null;
  /** «حفلات النساء»: brides only, and only without faces. */
  forWomen: boolean;
  noFaces: boolean;
  status: 'PENDING' | 'APPROVED' | 'REJECTED';
  rejectionReason: string | null;
  reviewedAt: string | null;
  createdAt: string;
  provider: { id: string; businessName: string; status: string };
};

export function getPortfolioPhotos(params: { status?: string; page?: number; limit?: number } = {}) {
  return apiRequest<Paginated<PortfolioPhoto>>(`/admin/portfolio-items${toQuery(params)}`);
}

/** «سليمة» approves (a women's photo with the no-faces check); «شِل» refuses with its reason. */
export function decidePortfolioPhoto(
  id: string,
  decision: { decision: 'APPROVE'; noFacesChecked?: boolean } | { decision: 'REJECT'; reason: string },
) {
  return apiRequest<PortfolioPhoto>(`/admin/portfolio-items/${id}/decision`, {
    method: 'PATCH',
    body: decision,
  });
}

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

/** B-09 (a10): hide the provider's reply like a review, or show it again. */
export function updateReviewReplyStatus(id: string, status: 'PUBLISHED' | 'HIDDEN') {
  return apiRequest<ProviderReview>(`/admin/reviews/${id}/reply-status`, {
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
