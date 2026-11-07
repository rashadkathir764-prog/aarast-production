import { render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  getProvider,
  getProviderApplications,
  getProviderClaims,
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
};

const getOpenReports = vi.fn();

function renderInbox() {
  render(
    <MemoryRouter>
      <DashboardPage getOpenReports={getOpenReports} />
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
    vi.mocked(getProvider).mockReset();
    getOpenReports.mockReset();
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

  it('names the customer side when the provider filed the report', async () => {
    authState.adminPermissions = [AdminPermission.CONVERSATION_REPORTS_WRITE];
    vi.mocked(getProvider).mockResolvedValue({ userId: 'user-9' } as ProviderApplication);
    getOpenReports.mockResolvedValue({ items: [report], total: 1 });

    renderInbox();

    expect(await screen.findByText('«مصور مجهول» بلّغ عن عميل')).toBeVisible();
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
});
