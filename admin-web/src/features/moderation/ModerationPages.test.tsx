import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  getConversationReports,
  getReviews,
  hideReview,
  updateConversationReportStatus,
  updateReviewReplyStatus,
  updateReviewStatus,
  type ConversationReport,
  type ProviderReview,
} from './api';
import { getProvider, type ProviderApplication } from '../providers/api';
import { ConversationReportsPage } from './ConversationReportsPage';
import { ReviewsPage } from './ReviewsPage';

vi.mock('./api', () => ({
  getConversationReports: vi.fn(),
  updateConversationReportStatus: vi.fn(),
  getReviews: vi.fn(),
  hideReview: vi.fn(),
  updateReviewReplyStatus: vi.fn(),
  updateReviewStatus: vi.fn(),
}));
vi.mock('../providers/api', () => ({ getProvider: vi.fn(), getProviders: vi.fn() }));
vi.mock('../auth/AuthProvider', () => ({
  useAuth: () => ({
    user: {
      id: 'admin-1',
      name: 'سارة',
      adminPermissions: ['USERS_READ', 'REVIEWS_WRITE', 'CONVERSATION_REPORTS_WRITE'],
    },
  }),
}));

const NOW = new Date('2026-10-24T08:00:00.000Z');

const page = <T,>(items: T[]) => ({ items, page: 1, limit: 20, total: items.length, totalPages: 1 });

const report = (
  id: string,
  reporterId: string,
  reporterName: string,
  reason = 'احتيال',
  createdAt = '2026-10-23T10:00:00.000Z',
): ConversationReport => ({
  id,
  conversationId: `conversation-${id}`,
  reason,
  status: 'OPEN',
  createdAt,
  updatedAt: createdAt,
  reporter: { id: reporterId, name: reporterName, phone: null, avatarUrl: null },
  conversation: {
    provider: { id: 'provider-1', businessName: 'استديو الفن' },
    quoteRequests: [{ id: 'quote-raw-id-123' }],
  },
});

const review = (status: string): ProviderReview => ({
  id: 'review-1',
  userId: 'user-1',
  user: { id: 'user-1', name: 'عادل' },
  providerId: 'provider-1',
  provider: { id: 'provider-1', businessName: 'فرقة الأفراح' } as ProviderReview['provider'],
  rating: 2,
  comment: 'ما جوا أصلًا',
  status,
  createdAt: '2026-01-20T10:00:00.000Z',
  updatedAt: '2026-01-20T10:00:00.000Z',
});

beforeEach(() => {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(NOW);
});

afterEach(() => {
  vi.useRealTimers();
  vi.clearAllMocks();
});

