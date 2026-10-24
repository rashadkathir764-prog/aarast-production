import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter, Route, Routes, useLocation } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  getProvider,
  getProviderApplication,
  getProviderApplications,
  getProviders,
  requestProviderChanges,
  suspendProvider,
  type ProviderApplication,
} from './api';
import { AdminPermission } from '../auth/api';
import { ProviderApplicationsPage } from './ProviderApplicationsPage';
import { ProviderApplicationDetailsPage } from './ProviderApplicationDetailsPage';
import { ProvidersPage } from './ProvidersPage';
import { ProviderDetailsPage } from './ProviderDetailsPage';

vi.mock('./api', () => ({
  getProviderApplications: vi.fn(),
  getProviderApplication: vi.fn(),
  getProviders: vi.fn(),
  getProvider: vi.fn(),
  approveProvider: vi.fn(),
  rejectProvider: vi.fn(),
  requestProviderChanges: vi.fn(),
  suspendProvider: vi.fn(),
  activateProvider: vi.fn(),
  setProviderVerified: vi.fn(),
  createListedProvider: vi.fn(),
}));

const authState = vi.hoisted(() => ({ adminPermissions: [] as string[] }));
vi.mock('../auth/AuthProvider', () => ({
  useAuth: () => ({ user: { id: 'admin-1', name: 'نادية', adminPermissions: authState.adminPermissions } }),
}));

const NOW = new Date('2026-10-24T08:00:00.000Z');
const ago = (hours: number) => new Date(NOW.getTime() - hours * 3_600_000).toISOString();

function provider(input: Partial<ProviderApplication> & { id: string; businessName: string }) {
  return {
    userId: 'owner-1',
    user: null,
    city: { id: 'c', nameAr: 'صنعاء' },
    primaryCategory: { id: 'k', nameAr: 'التصوير' },
    ownerName: null,
    phone: '773210455',
    status: 'ACTIVE',
    reviewNote: null,
    reviewedAt: null,
    reviewedBy: null,
    verifiedAt: null,
    isFeatured: false,
    ratingAverage: '0',
    ratingCount: 0,
    quoteRequestsCount: 0,
    services: [],
    packages: [],
    createdAt: ago(48),
    ...input,
  } as ProviderApplication;
}

const paged = (items: ProviderApplication[], limit = 20) => ({
  items,
  page: 1,
  limit,
  total: items.length,
  totalPages: 1,
});

function Where() {
  const location = useLocation();
  return <output data-testid="where">{location.pathname}</output>;
}

function renderAt(path: string, pattern: string, element: JSX.Element) {
  render(
    <MemoryRouter initialEntries={[path]}>
      <Routes>
        <Route path={pattern} element={element} />
        <Route path="*" element={<Where />} />
      </Routes>
    </MemoryRouter>,
  );
}

beforeEach(() => {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(NOW);
  authState.adminPermissions = [AdminPermission.PROVIDERS_READ, AdminPermission.PROVIDERS_WRITE];
});

afterEach(() => {
  vi.useRealTimers();
  vi.clearAllMocks();
});

describe('a03 طلبات الانضمام', () => {
  const getStats = vi.fn().mockResolvedValue({ pendingProviders: 8, needsChangesProviders: 6 });

  it('opens on the new ones, oldest first, with the two-day promise in coral', async () => {
    vi.mocked(getProviderApplications).mockResolvedValue(
      paged(
        [
          provider({ id: 'young', businessName: 'كوافيرة أم ريان', status: 'PENDING', createdAt: ago(5) }),
          provider({ id: 'old', businessName: 'استوديو ضوء صنعاء', status: 'PENDING', ownerName: 'علي الشامي', createdAt: ago(49) }),
        ],
        100,
      ),
    );

    renderAt('/a', '/a', <ProviderApplicationsPage getStats={getStats} />);

    const table = await screen.findByRole('table', { name: 'طلبات الانضمام' });
    const rows = within(table).getAllByRole('row').slice(1);
    expect(rows[0]).toHaveTextContent('استوديو ضوء صنعاء');
    expect(rows[0]).toHaveTextContent('علي الشامي · 773 210 455');
    expect(within(rows[0]).getByText('يومين')).toHaveClass('desk-ink--coral');
    expect(within(rows[1]).getByText('5 ساعات')).not.toHaveClass('desk-ink--coral');
    expect(getProviderApplications).toHaveBeenCalledWith({ status: 'PENDING', page: 1, limit: 100 });
    expect(await screen.findByRole('button', { name: 'جديد 8' })).toHaveAttribute('aria-pressed', 'true');
    expect(screen.getByRole('button', { name: 'يحتاج تعديل 6' })).toBeVisible();
    expect(screen.queryByText(/أُعيد إرسالها/)).not.toBeInTheDocument();
    expect(screen.getByText('الأقدم أول · نوعد المزود برد خلال يومين')).toBeVisible();
  });

  it('switches to the ones that need changes and shows the admin note', async () => {
    vi.mocked(getProviderApplications).mockResolvedValue(paged([], 100));
    renderAt('/a', '/a', <ProviderApplicationsPage getStats={getStats} />);
    await screen.findByText('ما فيه طلبات هنا.');

    vi.mocked(getProviderApplications).mockResolvedValue(
      paged([provider({ id: 'n', businessName: 'فرقة الأمجاد', status: 'NEEDS_CHANGES', reviewNote: 'أضف أسعارك', reviewedAt: ago(24) })], 100),
    );
    fireEvent.click(await screen.findByRole('button', { name: 'يحتاج تعديل 6' }));

    expect(await screen.findByText('أضف أسعارك')).toBeVisible();
    expect(getProviderApplications).toHaveBeenLastCalledWith({ status: 'NEEDS_CHANGES', page: 1, limit: 100 });
  });

  it('opens the review of a row', async () => {
    vi.mocked(getProviderApplications).mockResolvedValue(
      paged([provider({ id: 'p1', businessName: 'محلات الأناقة', status: 'PENDING' })], 100),
    );
    renderAt('/a', '/a', <ProviderApplicationsPage getStats={getStats} />);
    fireEvent.click(await screen.findByRole('row', { name: 'افتح طلب محلات الأناقة' }));
    expect(screen.getByTestId('where')).toHaveTextContent('/providers/applications/p1');
  });
});

