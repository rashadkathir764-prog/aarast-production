import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter, Route, Routes, useLocation } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  approveProviderClaim,
  getProvider,
  getProviderApplication,
  getProviderApplications,
  getProviderClaims,
  getProviderReviewHistory,
  getProviders,
  rejectProviderClaim,
  requestProviderChanges,
  suspendProvider,
  type ProviderApplication,
  type ProviderClaimRequest,
  type ProviderReviewEvent,
} from './api';
import { AdminPermission } from '../auth/api';
import { ProviderApplicationsPage } from './ProviderApplicationsPage';
import { ProviderApplicationDetailsPage } from './ProviderApplicationDetailsPage';
import { ProviderClaimsPage } from './ProviderClaimsPage';
import { ProvidersPage } from './ProvidersPage';
import { ProviderDetailsPage } from './ProviderDetailsPage';

vi.mock('./api', () => ({
  getProviderApplications: vi.fn(),
  getProviderApplication: vi.fn(),
  getProviderReviewHistory: vi.fn(),
  getProviderClaims: vi.fn(),
  approveProviderClaim: vi.fn(),
  rejectProviderClaim: vi.fn(),
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
    fieldNotes: [],
    resubmittedAt: null,
    resubmitCount: 0,
    reopenedAt: null,
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
  vi.mocked(getProviderReviewHistory).mockResolvedValue({
    providerId: 'p',
    appliedAt: ago(48),
    events: [],
  });
});

afterEach(() => {
  vi.useRealTimers();
  vi.clearAllMocks();
});

describe('a03 طلبات الانضمام', () => {
  const getStats = vi.fn().mockResolvedValue({
    pendingProviders: 12,
    resubmittedProviders: 4,
    needsChangesProviders: 6,
  });

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
    expect(getProviderApplications).toHaveBeenCalledWith({
      status: 'PENDING',
      resubmitted: false,
      page: 1,
      limit: 100,
    });
    expect(await screen.findByRole('button', { name: 'جديد 8' })).toHaveAttribute('aria-pressed', 'true');
    expect(screen.getByRole('button', { name: 'أُعيد إرسالها 4' })).toBeVisible();
    expect(screen.getByRole('button', { name: 'يحتاج تعديل 6' })).toBeVisible();
    expect(screen.getByText('الأقدم أول · نوعد المزود برد خلال يومين')).toBeVisible();
  });

  it('lists the profiles sent back after changes, waiting from when they came back (B-01, B-02)', async () => {
    vi.mocked(getProviderApplications).mockResolvedValue(paged([], 100));
    renderAt('/a', '/a', <ProviderApplicationsPage getStats={getStats} />);
    await screen.findByText('ما فيه طلبات هنا.');

    vi.mocked(getProviderApplications).mockResolvedValue(
      paged(
        [
          provider({
            id: 'back',
            businessName: 'استوديو ضوء صنعاء',
            status: 'PENDING',
            createdAt: ago(240),
            resubmittedAt: ago(49),
            resubmitCount: 1,
          }),
          provider({
            id: 'refused',
            businessName: 'كوافيرة أم ريان',
            status: 'PENDING',
            createdAt: ago(300),
            resubmittedAt: ago(2),
            resubmitCount: 2,
            reopenedAt: ago(3),
          }),
        ],
        100,
      ),
    );
    fireEvent.click(await screen.findByRole('button', { name: 'أُعيد إرسالها 4' }));

    const table = await screen.findByRole('table', { name: 'طلبات الانضمام' });
    const rows = within(table).getAllByRole('row').slice(1);
    expect(rows[0]).toHaveTextContent('استوديو ضوء صنعاء');
    expect(rows[0]).toHaveTextContent('أُعيد إرساله · كان يحتاج تعديل');
    expect(within(rows[0]).getByText('يومين')).toHaveClass('desk-ink--coral');
    expect(rows[1]).toHaveTextContent('أُعيد إرساله 2 مرات · كان مرفوض');
    expect(getProviderApplications).toHaveBeenLastCalledWith({
      status: 'PENDING',
      resubmitted: true,
      page: 1,
      limit: 100,
    });
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
    expect(screen.queryByRole('button', { name: 'يحتاج تعديل 6' })).toHaveAttribute('aria-pressed', 'true');
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
    expect(screen.getByText('ملاحظتك تظهر للمزود جنب الحقل نفسه.')).toBeVisible();
    expect(screen.getByRole('button', { name: 'اعتماد' })).toBeVisible();
    expect(screen.getByRole('button', { name: 'رفض' })).toBeVisible();
    // B-01: a note on each field the provider can fix, none on the photos.
    expect(screen.getByRole('button', { name: 'ملاحظة على باقة صور وفيديو' })).toBeVisible();
    expect(screen.queryByRole('button', { name: 'ملاحظة على صور الشغل' })).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: 'ملاحظة على باقة صور وفيديو' }));
    fireEvent.change(screen.getByLabelText('ملاحظتك على باقة صور وفيديو'), {
      target: { value: 'اكتب ايش تشمل الباقة' },
    });
    fireEvent.click(screen.getByRole('button', { name: 'ملاحظة على المناطق' }));
    fireEvent.change(screen.getByLabelText('ملاحظتك على المناطق'), {
      target: { value: 'حدد الأحياء' },
    });

    fireEvent.click(screen.getByRole('button', { name: 'اطلب تعديل' }));
    const dialog = screen.getByRole('dialog', { name: 'اطلب تعديل من استوديو ضوء صنعاء' });
    expect(dialog).toHaveTextContent('ملاحظاتك على الحقلين تظهر له جنب الحقل نفسه.');
    const send = within(dialog).getByRole('button', { name: 'أرسل الملاحظات' });
    // The field notes are enough; the general note is optional with them.
    expect(send).toBeEnabled();
    fireEvent.click(send);
    await waitFor(() =>
      expect(requestProviderChanges).toHaveBeenCalledWith('p1', {
        note: '',
        fieldNotes: [
          { field: 'SERVICE', note: 'اكتب ايش تشمل الباقة' },
          { field: 'CITY', note: 'حدد الأحياء' },
        ],
      }),
    );
  });

  it('asks for a general note when no field has one', async () => {
    vi.mocked(getProviderApplication).mockResolvedValue(
      provider({ id: 'p1', businessName: 'استوديو ضوء صنعاء', status: 'PENDING' }),
    );
    vi.mocked(requestProviderChanges).mockResolvedValue(provider({ id: 'p1', businessName: 'x' }));
    renderAt('/r/p1', '/r/:id', <ProviderApplicationDetailsPage />);
    fireEvent.click(await screen.findByRole('button', { name: 'اطلب تعديل' }));
    const dialog = screen.getByRole('dialog', { name: 'اطلب تعديل من استوديو ضوء صنعاء' });
    const send = within(dialog).getByRole('button', { name: 'أرسل الملاحظات' });
    expect(send).toBeDisabled();
    fireEvent.change(within(dialog).getByLabelText('ملاحظة عامة (توصل المزود)'), {
      target: { value: 'أضف خدمة بسعرها' },
    });
    fireEvent.click(send);
    await waitFor(() =>
      expect(requestProviderChanges).toHaveBeenCalledWith('p1', {
        note: 'أضف خدمة بسعرها',
        fieldNotes: [],
      }),
    );
  });

  it('writes the review line from the history, and lets the team rewrite its notes while the provider fixes', async () => {
    vi.mocked(getProviderApplication).mockResolvedValue(
      provider({
        id: 'p2',
        businessName: 'فرقة الأمجاد',
        status: 'NEEDS_CHANGES',
        reviewedAt: '2026-10-19T07:00:00.000Z',
        reviewedBy: { id: 'a', name: 'رشاد' } as ProviderApplication['reviewedBy'],
        fieldNotes: [{ field: 'SERVICE', note: 'حدد سعر الليلة' }],
        services: [
          {
            id: 's1',
            title: 'برع الزفة',
            description: null,
            basePrice: '400000',
            priceUnit: null,
            currency: 'YER',
            isActive: true,
            images: [],
          },
        ],
      }),
    );
    const events: ProviderReviewEvent[] = [
      {
        id: 'e1',
        kind: 'REJECTED',
        at: '2026-10-15T07:00:00.000Z',
        actor: { id: 'a', name: 'رشاد' },
        notes: [{ field: 'GENERAL', note: 'الصور منقولة' }],
      },
      { id: 'e2', kind: 'REOPENED', at: '2026-10-16T07:00:00.000Z', actor: null, notes: [] },
      {
        id: 'e3',
        kind: 'CHANGES_REQUESTED',
        at: '2026-10-19T07:00:00.000Z',
        actor: { id: 'a', name: 'رشاد' },
        notes: [
          { field: 'SERVICE', note: 'حدد سعر الليلة' },
          { field: 'BUSINESS_NAME', note: 'الاسم' },
        ],
      },
    ];
    vi.mocked(getProviderReviewHistory).mockResolvedValue({
      providerId: 'p2',
      appliedAt: ago(300),
      events,
    });
    renderAt('/r/p2', '/r/:id', <ProviderApplicationDetailsPage />);
    expect(await screen.findByText('رشاد رفض الطلب')).toBeVisible();
    expect(screen.getByText('للمزود: الصور منقولة')).toBeVisible();
    expect(screen.getByText('المزود قدّم من جديد بعد الرفض')).toBeVisible();
    expect(screen.getByText('رشاد طلب تعديل في حقلين')).toBeVisible();
    // The note he reads now sits under its field.
    expect(screen.getByText('للمزود: حدد سعر الليلة')).toBeVisible();
    expect(screen.getByRole('button', { name: 'اطلب تعديل' })).toBeVisible();
    // Opening the note starts from the current one, to rewrite it.
    fireEvent.click(screen.getByRole('button', { name: 'ملاحظة على برع الزفة' }));
    expect(screen.getByLabelText('ملاحظتك على برع الزفة')).toHaveValue('حدد سعر الليلة');
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

describe('a07 ملفات بلا حساب (B-12)', () => {
  const claim = (input: Partial<ProviderClaimRequest> & { id: string }): ProviderClaimRequest => ({
    status: 'PENDING',
    note: null,
    createdAt: ago(20),
    decidedAt: null,
    provider: {
      id: 'harah',
      businessName: 'مصور الحارة',
      phone: '+967777000506',
      whatsapp: null,
      logoUrl: null,
      status: 'ACTIVE',
      ratingAverage: '0',
      ratingCount: 0,
      city: { id: 'c', nameAr: 'صنعاء' } as ProviderClaimRequest['provider']['city'],
      primaryCategory: { id: 'k', nameAr: 'التصوير' } as ProviderClaimRequest['provider']['primaryCategory'],
    },
    claimant: { id: 'u', name: 'عبدالله الحارثي', phone: '+967777000506' },
    decidedBy: null,
    ...input,
  });

  it('lists the claims waiting for review and approves one', async () => {
    vi.mocked(getProviderClaims).mockResolvedValue({
      items: [claim({ id: 'c1' })],
      page: 1,
      limit: 50,
      total: 1,
      totalPages: 1,
    });
    vi.mocked(approveProviderClaim).mockResolvedValue(claim({ id: 'c1', status: 'APPROVED' }));
    renderAt('/l', '/l', <ProviderClaimsPage />);

    const row = (await screen.findByText('مصور الحارة')).closest('tr');
    expect(row).toHaveTextContent('عبدالله الحارثي');
    expect(row).toHaveTextContent('ينتظر المراجعة');
    expect(row).toHaveTextContent('التصوير');
    expect(screen.getByText('يستلمها صاحبها برقمه بعد ما نراجع · 1 طلب ينتظر')).toBeVisible();
    expect(getProviderClaims).toHaveBeenCalledWith({ status: 'PENDING', page: 1, limit: 50 });
    // D41: no WhatsApp claim link, and a listing takes no requests.
    expect(screen.queryByText('رابط الاستلام')).not.toBeInTheDocument();
    expect(screen.queryByText('طلبات تنتظره')).not.toBeInTheDocument();

    fireEvent.click(within(row as HTMLElement).getByRole('button', { name: 'اقبل' }));
    const dialog = screen.getByRole('dialog', { name: 'سلّم «مصور الحارة» لصاحب الطلب' });
    fireEvent.click(within(dialog).getByRole('button', { name: 'سلّمه الملف' }));
    await waitFor(() => expect(approveProviderClaim).toHaveBeenCalledWith('c1'));
  });

  it('refuses a claim only with a reason the claimant reads', async () => {
    vi.mocked(getProviderClaims).mockResolvedValue({
      items: [claim({ id: 'c2' })],
      page: 1,
      limit: 50,
      total: 1,
      totalPages: 1,
    });
    vi.mocked(rejectProviderClaim).mockResolvedValue(claim({ id: 'c2', status: 'REJECTED' }));
    renderAt('/l', '/l', <ProviderClaimsPage />);

    const row = (await screen.findByText('مصور الحارة')).closest('tr') as HTMLElement;
    fireEvent.click(within(row).getByRole('button', { name: 'ارفض' }));
    const dialog = screen.getByRole('dialog', { name: 'ما نقبل استلام «مصور الحارة»' });
    const refuse = within(dialog).getByRole('button', { name: 'ارفض' });
    expect(refuse).toBeDisabled();
    fireEvent.change(within(dialog).getByLabelText('السبب (يوصل صاحب الطلب)'), {
      target: { value: 'اتصلنا بالرقم وما رد' },
    });
    fireEvent.click(refuse);
    await waitFor(() => expect(rejectProviderClaim).toHaveBeenCalledWith('c2', 'اتصلنا بالرقم وما رد'));
  });

  it('hides the decisions from read-only roles', async () => {
    authState.adminPermissions = [AdminPermission.PROVIDERS_READ];
    vi.mocked(getProviderClaims).mockResolvedValue({
      items: [claim({ id: 'c3' })],
      page: 1,
      limit: 50,
      total: 1,
      totalPages: 1,
    });
    renderAt('/l', '/l', <ProviderClaimsPage />);
    await screen.findByText('مصور الحارة');
    expect(screen.queryByRole('button', { name: 'اقبل' })).not.toBeInTheDocument();
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