describe('ConversationReportsPage (a11)', () => {
  beforeEach(() => {
    vi.mocked(getConversationReports).mockResolvedValue(
      page([
        report('r1', 'customer-1', 'أحمد العريس', 'كلام غير لائق'),
        report('r2', 'provider-owner-1', 'صاحب الاستديو', 'إزعاج', '2026-10-21T10:00:00.000Z'),
      ]),
    );
    vi.mocked(getProvider).mockResolvedValue({
      id: 'provider-1',
      userId: 'provider-owner-1',
    } as ProviderApplication);
  });

  function renderReports() {
    render(
      <MemoryRouter>
        <ConversationReportsPage />
      </MemoryRouter>,
    );
  }

  it('lists the open reports and reads the first one, linking both parties', async () => {
    renderReports();

    const first = await screen.findByRole('row', { name: 'اقرأ بلاغ كلام غير لائق' });
    expect(first).toHaveTextContent('أحمد العريس بلّغ عن استديو الفن · أمس');
    expect(first).toHaveClass('is-hi');
    expect(getConversationReports).toHaveBeenCalledWith({ status: 'OPEN', page: 1, limit: 20 });

    expect(screen.getByRole('heading', { name: 'كلام غير لائق' })).toBeVisible();
    expect(screen.getByRole('link', { name: 'أحمد العريس' })).toHaveAttribute('href', '/users/customer-1');
    expect(screen.getByRole('link', { name: 'استديو الفن' })).toHaveAttribute('href', '/providers/provider-1');
    expect(screen.queryByText(/quote-raw-id-123/)).toBeNull();
    expect(screen.queryByRole('button', { name: 'احذف الرسالة' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'اطلب إيقافه' })).not.toBeInTheDocument();
  });

  it('names the customer when the provider reports', async () => {
    renderReports();

    const second = await screen.findByRole('row', { name: 'اقرأ بلاغ إزعاج' });
    expect(second).toHaveTextContent('استديو الفن بلّغ عن العميل · قبل 3 أيام');
    fireEvent.click(second);

    expect(screen.getByRole('heading', { name: 'إزعاج' })).toBeVisible();
    expect(screen.getByText(/المزود نفسه/)).toHaveTextContent('العميل في المحادثة');
  });

  it('closes a report as handled or as nothing, and says why when it fails', async () => {
    vi.mocked(updateConversationReportStatus).mockRejectedValueOnce(new Error('تعذر التحديث الآن.'));
    renderReports();
    await screen.findByRole('heading', { name: 'كلام غير لائق' });

    fireEvent.click(screen.getByRole('button', { name: 'ما فيه شيء' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('تعذر التحديث الآن.');
    expect(updateConversationReportStatus).toHaveBeenCalledWith('r1', 'DISMISSED');

    vi.mocked(updateConversationReportStatus).mockResolvedValue({} as ConversationReport);
    fireEvent.click(screen.getByRole('button', { name: 'تمت المراجعة' }));
    await waitFor(() =>
      expect(updateConversationReportStatus).toHaveBeenLastCalledWith('r1', 'REVIEWED'),
    );
  });
});

describe('ReviewsPage (a10)', () => {
  beforeEach(() => {
    vi.mocked(getReviews).mockResolvedValue(page([review('PUBLISHED')]));
  });

  function renderReviews() {
    render(
      <MemoryRouter>
        <ReviewsPage />
      </MemoryRouter>,
    );
  }

  it('shows the stars, the words, the reviewer and the provider', async () => {
    renderReviews();
    const row = (await screen.findByText(/ما جوا أصلًا/)).closest('tr') as HTMLElement;
    expect(row).toHaveTextContent('★★☆☆☆ «ما جوا أصلًا»');
    expect(row).toHaveTextContent('عادل · 20 يناير');
    expect(row).toHaveTextContent('فرقة الأفراح');
    expect(screen.getByText('تنشر على طول · المخالف ينخفي')).toBeVisible();
    // RA-ST-05: the reported ones have their own tab; a review nobody
    // reported has no «خلّه».
    expect(screen.getByRole('button', { name: 'مبلّغ عنها' })).toBeVisible();
    expect(screen.queryByRole('button', { name: 'خلّه' })).not.toBeInTheDocument();
  });

  // RA-ST-05: a reported review shows its reports; «خلّه» keeps it, which
  // answers them.
  it('lists the reported ones with their reports and keeps one', async () => {
    vi.mocked(getReviews).mockResolvedValue(
      page([
        {
          ...review('PUBLISHED'),
          openReports: [
            { reason: 'كلام مسيء', createdAt: '2027-01-21T10:00:00.000Z' },
            { reason: 'ما حجز عندهم أصلًا', createdAt: '2027-01-20T10:00:00.000Z' },
          ],
        },
      ]),
    );
    vi.mocked(updateReviewStatus).mockResolvedValue(review('PUBLISHED'));
    renderReviews();
    await screen.findByText(/ما جوا أصلًا/);

    fireEvent.click(screen.getByRole('button', { name: 'مبلّغ عنها' }));
    await waitFor(() =>
      expect(getReviews).toHaveBeenLastCalledWith({ reported: 'true', page: 1, limit: 20 }),
    );
    const row = (await screen.findByText(/ما جوا أصلًا/)).closest('tr') as HTMLElement;
    expect(row).toHaveTextContent('بلاغات (2): «كلام مسيء»، «ما حجز عندهم أصلًا»');

    fireEvent.click(within(row).getByRole('button', { name: 'خلّه' }));
    await waitFor(() => expect(updateReviewStatus).toHaveBeenCalledWith('review-1', 'PUBLISHED'));
  });

  // RA-ST-05: the server lists five reasons at most; the count is all of them.
  it('counts every open report, not only the reasons it lists', async () => {
    vi.mocked(getReviews).mockResolvedValue(
      page([
        {
          ...review('PUBLISHED'),
          openReports: [{ reason: 'كلام مسيء', createdAt: '2027-01-21T10:00:00.000Z' }],
          openReportCount: 7,
        },
      ]),
    );
    renderReviews();
    const row = (await screen.findByText(/ما جوا أصلًا/)).closest('tr') as HTMLElement;
    expect(row).toHaveTextContent('بلاغات (7): «كلام مسيء»');
  });

  it('asks before hiding a review', async () => {
    vi.mocked(hideReview).mockResolvedValue(review('HIDDEN'));
    renderReviews();
    await screen.findByText(/ما جوا أصلًا/);

    fireEvent.click(screen.getByRole('button', { name: 'أخفِ' }));
    expect(hideReview).not.toHaveBeenCalled();
    const dialog = await screen.findByRole('dialog', { name: 'إخفاء تقييم عادل' });
    fireEvent.click(within(dialog).getByRole('button', { name: 'أخفِ' }));

    await waitFor(() => expect(hideReview).toHaveBeenCalledWith('review-1'));
  });

  it('lists the hidden ones and brings one back, keeping the list when that fails', async () => {
    vi.mocked(getReviews).mockResolvedValue(page([review('HIDDEN')]));
    vi.mocked(updateReviewStatus).mockRejectedValue(new Error('تعذر تحديث التقييم الآن.'));
    renderReviews();
    await screen.findByText(/ما جوا أصلًا/);

    fireEvent.click(screen.getByRole('button', { name: 'مخفية' }));
    await waitFor(() =>
      expect(getReviews).toHaveBeenLastCalledWith({ status: 'HIDDEN', page: 1, limit: 20 }),
    );
    fireEvent.click(await screen.findByRole('button', { name: 'أظهره' }));

    expect(await screen.findByRole('alert')).toHaveTextContent('تعذر تحديث التقييم الآن.');
    expect(updateReviewStatus).toHaveBeenCalledWith('review-1', 'PUBLISHED');
    expect(screen.getByText(/ما جوا أصلًا/)).toBeInTheDocument();
  });

  // B-09: «رد المزود: «…»» as a10 draws it; the team hides it after asking,
  // and brings a hidden one back.
  it('shows the provider reply and hides it after asking', async () => {
    vi.mocked(getReviews).mockResolvedValue(
      page([
        {
          ...review('PUBLISHED'),
          reply: { body: 'العريس لغى قبل يوم', repliedAt: '2026-01-21T10:00:00.000Z', status: 'PUBLISHED' },
        },
      ]),
    );
    vi.mocked(updateReviewReplyStatus).mockResolvedValue(review('PUBLISHED'));
    renderReviews();
    const row = (await screen.findByText(/ما جوا أصلًا/)).closest('tr') as HTMLElement;
    expect(row).toHaveTextContent('عادل · 20 يناير · رد المزود: «العريس لغى قبل يوم»');

    fireEvent.click(within(row).getByRole('button', { name: 'أخفِ الرد' }));
    expect(updateReviewReplyStatus).not.toHaveBeenCalled();
    const dialog = await screen.findByRole('dialog', { name: 'إخفاء رد فرقة الأفراح' });
    fireEvent.click(within(dialog).getByRole('button', { name: 'أخفِ الرد' }));
    await waitFor(() => expect(updateReviewReplyStatus).toHaveBeenCalledWith('review-1', 'HIDDEN'));
  });

  it('marks a hidden reply and shows it again', async () => {
    vi.mocked(getReviews).mockResolvedValue(
      page([
        {
          ...review('PUBLISHED'),
          reply: { body: 'العريس لغى قبل يوم', repliedAt: '2026-01-21T10:00:00.000Z', status: 'HIDDEN' },
        },
      ]),
    );
    vi.mocked(updateReviewReplyStatus).mockResolvedValue(review('PUBLISHED'));
    renderReviews();
    const row = (await screen.findByText(/ما جوا أصلًا/)).closest('tr') as HTMLElement;
    expect(row).toHaveTextContent('رد المزود (مخفي): «العريس لغى قبل يوم»');
    expect(within(row).queryByRole('button', { name: 'أخفِ الرد' })).not.toBeInTheDocument();
    fireEvent.click(within(row).getByRole('button', { name: 'أظهر الرد' }));
    await waitFor(() => expect(updateReviewReplyStatus).toHaveBeenCalledWith('review-1', 'PUBLISHED'));
  });
});
