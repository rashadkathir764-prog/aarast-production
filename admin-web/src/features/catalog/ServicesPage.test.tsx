import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  getCategories,
  getCities,
  getServices,
  updateService,
  type ProviderService,
} from './api';
import { getProviders } from '../providers/api';
import { ServicesPage } from './ServicesPage';

vi.mock('./api', () => ({
  getServices: vi.fn(),
  getCities: vi.fn(),
  getCategories: vi.fn(),
  createService: vi.fn(),
  updateService: vi.fn(),
}));
vi.mock('../providers/api', () => ({ getProviders: vi.fn() }));
const authState = vi.hoisted(() => ({
  user: { id: 'admin-1', name: 'نادية', adminPermissions: ['SERVICES_READ', 'SERVICES_WRITE'] },
}));
vi.mock('../auth/AuthProvider', () => ({ useAuth: () => authState }));

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

function renderPage() {
  render(
    <MemoryRouter>
      <ServicesPage />
    </MemoryRouter>,
  );
}

beforeEach(() => {
  authState.user.adminPermissions = ['SERVICES_READ', 'SERVICES_WRITE'];
  vi.mocked(getServices).mockResolvedValue({ items: [service], page: 1, limit: 20, total: 1, totalPages: 1 });
  vi.mocked(getProviders).mockResolvedValue({ items: [], page: 1, limit: 20, total: 0, totalPages: 1 });
  vi.mocked(getCities).mockResolvedValue([]);
  vi.mocked(getCategories).mockResolvedValue([]);
});

afterEach(() => vi.clearAllMocks());

describe('services', () => {
  it('has no service «تمييز»: featuring is the provider placement on a17 only (B-43)', async () => {
    renderPage();
    expect(await screen.findByText('حجز القاعة')).toBeVisible();
    expect(screen.getByRole('button', { name: 'أوقفها' })).toBeVisible();
    expect(screen.queryByRole('button', { name: 'تمييز' })).not.toBeInTheDocument();
    expect(screen.queryByRole('option', { name: 'مميزة' })).not.toBeInTheDocument();
    expect(screen.queryByText('مميزة في الصفحة')).not.toBeInTheDocument();
  });

  it('stops a service only after saying what that does', async () => {
    vi.mocked(updateService).mockResolvedValue({ ...service, isActive: false });
    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: 'أوقفها' }));
    const dialog = await screen.findByRole('dialog', { name: 'إيقاف «حجز القاعة»' });
    expect(dialog).toHaveTextContent('المزود نفسه ما يظهر للعرسان');
    expect(updateService).not.toHaveBeenCalled();
    fireEvent.click(within(dialog).getByRole('button', { name: 'أوقفها' }));
    await waitFor(() => expect(updateService).toHaveBeenCalledWith('service-1', { isActive: false }));
    await waitFor(() => expect(getServices).toHaveBeenCalledTimes(2));
  });

  it('shows a read-only role the services without changing them', async () => {
    authState.user.adminPermissions = ['SERVICES_READ'];
    renderPage();
    expect(await screen.findByText('حجز القاعة')).toBeVisible();
    expect(screen.queryByRole('button', { name: 'أوقفها' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'أضف خدمة لمزود' })).not.toBeInTheDocument();
  });

  it('says in Arabic when the list cannot load and tries again', async () => {
    vi.mocked(getServices)
      .mockRejectedValueOnce(new Error('تعذر الاتصال بالخادم. تأكد من الإنترنت ثم حاول مرة ثانية.'))
      .mockResolvedValueOnce({ items: [], page: 1, limit: 20, total: 0, totalPages: 1 });
    renderPage();
    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent('تعذر الاتصال بالخادم');
    fireEvent.click(within(alert).getByRole('button', { name: 'حاول مرة ثانية' }));
    expect(await screen.findByText('ما فيه خدمات بعد.')).toBeVisible();
  });
});
