import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { getCategories, getCities, getServices, type ProviderService } from './api';
import { getProviders } from '../providers/api';
import { AdminPermission } from '../auth/api';
import { ServicesPage } from './ServicesPage';

vi.mock('./api', () => ({
  getServices: vi.fn(),
  getCities: vi.fn(),
  getCategories: vi.fn(),
  createService: vi.fn(),
  updateService: vi.fn(),
}));
vi.mock('../providers/api', () => ({ getProviders: vi.fn() }));
vi.mock('../auth/AuthProvider', () => ({
  useAuth: () => ({
    user: { id: 'admin-1', name: 'نادية', adminPermissions: [AdminPermission.SERVICES_READ, AdminPermission.SERVICES_WRITE] },
  }),
}));

const service: ProviderService = {
  id: 'service-1',
  providerId: 'hall',
  title: 'حجز القاعة',
  description: null,
  basePrice: '300000',
  priceUnit: null,
  currency: 'YER',
  isActive: true,
};

afterEach(() => vi.clearAllMocks());

describe('services', () => {
  it('has no service «تمييز»: featuring is the provider placement on a17 only (B-43)', async () => {
    vi.mocked(getServices).mockResolvedValue({ items: [service], page: 1, limit: 20, total: 1, totalPages: 1 });
    vi.mocked(getProviders).mockResolvedValue({ items: [], page: 1, limit: 20, total: 0, totalPages: 1 });
    vi.mocked(getCities).mockResolvedValue([]);
    vi.mocked(getCategories).mockResolvedValue([]);
    render(
      <MemoryRouter>
        <ServicesPage />
      </MemoryRouter>,
    );
    expect(await screen.findByText('حجز القاعة')).toBeVisible();
    expect(screen.getByRole('button', { name: 'إيقاف' })).toBeVisible();
    expect(screen.queryByRole('button', { name: 'تمييز' })).not.toBeInTheDocument();
    expect(screen.queryByRole('option', { name: 'مميزة' })).not.toBeInTheDocument();
    expect(screen.queryByText('مميزة في الصفحة')).not.toBeInTheDocument();
  });
});