describe('a04 مراجعة طلب', () => {
  it('shows the fields, the review line, and asks for changes with one note', async () => {
    vi.mocked(getProviderApplication).mockResolvedValue(
      provider({
        id: 'p1',
        businessName: 'استوديو ضوء صنعاء',
        status: 'PENDING',
        createdAt: '2026-10-18T07:00:00.000Z',
        address: 'كل صنعاء',
        services: [
          {
            id: 's1',
            title: 'باقة صور وفيديو',
            description: 'مصوّرين، 300 صورة',
            basePrice: '550000',
            priceUnit: null,
            currency: 'YER',
            isActive: true,
            images: [1, 2, 3].map((n) => ({ id: `i${n}`, serviceId: 's1', imageUrl: '', altText: null, sortOrder: n, createdAt: ago(1) })),
          },
        ],
      }),
    );
    vi.mocked(requestProviderChanges).mockResolvedValue(provider({ id: 'p1', businessName: 'x' }));

    renderAt('/r/p1', '/r/:id', <ProviderApplicationDetailsPage />);

    expect(await screen.findByRole('heading', { name: 'استوديو ضوء صنعاء' })).toBeVisible();
    expect(screen.getByText('التصوير · صنعاء · قدّم 18 أكتوبر')).toBeVisible();
    expect(screen.getByText('3 صور')).toBeVisible();
    expect(screen.getByText('550,000 ر.ي · مصوّرين، 300 صورة')).toBeVisible();
    expect(screen.getByText('صنعاء · كل صنعاء')).toBeVisible();
    expect(screen.getByText('قدّم الطلب')).toBeVisible();
    expect(screen.queryByText('فحص سريع')).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'ملاحظة' })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'اعتماد' })).toBeVisible();
    expect(screen.getByRole('button', { name: 'رفض' })).toBeVisible();

    fireEvent.click(screen.getByRole('button', { name: 'اطلب تعديل' }));
    const dialog = screen.getByRole('dialog', { name: 'اطلب تعديل من استوديو ضوء صنعاء' });
    const send = within(dialog).getByRole('button', { name: 'أرسل الملاحظة' });
    expect(send).toBeDisabled();
    fireEvent.change(within(dialog).getByLabelText('الملاحظة (توصل المزود)'), {
      target: { value: 'أضف صور بدون وجوه' },
    });
    fireEvent.click(send);
    await waitFor(() =>
      expect(requestProviderChanges).toHaveBeenCalledWith('p1', 'أضف صور بدون وجوه'),
    );
  });

  it('writes who decided and the note they sent', async () => {
    vi.mocked(getProviderApplication).mockResolvedValue(
      provider({
        id: 'p2',
        businessName: 'فرقة الأمجاد',
        status: 'NEEDS_CHANGES',
        reviewedAt: '2026-10-19T07:00:00.000Z',
        reviewedBy: { id: 'a', name: 'رشاد' } as ProviderApplication['reviewedBy'],
        reviewNote: 'حقلين: الصور والباقة',
      }),
    );
    renderAt('/r/p2', '/r/:id', <ProviderApplicationDetailsPage />);
    expect(await screen.findByText('رشاد طلب تعديل')).toBeVisible();
    expect(screen.getByText('للمزود: حقلين: الصور والباقة')).toBeVisible();
    expect(screen.queryByRole('button', { name: 'اطلب تعديل' })).not.toBeInTheDocument();
  });

  it('hides the decisions from read-only roles', async () => {
    authState.adminPermissions = [AdminPermission.PROVIDERS_READ];
    vi.mocked(getProviderApplication).mockResolvedValue(
      provider({ id: 'p3', businessName: 'محلات الأناقة', status: 'PENDING' }),
    );
    renderAt('/r/p3', '/r/:id', <ProviderApplicationDetailsPage />);
    await screen.findByRole('heading', { name: 'محلات الأناقة' });
    expect(screen.queryByRole('button', { name: 'اعتماد' })).not.toBeInTheDocument();
  });
});

