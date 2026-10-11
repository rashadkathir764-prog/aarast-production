import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { getStats, type AdminStats } from './api';
import {
  getProviderApplications,
  type ProviderApplication,
} from '../providers/api';
import { DashboardPage } from './DashboardPage';

vi.mock('./api', () => ({ getStats: vi.fn() }));
vi.mock('../providers/api', () => ({ getProviderApplications: vi.fn() }));

const authState = vi.hoisted(() => ({
  adminPermissions: undefined as string[] | undefined,
}));

vi.mock('../auth/AuthProvider', () => ({
  useAuth: () => ({
    user: {
      id: 'admin-1',
      name: 'مدير النظام',
      adminPermissions: authState.adminPermissions,
    },
  }),
}));

vi.mock('../../design_system/MiniDonut', () => ({
  MiniDonut: ({ value }: { value: number }) => <div>توزيع الموردين: {value}</div>,
}));

const stats: AdminStats = {
  totalUsers: 120,
  totalProviders: 24,
  pendingProviders: 2,
  approvedProviders: 16,
  rejectedProviders: 1,
  needsChangesProviders: 1,
  suspendedProviders: 4,
  totalQuoteRequests: 36,
  totalWeddingPlans: 80,
  totalCities: 8,
  totalProviderCategories: 10,
};

const pendingProvider = {
  id: 'provider-1',
  businessName: 'قاعة الندى',
  primaryCategory: { nameAr: 'قاعات أفراح' },
  status: 'PENDING',
  createdAt: '2026-08-07T10:00:00.000Z',
} as ProviderApplication;

function renderDashboard() {
  render(
    <MemoryRouter>
      <DashboardPage />
    </MemoryRouter>,
  );
}

describe('DashboardPage', () => {
  beforeEach(() => {
    authState.adminPermissions = undefined;
    vi.mocked(getStats).mockResolvedValue(stats);
    vi.mocked(getProviderApplications).mockResolvedValue({
      items: [pendingProvider],
      page: 1,
      limit: 5,
      total: 1,
      totalPages: 1,
    });
  });

  it('prioritizes pending provider work and keeps supporting metrics concise', async () => {
    renderDashboard();

    expect(screen.getByText('جارٍ تجهيز لوحة التحكم')).toBeInTheDocument();
    await waitFor(() => expect(screen.getByText('قاعة الندى')).toBeVisible());

    expect(getProviderApplications).toHaveBeenCalledWith({
      status: 'PENDING',
      limit: 5,
    });
    expect(screen.getByRole('heading', { name: /مرحباً، مدير النظام/ })).toBeVisible();
    expect(screen.getByText('طلبات الموردين التي تنتظر المراجعة')).toBeVisible();
    expect(screen.getByRole('link', { name: 'مراجعة 3 طلبات' })).toHaveAttribute(
      'href',
      '/providers/applications',
    );
    expect(screen.getByText('120')).toBeVisible();
    expect(screen.getByText('توزيع الموردين: 24')).toBeVisible();
  });

  it('shows an honest empty state when there is no pending review work', async () => {
    vi.mocked(getProviderApplications).mockResolvedValue({
      items: [],
      page: 1,
      limit: 5,
      total: 0,
      totalPages: 0,
    });

    renderDashboard();

    await waitFor(() =>
      expect(screen.getByText('قائمة المراجعة فارغة')).toBeVisible(),
    );
    expect(
      screen.getByText('ستظهر هنا الطلبات الجديدة فور وصولها.'),
    ).toBeVisible();
  });

  it('shows a retryable error without pretending that data is zero', async () => {
    vi.mocked(getStats).mockRejectedValue(new Error('تعذر الوصول للخدمة'));

    renderDashboard();

    await waitFor(() =>
      expect(screen.getByText('تعذر تحميل البيانات')).toBeVisible(),
    );
    expect(screen.getByText('تعذر الوصول للخدمة')).toBeVisible();
    expect(screen.queryByText('120')).not.toBeInTheDocument();
  });

  // F08: quick links follow the same read permission as their route guard.
  it('shows a moderator only the quick links that role can open', async () => {
    authState.adminPermissions = [
      'DASHBOARD_READ',
      'PROVIDERS_READ',
      'REVIEWS_READ',
      'REVIEWS_WRITE',
      'CONVERSATION_REPORTS_READ',
      'CONVERSATION_REPORTS_WRITE',
      'NOTIFICATIONS_READ',
      'NOTIFICATIONS_WRITE',
    ];

    renderDashboard();
    await waitFor(() => expect(screen.getByText('قاعة الندى')).toBeVisible());

    for (const name of ['دليل الموردين', 'مراقبة التقييمات', 'إشعارات الحساب']) {
      expect(screen.getByRole('link', { name })).toBeVisible();
    }
    for (const name of [
      'فئات الموردين',
      'المدن والمناطق',
      'الخدمات',
      'التقارير التشغيلية',
    ]) {
      expect(screen.queryByRole('link', { name })).not.toBeInTheDocument();
    }
  });

  it('shows support only the quick links that role can open', async () => {
    authState.adminPermissions = [
      'DASHBOARD_READ',
      'USERS_READ',
      'PROVIDERS_READ',
      'SERVICES_READ',
      'CATALOG_READ',
      'NOTIFICATIONS_READ',
    ];

    renderDashboard();
    await waitFor(() => expect(screen.getByText('قاعة الندى')).toBeVisible());

    for (const name of ['فئات الموردين', 'المدن والمناطق', 'الخدمات']) {
      expect(screen.getByRole('link', { name })).toBeVisible();
    }
    for (const name of ['مراقبة التقييمات', 'التقارير التشغيلية']) {
      expect(screen.queryByRole('link', { name })).not.toBeInTheDocument();
    }
  });
});
