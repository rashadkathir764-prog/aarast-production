import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  getConversationReports,
  getReviews,
  hideReview,
  updateReviewStatus,
  type ConversationReport,
  type ProviderReview,
} from './api';
import { getProvider, getProviders, type ProviderApplication } from '../providers/api';
import { ConversationReportsPage } from './ConversationReportsPage';
import { ReviewsPage } from './ReviewsPage';

vi.mock('./api', () => ({
  getConversationReports: vi.fn(),
  updateConversationReportStatus: vi.fn(),
  getReviews: vi.fn(),
  hideReview: vi.fn(),
  updateReviewStatus: vi.fn(),
}));
vi.mock('../providers/api', () => ({ getProvider: vi.fn(), getProviders: vi.fn() }));
vi.mock('../auth/AuthProvider', () => ({
  useAuth: () => ({
    user: {
      id: 'admin-1',
      name: 'مدير',
      adminPermissions: ['USERS_READ', 'REVIEWS_WRITE', 'CONVERSATION_REPORTS_WRITE'],
    },
  }),
}));

const page = <T,>(items: T[]) => ({ items, page: 1, limit: 20, total: items.length, totalPages: 1 });

const report = (id: string, reporterId: string, reporterName: string): ConversationReport => ({
  id,
  conversationId: `conversation-${id}`,
  reason: 'احتيال',
  status: 'OPEN',
  createdAt: '2026-10-20T10:00:00.000Z',
  updatedAt: '2026-10-20T10:00:00.000Z',
  reporter: { id: reporterId, name: reporterName, phone: null, avatarUrl: null },
  conversation: {
    provider: { id: 'provider-1', businessName: 'استديو الفن' },
    quoteRequests: [{ id: 'quote-raw-id-123' }],
  },
});

const review = (status: string): ProviderReview => ({
  id: 'review-1',
  userId: 'user-1',
  user: { id: 'user-1', name: 'أحمد' },
  providerId: 'provider-1',
  rating: 4,
  comment: 'خدمة ممتازة',
  status,
  createdAt: '2026-10-20T10:00:00.000Z',
  updatedAt: '2026-10-20T10:00:00.000Z',
});

describe('ConversationReportsPage', () => {
  beforeEach(() => {
    vi.mocked(getConversationReports).mockResolvedValue(
      page([
        report('r1', 'customer-1', 'أحمد العريس'),
        report('r2', 'provider-owner-1', 'صاحب الاستديو'),
      ]),
    );
    vi.mocked(getProvider).mockResolvedValue({
      id: 'provider-1',
      userId: 'provider-owner-1',
    } as ProviderApplication);
  });

  it('links both parties and names the customer when the provider reports', async () => {
    render(
      <MemoryRouter>
        <ConversationReportsPage />
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getByText('أحمد العريس')).toBeInTheDocument());

    expect(screen.getByRole('link', { name: 'أحمد العريس' })).toHaveAttribute(
      'href',
      '/users/customer-1',
    );
    const customerRow = screen.getByText('أحمد العريس').closest('tr') as HTMLElement;
    expect(within(customerRow).getByRole('link', { name: 'استديو الفن' })).toHaveAttribute(
      'href',
      '/providers/provider-1',
    );

    const providerRow = screen.getByText('صاحب الاستديو').closest('tr') as HTMLElement;
    expect(within(providerRow).getByText('المزود نفسه')).toBeInTheDocument();
    expect(within(providerRow).getByText('العميل في المحادثة')).toBeInTheDocument();
    expect(screen.queryByText(/quote-raw-id-123/)).toBeNull();
  });
});

describe('ReviewsPage', () => {
  beforeEach(() => {
    vi.mocked(getReviews).mockResolvedValue(page([review('PUBLISHED')]));
    vi.mocked(getProviders).mockResolvedValue(page([]));
    vi.mocked(updateReviewStatus).mockReset();
    vi.mocked(hideReview).mockReset();
  });

  function renderReviews() {
    render(
      <MemoryRouter>
        <ReviewsPage />
      </MemoryRouter>,
    );
  }

  it('keeps the list when an action fails and says why', async () => {
    vi.mocked(updateReviewStatus).mockRejectedValue(new Error('تعذر تحديث التقييم الآن.'));
    renderReviews();
    await waitFor(() => expect(screen.getByText('خدمة ممتازة')).toBeInTheDocument());

    fireEvent.click(screen.getByRole('button', { name: 'مراجعة' }));

    expect(await screen.findByRole('alert')).toHaveTextContent('تعذر تحديث التقييم الآن.');
    expect(screen.getByText('خدمة ممتازة')).toBeInTheDocument();
  });

  it('asks before hiding a review', async () => {
    vi.mocked(hideReview).mockResolvedValue(review('HIDDEN'));
    renderReviews();
    await waitFor(() => expect(screen.getByText('خدمة ممتازة')).toBeInTheDocument());

    fireEvent.click(screen.getByRole('button', { name: 'إخفاء' }));
    expect(hideReview).not.toHaveBeenCalled();
    const dialog = await screen.findByRole('dialog');
    fireEvent.click(within(dialog).getByRole('button', { name: 'إخفاء' }));

    await waitFor(() => expect(hideReview).toHaveBeenCalledWith('review-1'));
  });
});
