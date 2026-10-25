import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  endFeaturedPeriod,
  getFeaturedPeriods,
  getFeaturedSummary,
  getProviders,
  grantFeaturedPeriod,
  type FeaturedPeriod,
  type ProviderApplication,
} from './api';
import { AdminPermission } from '../auth/api';
import { ApiError } from '../../platform/api/client';
import { addDays, FeaturedPlacementsPage, yemenToday } from './FeaturedPlacementsPage';

vi.mock('./api', () => ({
  getFeaturedPeriods: vi.fn(),
  getFeaturedSummary: vi.fn(),
  getProviders: vi.fn(),
  grantFeaturedPeriod: vi.fn(),
  endFeaturedPeriod: vi.fn(),
}));

const authState = vi.hoisted(() => ({ adminPermissions: [] as string[] }));
vi.mock('../auth/AuthProvider', () => ({
  useAuth: () => ({ user: { id: 'admin-1', name: 'نادية', adminPermissions: authState.adminPermissions } }),
}));

// 25 October in Sana'a.
const NOW = new Date('2026-10-25T09:00:00.000Z');

const listing = {
  id: 'hall',
  businessName: 'قاعة سبأ',
  phone: '777000202',
  whatsapp: null,
  logoUrl: null,
  status: 'ACTIVE',
  ratingAverage: '4.8',
  ratingCount: 63,
  city: { id: 'c', nameAr: 'صنعاء', nameEn: null, countryCode: 'YE', isActive: true, sortOrder: 1 },
  primaryCategory: {
    id: 'k',
    nameAr: 'الصالات',
    nameEn: null,
    slug: 'halls',
    icon: null,
    showForGroom: true,
    showForBride: true,
    isActive: true,
    sortOrder: 1,
  },
};

function period(input: Partial<FeaturedPeriod> & { id: string }): FeaturedPeriod {
  return {
    state: 'ACTIVE',
    providerShown: true,
    startsAt: '2026-09-30T21:00:00.000Z',
    endsAt: '2026-12-31T21:00:00.000Z',
    startsOn: '2026-10-01',
    lastDay: '2026-12-31',
    note: 'كاش · 3 شهور',
    createdAt: '2026-10-01T09:00:00.000Z',
    grantedBy: { id: 'admin-1', name: 'نادية' },
    endedAt: null,
    endedBy: null,
    endNote: null,
    startNoticeAt: '2026-10-01T09:00:00.000Z',
    endingNoticeAt: null,
    endNoticeAt: null,
    provider: listing,
    ...input,
  };
}

function renderPage() {
  render(
    <MemoryRouter>
      <FeaturedPlacementsPage />
    </MemoryRouter>,
  );
}

beforeEach(() => {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(NOW);
  authState.adminPermissions = [AdminPermission.PROVIDERS_READ, AdminPermission.PROVIDERS_WRITE];
  vi.mocked(getFeaturedSummary).mockResolvedValue({
    listedProviders: 388,
    featured: 27,
    free: 361,
    endingThisWeek: 4,
  });
  vi.mocked(getFeaturedPeriods).mockResolvedValue({
    items: [
      period({ id: 'p1' }),
      period({
        id: 'p2',
        state: 'EXPIRED',
        startsOn: '2026-09-15',
        lastDay: '2026-10-14',
        note: 'حوالة الكريمي',
        grantedBy: { id: 'admin-2', name: 'سارة' },
        provider: { ...listing, id: 'studio', businessName: 'استوديو ضوء صنعاء' },
      }),
    ],
    page: 1,
    limit: 50,
    total: 2,
    totalPages: 1,
  });
});

afterEach(() => {
  vi.useRealTimers();
  vi.clearAllMocks();
});

