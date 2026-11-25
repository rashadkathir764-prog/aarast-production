import { render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  getProvider,
  getProviderApplications,
  getProviderClaims,
  getProfileChanges,
  type ProfileChange,
  type ProviderApplication,
  type ProviderClaimRequest,
} from '../providers/api';
import { AdminPermission } from '../auth/api';
import { DashboardPage, type InboxReport } from './DashboardPage';

vi.mock('../providers/api', async () => ({
  // The reading of a row stays the real one; only the requests are stubbed.
  sentBackAfterRefusal: (
    await vi.importActual<typeof import('../providers/api')>('../providers/api')
  ).sentBackAfterRefusal,
  getProviderApplications: vi.fn(),
  getProviderClaims: vi.fn(),
  getProfileChanges: vi.fn(),
  getProvider: vi.fn(),
}));

const authState = vi.hoisted(() => ({
  adminPermissions: [] as string[],
}));

vi.mock('../auth/AuthProvider', () => ({
  useAuth: () => ({
    user: {
      id: 'admin-1',
      name: 'نادية',
      adminPermissions: authState.adminPermissions,
    },
  }),
}));

const NOW = new Date('2026-10-24T09:00:00.000Z');

function application(id: string, name: string, createdAt: string) {
  return {
    id,
    businessName: name,
    status: 'PENDING',
    createdAt,
    primaryCategory: { nameAr: 'التصوير' },
    city: { nameAr: 'صنعاء' },
  } as ProviderApplication;
}

const report: InboxReport = {
  id: 'report-1',
  reason: 'احتيال: طلب تحويل لرقم ثاني',
  createdAt: '2026-10-24T06:00:00.000Z',
  reporter: { id: 'user-9', name: 'محمد' },
  conversation: { provider: { id: 'provider-9', businessName: 'مصور مجهول' } },
  reported: { kind: 'PROVIDER' },
};

const getOpenReports = vi.fn();
const getOpenAssistantReports = vi.fn();
const getPendingPhotos = vi.fn();
const getReportedReviews = vi.fn();
const getDeletions = vi.fn();

function renderInbox() {
  render(
    <MemoryRouter>
      <DashboardPage
        getOpenReports={getOpenReports}
        getOpenAssistantReports={getOpenAssistantReports}
        getPendingPhotos={getPendingPhotos}
        getReportedReviews={getReportedReviews}
        getDeletions={getDeletions}
      />
    </MemoryRouter>,
  );
}