describe('a05 دليل المزودين', () => {
  it('lists the marks and ratings, with totals from the server', async () => {
    vi.mocked(getProviders).mockResolvedValue(
      paged([
        provider({ id: 'saba', businessName: 'قاعة سبأ', verifiedAt: ago(1), isFeatured: true, ratingAverage: '4.8', ratingCount: 63 }),
        provider({ id: 'hara', businessName: 'مصور الحارة', userId: null }),
        provider({ id: 's', businessName: 'مصور س', status: 'SUSPENDED' }),
      ]),
    );
    renderAt(
      '/p',
      '/p',
      <ProvidersPage
        getCities={vi.fn().mockResolvedValue([])}
        getCategories={vi.fn().mockResolvedValue([])}
        getStats={vi.fn().mockResolvedValue({ totalProviders: 412, approvedProviders: 388 })}
      />,
    );

    const saba = await screen.findByRole('row', { name: 'افتح قاعة سبأ' });
    expect(saba).toHaveTextContent('موثّق');
    expect(saba).toHaveTextContent('مميز');
    expect(saba).toHaveTextContent('4.8 · 63');
    expect(screen.getByRole('row', { name: 'افتح مصور الحارة' })).toHaveTextContent('بلا حساب');
    expect(screen.getByRole('row', { name: 'افتح مصور س' })).toHaveTextContent('موقوف');
    expect(await screen.findByText('412 مزود · 388 نشط')).toBeVisible();
    expect(screen.queryByText('الحجوزات')).not.toBeInTheDocument();
    expect(getProviders).toHaveBeenCalledWith({ page: 1, limit: 20 });
  });

  it('opens the listed provider form in a window', async () => {
    vi.mocked(getProviders).mockResolvedValue(paged([]));
    const getCities = vi.fn().mockResolvedValue([]);
    renderAt(
      '/p',
      '/p',
      <ProvidersPage
        getCities={getCities}
        getCategories={vi.fn().mockResolvedValue([])}
        getStats={vi.fn().mockResolvedValue({ totalProviders: 0, approvedProviders: 0 })}
      />,
    );
    fireEvent.click(await screen.findByRole('button', { name: 'أضف مزود بلا حساب' }));
    expect(screen.getByRole('dialog', { name: 'أضف مزود بلا حساب' })).toBeVisible();
    await waitFor(() => expect(getCities).toHaveBeenCalled());
  });
});

describe('a06 تفاصيل مزود', () => {
  it('suspends with a reason and says only what the server does', async () => {
    vi.mocked(getProvider).mockResolvedValue(
      provider({
        id: 's',
        businessName: 'مصور س',
        verifiedAt: ago(100),
        reviewedAt: '2026-03-10T07:00:00.000Z',
        quoteRequestsCount: 3,
        ratingAverage: '3.9',
        ratingCount: 21,
        city: { id: 'a', nameAr: 'عدن' } as ProviderApplication['city'],
      }),
    );
    vi.mocked(suspendProvider).mockResolvedValue(provider({ id: 's', businessName: 'مصور س' }));

    renderAt('/d/s', '/d/:id', <ProviderDetailsPage />);

    expect(await screen.findByText('التصوير · عدن · نشط من مارس')).toBeVisible();
    expect(screen.getByText('طلبات العروض')).toBeVisible();
    expect(screen.getByText('21 تقييم')).toBeVisible();
    expect(screen.queryByText('حجوزات جاية')).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'إلغاء التوثيق' })).toBeVisible();

    fireEvent.click(screen.getByRole('button', { name: 'إيقاف' }));
    const dialog = screen.getByRole('dialog', { name: 'إيقاف مصور س' });
    expect(within(dialog).getAllByRole('listitem').map((item) => item.textContent)).toEqual([
      'يختفي من الدليل وما توصله طلبات جديدة.',
      'يوصله السبب، ويقدر يتواصل مع الدعم.',
    ]);
    fireEvent.change(within(dialog).getByLabelText('السبب (يوصل المزود)'), {
      target: { value: '3 بلاغات تأخير تسليم خلال شهرين' },
    });
    expect(within(dialog).getByRole('button', { name: 'تراجع' })).toBeVisible();
    fireEvent.click(within(dialog).getByRole('button', { name: 'أوقف' }));
    await waitFor(() =>
      expect(suspendProvider).toHaveBeenCalledWith('s', '3 بلاغات تأخير تسليم خلال شهرين'),
    );
  });
});