describe('a17 featured placements', () => {
  it('draws the counts, the placements and the note as a17, with no money and no «احترافي»', async () => {
    renderPage();
    const hall = (await screen.findByText('قاعة سبأ')).closest('tr') as HTMLElement;
    expect(hall).toHaveTextContent('الصالات · صنعاء');
    expect(hall).toHaveTextContent('مميز');
    expect(hall).toHaveTextContent('1 أكتوبر');
    expect(hall).toHaveTextContent('31 ديسمبر');
    expect(hall).toHaveTextContent('كاش · 3 شهور');
    expect(hall).toHaveTextContent('سجّلها نادية');
    expect(hall).toHaveTextContent('شغّال');
    const studio = screen.getByText('استوديو ضوء صنعاء').closest('tr') as HTMLElement;
    expect(studio).toHaveTextContent('خلص');
    expect(studio).not.toHaveTextContent('ذكّره');
    expect(screen.getByText('361')).toBeVisible();
    expect(screen.getByText('ظهور عادي')).toBeVisible();
    expect(screen.getByText('فوق في القسم والمدينة')).toBeVisible();
    expect(screen.getByText('تنتهي هذا الأسبوع')).toBeVisible();
    expect(screen.queryByText('احترافي')).not.toBeInTheDocument();
    expect(screen.queryByText('ينتظر الدفع')).not.toBeInTheDocument();
    expect(screen.getByText(/التطبيق ما يستلم فلوس/)).toBeVisible();
    // The table lists what runs or is booked, under a title that says so.
    expect(getFeaturedPeriods).toHaveBeenCalledWith({ state: 'CURRENT', page: 1, limit: 50 });
    expect(screen.getByRole('table', { name: 'الشغّالة والمحجوزة' })).toBeVisible();
  });

  it('lists the finished placements behind their own filter', async () => {
    renderPage();
    await screen.findByText('قاعة سبأ');
    fireEvent.click(screen.getByRole('button', { name: 'اللي خلصت' }));
    await waitFor(() =>
      expect(getFeaturedPeriods).toHaveBeenLastCalledWith({ state: 'FINISHED', page: 1, limit: 50 }),
    );
    expect(await screen.findByRole('table', { name: 'اللي خلصت' })).toBeVisible();
    expect(screen.getByRole('button', { name: 'اللي خلصت' })).toHaveAttribute('aria-pressed', 'true');
  });

  it('says «مو ظاهر للعرسان» instead of «شغّال» when customers cannot find the provider', async () => {
    vi.mocked(getFeaturedPeriods).mockResolvedValue({
      items: [period({ id: 'p1', providerShown: false })],
      page: 1,
      limit: 50,
      total: 1,
      totalPages: 1,
    });
    renderPage();
    const hall = (await screen.findByText('قاعة سبأ')).closest('tr') as HTMLElement;
    expect(hall).toHaveTextContent('مو ظاهر للعرسان');
    expect(hall).not.toHaveTextContent('شغّال');
  });

  it('records a placement for an active provider from today to the chosen last day', async () => {
    vi.mocked(getProviders).mockResolvedValue({
      items: [{ ...listing, isFeatured: false } as unknown as ProviderApplication],
      page: 1,
      limit: 8,
      total: 1,
      totalPages: 1,
    });
    vi.mocked(grantFeaturedPeriod).mockResolvedValue(period({ id: 'p3' }));
    renderPage();
    await screen.findByText('قاعة سبأ');
    fireEvent.click(screen.getByRole('button', { name: 'فعّل باقة لمزود' }));
    const dialog = screen.getByRole('dialog', { name: 'فعّل باقة «مميز»' });
    fireEvent.change(within(dialog).getByPlaceholderText('ابحث باسم النشاط أو الرقم'), {
      target: { value: 'سبأ' },
    });
    fireEvent.click(within(dialog).getByRole('button', { name: 'ابحث' }));
    fireEvent.click(await within(dialog).findByRole('button', { name: 'قاعة سبأ' }));
    expect(getProviders).toHaveBeenCalledWith({ status: 'ACTIVE', search: 'سبأ', limit: 8 });
    expect(within(dialog).getByText(/التطبيق ما يستلم فلوس، ولا يسجّل مبلغ/)).toBeVisible();
    fireEvent.change(within(dialog).getByLabelText('آخر يوم'), { target: { value: '2026-12-31' } });
    fireEvent.change(within(dialog).getByLabelText('كيف دفع برا التطبيق (اختياري)'), {
      target: { value: 'كاش · 3 شهور' },
    });
    // The truth: he comes up with the featured, not «أول في قسمه ومدينته».
    expect(within(dialog).getByText(/من 25 أكتوبر لين 31 ديسمبر يطلع مع المميزين أول/)).toBeVisible();
    expect(within(dialog).queryByText(/قسمه ومدينته/)).not.toBeInTheDocument();
    fireEvent.click(within(dialog).getByRole('button', { name: 'فعّل' }));
    await waitFor(() =>
      expect(grantFeaturedPeriod).toHaveBeenCalledWith('hall', { endsOn: '2026-12-31', note: 'كاش · 3 شهور' }),
    );
  });

  it('renews after the current placement and reads a refusal in Arabic', async () => {
    vi.mocked(grantFeaturedPeriod).mockRejectedValue(
      new ApiError('overlap', 409, 'FEATURED_PERIOD_OVERLAP'),
    );
    renderPage();
    const hall = (await screen.findByText('قاعة سبأ')).closest('tr') as HTMLElement;
    fireEvent.click(within(hall).getByRole('button', { name: 'جدّد' }));
    const dialog = screen.getByRole('dialog', { name: 'فعّل باقة «مميز»' });
    expect(within(dialog).getByLabelText('أول يوم')).toHaveValue('2027-01-01');
    fireEvent.click(within(dialog).getByRole('button', { name: 'فعّل' }));
    await waitFor(() =>
      expect(grantFeaturedPeriod).toHaveBeenCalledWith('hall', { endsOn: '2027-01-31', startsOn: '2027-01-01' }),
    );
    expect(
      await within(dialog).findByText('عنده ظهور مميز في نفس الأيام. خلّ الجديد يبدأ بعد آخر يوم في الحالي.'),
    ).toBeVisible();
  });

  it('reads the refusal of a provider customers cannot find in Arabic', async () => {
    vi.mocked(grantFeaturedPeriod).mockRejectedValue(
      new ApiError('not listed', 409, 'FEATURED_PROVIDER_NOT_LISTED'),
    );
    renderPage();
    const hall = (await screen.findByText('قاعة سبأ')).closest('tr') as HTMLElement;
    fireEvent.click(within(hall).getByRole('button', { name: 'جدّد' }));
    const dialog = screen.getByRole('dialog', { name: 'فعّل باقة «مميز»' });
    fireEvent.click(within(dialog).getByRole('button', { name: 'فعّل' }));
    expect(await within(dialog).findByText(/المزود مو ظاهر للعرسان: ما عنده خدمة شغّالة/)).toBeVisible();
  });

  it('stops an active placement with a note the provider reads', async () => {
    vi.mocked(endFeaturedPeriod).mockResolvedValue(period({ id: 'p1', state: 'ENDED' }));
    renderPage();
    const hall = (await screen.findByText('قاعة سبأ')).closest('tr') as HTMLElement;
    fireEvent.click(within(hall).getByRole('button', { name: 'وقّفه' }));
    const dialog = screen.getByRole('dialog', { name: 'نوقّف ظهور «قاعة سبأ» المميز؟' });
    expect(dialog).toHaveTextContent('التطبيق ما يرجّع فلوس');
    fireEvent.change(within(dialog).getByRole('textbox'), { target: { value: 'طلب يوقفها' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'وقّفه' }));
    await waitFor(() => expect(endFeaturedPeriod).toHaveBeenCalledWith('p1', 'طلب يوقفها'));
  });

  it('shows the placements without the actions to a role that only reads providers', async () => {
    authState.adminPermissions = [AdminPermission.PROVIDERS_READ];
    renderPage();
    await screen.findByText('قاعة سبأ');
    expect(screen.queryByRole('button', { name: 'فعّل باقة لمزود' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'وقّفه' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'جدّد' })).not.toBeInTheDocument();
  });

  it('counts Yemen days', () => {
    expect(yemenToday(new Date('2026-10-24T22:30:00.000Z'))).toBe('2026-10-25');
    expect(addDays('2026-12-31', 1)).toBe('2027-01-01');
  });
});