describe('DashboardPage (n01 الصندوق)', () => {
  beforeEach(() => {
    vi.useFakeTimers({ toFake: ['Date'] });
    vi.setSystemTime(NOW);
    vi.mocked(getProviderApplications).mockReset();
    vi.mocked(getProviderClaims).mockReset();
    vi.mocked(getProviderClaims).mockResolvedValue({
      items: [],
      page: 1,
      limit: 100,
      total: 0,
      totalPages: 1,
    });
    vi.mocked(getProfileChanges).mockReset();
    vi.mocked(getProfileChanges).mockResolvedValue({
      items: [],
      page: 1,
      limit: 100,
      total: 0,
      totalPages: 1,
    });
    vi.mocked(getProvider).mockReset();
    getOpenReports.mockReset();
    for (const loader of [getOpenAssistantReports, getPendingPhotos, getReportedReviews]) {
      loader.mockReset();
      loader.mockResolvedValue({ items: [], total: 0 });
    }
    getDeletions.mockReset();
    getDeletions.mockResolvedValue({ deletions: [] });
    vi.mocked(getProvider).mockResolvedValue({ userId: 'owner-9' } as ProviderApplication);
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('lists pending applications with their two-day promise, the overdue first', async () => {
    authState.adminPermissions = [AdminPermission.PROVIDERS_WRITE];
    vi.mocked(getProviderApplications).mockResolvedValue({
      items: [
        application('p-new', 'استوديو ضوء صنعاء', '2026-10-23T09:00:00.000Z'),
        application('p-old', 'ضيافة الأصالة', '2026-10-21T09:00:00.000Z'),
      ],
      page: 1,
      limit: 100,
      total: 2,
      totalPages: 1,
    });

    renderInbox();

    const table = await screen.findByRole('table', { name: 'بنود الصندوق' });
    const rows = within(table).getAllByRole('row').slice(1);
    expect(rows[0]).toHaveTextContent('ضيافة الأصالة');
    expect(rows[0]).toHaveTextContent('تعدّى بيوم');
    expect(rows[0]).toHaveClass('is-hi');
    expect(rows[1]).toHaveTextContent('استوديو ضوء صنعاء');
    expect(rows[1]).toHaveTextContent('التصوير · صنعاء · قبل يوم');
    expect(rows[1]).toHaveTextContent('باقي يوم');
    expect(rows[1]).not.toHaveClass('is-hi');
    expect(within(table).getAllByText('انضمام')).toHaveLength(2);
    expect(
      screen.getByText('كل شغل اللوحة في مكان واحد · 2 مفتوح · 1 تعدّت الوقت'),
    ).toBeVisible();
    expect(getProviderApplications).toHaveBeenCalledWith({ status: 'PENDING', page: 1, limit: 100 });
    expect(getOpenReports).not.toHaveBeenCalled();
    expect(screen.getByText('الوعد لكل نوع').parentElement).toHaveTextContent('انضماميومين');
    expect(screen.queryByText('مسؤول')).not.toBeInTheDocument();
    expect(screen.queryByText('ضغط الفريق')).not.toBeInTheDocument();
  });

  // RA-AD-07: the server lists newest first, 100 at a time. The inbox read
  // one page and counted its rows, so past 100 the oldest (the most overdue)
  // never showed and the count was 100.
  it('holds every open item past a hundred, the oldest included', async () => {
    authState.adminPermissions = [AdminPermission.PROVIDERS_WRITE];
    const newest = Array.from({ length: 100 }, (_, index) =>
      application(`p-new-${index}`, `جديد ${index}`, '2026-10-24T08:00:00.000Z'),
    );
    const oldest = Array.from({ length: 30 }, (_, index) =>
      application(`p-old-${index}`, `قديم ${index}`, '2026-10-20T09:00:00.000Z'),
    );
    vi.mocked(getProviderApplications).mockImplementation(async (params) => ({
      items: params?.page === 1 ? newest : params?.page === 2 ? oldest : [],
      page: params?.page ?? 1,
      limit: 100,
      total: 130,
      totalPages: 2,
    }));

    renderInbox();

    const table = await screen.findByRole('table', { name: 'بنود الصندوق' });
    const rows = within(table).getAllByRole('row').slice(1);
    expect(rows).toHaveLength(130);
    expect(rows[0]).toHaveTextContent('قديم');
    expect(
      screen.getByText('كل شغل اللوحة في مكان واحد · 130 مفتوح · 30 تعدّت الوقت'),
    ).toBeVisible();
    expect(getProviderApplications).toHaveBeenCalledWith({ status: 'PENDING', page: 2, limit: 100 });
  });

  it('shows a profile sent back after changes from the time it came back, and a claim waiting for review (B-01, B-12)', async () => {
    authState.adminPermissions = [AdminPermission.PROVIDERS_WRITE];
    vi.mocked(getProviderApplications).mockResolvedValue({
      items: [
        {
          ...application('p-back', 'استوديو ضوء صنعاء', '2026-10-10T09:00:00.000Z'),
          resubmittedAt: '2026-10-24T07:00:00.000Z',
          // Refused long ago, then asked for changes: it came from changes
          // (finding 6).
          reopenedAt: '2026-10-12T09:00:00.000Z',
          latestDecision: { id: 'd1', kind: 'CHANGES_REQUESTED', at: '2026-10-20T09:00:00.000Z' },
        } as ProviderApplication,
        {
          ...application('p-refused', 'كوافيرة أم ريان', '2026-10-11T09:00:00.000Z'),
          resubmittedAt: '2026-10-24T06:00:00.000Z',
          reopenedAt: '2026-10-23T09:00:00.000Z',
          latestDecision: { id: 'd2', kind: 'REJECTED', at: '2026-10-22T09:00:00.000Z' },
        } as ProviderApplication,
      ],
      page: 1,
      limit: 100,
      total: 1,
      totalPages: 1,
    });
    vi.mocked(getProviderClaims).mockResolvedValue({
      items: [
        {
          id: 'claim-1',
          status: 'PENDING',
          note: null,
          createdAt: '2026-10-23T09:00:00.000Z',
          decidedAt: null,
          provider: { id: 'listing-1', businessName: 'مصور الحارة' },
          claimant: { id: 'u-1', name: 'عبدالله الحارثي', phone: '+967777000506' },
          decidedBy: null,
        } as ProviderClaimRequest,
      ],
      page: 1,
      limit: 100,
      total: 1,
      totalPages: 1,
    });

    renderInbox();

    const back = (await screen.findByText('استوديو ضوء صنعاء')).closest('tr');
    expect(back).toHaveTextContent('أُعيد إرساله بعد التعديل');
    expect(back).toHaveTextContent('باقي يوم');
    expect(screen.getByText('كوافيرة أم ريان').closest('tr')).toHaveTextContent(
      'قدّم من جديد بعد الرفض',
    );
    const claim = screen.getByText('مصور الحارة').closest('tr');
    expect(claim).toHaveTextContent('عبدالله الحارثي يطلب استلام الملف');
    expect(claim).toHaveTextContent('استلام');
    expect(getProviderClaims).toHaveBeenCalledWith({ status: 'PENDING', page: 1, limit: 100 });
  });

  // RA-AD-27: a provider's change of his name, logo, cover, city or category
  // waits for whom decides it, with the joining's two days.
  it('lists the provider profile changes waiting, with the two-day promise', async () => {
    authState.adminPermissions = [AdminPermission.PROVIDERS_WRITE];
    vi.mocked(getProviderApplications).mockResolvedValue({
      items: [],
      page: 1,
      limit: 100,
      total: 0,
      totalPages: 1,
    });
    vi.mocked(getProfileChanges).mockResolvedValue({
      items: [
        {
          id: 'change-1',
          status: 'PENDING',
          createdAt: '2026-10-21T09:00:00.000Z',
          provider: { id: 'provider-3', businessName: 'قاعة سبأ' },
        } as ProfileChange,
      ],
      page: 1,
      limit: 100,
      total: 1,
      totalPages: 1,
    });

    renderInbox();

    const table = await screen.findByRole('table', { name: 'بنود الصندوق' });
    const [row] = within(table).getAllByRole('row').slice(1);
    expect(row).toHaveTextContent('قاعة سبأ');
    expect(row).toHaveTextContent('يطلب تعديل ملفه');
    expect(row).toHaveTextContent('تعديل ملف');
    expect(row).toHaveTextContent('تعدّى بيوم');
    expect(getProfileChanges).toHaveBeenCalledWith({ status: 'PENDING', page: 1, limit: 100 });
    expect(screen.getByText('كل شغل اللوحة في مكان واحد · 1 مفتوح · 1 تعدّت الوقت')).toBeVisible();
  });

  it('lists open reports with the four-hour promise and names who reported whom', async () => {
    authState.adminPermissions = [AdminPermission.CONVERSATION_REPORTS_WRITE];
    getOpenReports.mockResolvedValue({ items: [report], total: 1 });

    renderInbox();

    const row = (await screen.findByText(report.reason)).closest('tr');
    expect(row).toHaveTextContent('محمد بلّغ عن «مصور مجهول»');
    expect(row).toHaveTextContent('بلاغ');
    expect(row).toHaveTextContent('باقي ساعة');
    expect(row?.querySelector('.desk-sla')).toHaveClass('is-late');
    expect(getProviderApplications).not.toHaveBeenCalled();
    expect(getProviderClaims).not.toHaveBeenCalled();
  });

  // RA-AD-22: the server names the customer the provider reported; the
  // inbox said «عميل» and guessed the side from the provider's owner.
  it('names the customer when the provider filed the report', async () => {
    authState.adminPermissions = [AdminPermission.CONVERSATION_REPORTS_WRITE];
    getOpenReports.mockResolvedValue({
      items: [{ ...report, reported: { kind: 'CUSTOMER', user: { name: 'نبيل' } } }],
      total: 1,
    });

    renderInbox();

    expect(await screen.findByText('«مصور مجهول» بلّغ عن نبيل')).toBeVisible();
    expect(getProvider).not.toHaveBeenCalled();
  });

  it('says so when nothing waits', async () => {
    authState.adminPermissions = [AdminPermission.PROVIDERS_WRITE];
    vi.mocked(getProviderApplications).mockResolvedValue({
      items: [],
      page: 1,
      limit: 100,
      total: 0,
      totalPages: 1,
    });

    renderInbox();

    expect(await screen.findByText('ما فيه شي ينتظر الآن.')).toBeVisible();
  });

  it('keeps the page and offers a retry when loading fails', async () => {
    authState.adminPermissions = [AdminPermission.PROVIDERS_WRITE];
    vi.mocked(getProviderApplications).mockRejectedValue(new Error('تعذر الاتصال'));

    renderInbox();

    await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent('تعذر الاتصال'));
    expect(screen.getByRole('heading', { name: 'الصندوق' })).toBeVisible();
  });

  // RA-AD-27: the photos waiting for review, the reported assistant answers
  // and reviews, and the deletions that failed sat outside the inbox, so the
  // desk's one place to look missed them.
  it('holds the photos, the reported answers and reviews and the failed deletions, for whom acts on each', async () => {
    authState.adminPermissions = [
      AdminPermission.REVIEWS_WRITE,
      AdminPermission.CONVERSATION_REPORTS_WRITE,
      AdminPermission.USERS_WRITE,
    ];
    getOpenReports.mockResolvedValue({ items: [], total: 0 });
    getPendingPhotos.mockResolvedValue({
      items: [{ id: 'photo-1', createdAt: '2026-10-24T08:30:00.000Z', provider: { id: 'p1', businessName: 'استوديو ضوء' } }],
      total: 1,
    });
    getOpenAssistantReports.mockResolvedValue({
      items: [{ id: 'answer-1', reason: 'الإجابة غلط في المهر', createdAt: '2026-10-24T07:00:00.000Z' }],
      total: 1,
    });
    getReportedReviews.mockResolvedValue({
      items: [
        {
          id: 'review-1',
          provider: { id: 'p2', businessName: 'قاعة الريان' },
          openReportCount: 2,
          openReports: [
            { reason: 'كلام مسيء', createdAt: '2026-10-24T06:00:00.000Z' },
            { reason: 'تقييم كاذب', createdAt: '2026-10-24T04:00:00.000Z' },
          ],
        },
      ],
      total: 1,
    });
    getDeletions.mockResolvedValue({
      deletions: [
        { userId: 'u-1', name: 'سالم', scheduledFor: '2026-10-23T09:00:00.000Z', purgeFailedAt: '2026-10-23T10:00:00.000Z' },
        { userId: 'u-2', name: 'علي', scheduledFor: '2026-11-10T09:00:00.000Z', purgeFailedAt: null },
      ],
    });

    renderInbox();

    const table = await screen.findByRole('table', { name: 'بنود الصندوق' });
    const rows = within(table).getAllByRole('row').slice(1);
    expect(rows).toHaveLength(4);
    // The failed deletion was due when it failed: it leads, overdue.
    expect(rows[0]).toHaveTextContent('سالم');
    expect(rows[0]).toHaveTextContent('الحذف ما كمل في موعده');
    expect(rows[0]).toHaveClass('is-hi');
    const photo = screen.getByText('صورة جديدة في معرض «استوديو ضوء»').closest('tr');
    expect(photo).toHaveTextContent('صورة');
    expect(photo).toHaveTextContent('باقي ساعة');
    const answer = screen.getByText('الإجابة غلط في المهر').closest('tr');
    expect(answer).toHaveTextContent('بلاغ على إجابة المساعد');
    const review = screen.getByText('تقييم على «قاعة الريان»').closest('tr');
    expect(review).toHaveTextContent('2 بلاغ · كلام مسيء');
    expect(review).toHaveTextContent('تعدّى');
    expect(screen.queryByText('علي')).not.toBeInTheDocument();
    expect(screen.getByText('كل شغل اللوحة في مكان واحد · 4 مفتوح · 2 تعدّت الوقت')).toBeVisible();
    expect(getPendingPhotos).toHaveBeenCalledWith({ status: 'PENDING', page: 1, limit: 100 });
    expect(getOpenAssistantReports).toHaveBeenCalledWith({ status: 'OPEN', page: 1, limit: 100 });
    expect(getReportedReviews).toHaveBeenCalledWith({ reported: 'true', page: 1, limit: 100 });
    const promises = screen.getByText('الوعد لكل نوع').parentElement;
    expect(promises).toHaveTextContent('صورة معرضساعتين');
    expect(promises).toHaveTextContent('حذف ما كملفورًا');
  });

  it('asks for none of those queues from an admin who cannot act on them', async () => {
    authState.adminPermissions = [AdminPermission.PROVIDERS_WRITE];
    vi.mocked(getProviderApplications).mockResolvedValue({
      items: [],
      page: 1,
      limit: 100,
      total: 0,
      totalPages: 1,
    });

    renderInbox();

    expect(await screen.findByText('ما فيه شي ينتظر الآن.')).toBeVisible();
    expect(getPendingPhotos).not.toHaveBeenCalled();
    expect(getOpenAssistantReports).not.toHaveBeenCalled();
    expect(getReportedReviews).not.toHaveBeenCalled();
    expect(getDeletions).not.toHaveBeenCalled();
  });
});
