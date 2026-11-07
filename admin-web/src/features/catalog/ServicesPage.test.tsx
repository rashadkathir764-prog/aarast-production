import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  createService,
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

  // RA-AD-16: the server takes a price as Latin digits with at most two
  // decimals. A price typed on an Arabic keyboard, or with its thousands
  // marked, used to come back as «راجع البيانات المدخلة» with no word on what.
  it('sends a price typed in Arabic digits or with commas as the server reads it', async () => {
    vi.mocked(getCategories).mockResolvedValue([
      { id: 'cat-1', nameAr: 'القاعات', isActive: true } as Awaited<ReturnType<typeof getCategories>>[number],
    ]);
    vi.mocked(getProviders).mockResolvedValue({
      items: [{ id: 'hall', businessName: 'قاعة السعادة' } as never],
      page: 1,
      limit: 20,
      total: 1,
      totalPages: 1,
    });
    vi.mocked(createService).mockResolvedValue(service);
    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: 'أضف خدمة لمزود' }));
    const dialog = await screen.findByRole('dialog', { name: 'أضف خدمة لمزود' });
    fireEvent.change(within(dialog).getByLabelText('المزود'), { target: { value: 'السعادة' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'ابحث' }));
    fireEvent.click(await within(dialog).findByRole('button', { name: 'قاعة السعادة' }));
    fireEvent.change(within(dialog).getByLabelText('القسم'), { target: { value: 'cat-1' } });
    fireEvent.change(within(dialog).getByLabelText('اسم الخدمة'), { target: { value: 'حجز القاعة' } });
    const price = within(dialog).getByLabelText('السعر (اختياري)');
    const add = within(dialog).getByRole('button', { name: 'أضف الخدمة' });

    fireEvent.change(price, { target: { value: 'ثلاثمية' } });
    expect(within(dialog).getByText('السعر أرقام فقط، وبعد الفاصلة خانتين بالكثير.')).toBeVisible();
    expect(add).toBeDisabled();

    fireEvent.change(price, { target: { value: '١٥٠٬٠٠٠٫٥' } });
    expect(add).toBeEnabled();
    fireEvent.click(add);
    await waitFor(() =>
      expect(createService).toHaveBeenCalledWith(expect.objectContaining({ basePrice: '150000.5' })),
    );

    vi.mocked(createService).mockClear();
    fireEvent.click(await screen.findByRole('button', { name: 'أضف خدمة لمزود' }));
    const again = await screen.findByRole('dialog', { name: 'أضف خدمة لمزود' });
    fireEvent.change(within(again).getByLabelText('المزود'), { target: { value: 'السعادة' } });
    fireEvent.click(within(again).getByRole('button', { name: 'ابحث' }));
    fireEvent.click(await within(again).findByRole('button', { name: 'قاعة السعادة' }));
    fireEvent.change(within(again).getByLabelText('القسم'), { target: { value: 'cat-1' } });
    fireEvent.change(within(again).getByLabelText('اسم الخدمة'), { target: { value: 'حجز القاعة' } });
    fireEvent.change(within(again).getByLabelText('السعر (اختياري)'), { target: { value: '300,000' } });
    fireEvent.click(within(again).getByRole('button', { name: 'أضف الخدمة' }));
    await waitFor(() =>
      expect(createService).toHaveBeenCalledWith(expect.objectContaining({ basePrice: '300000' })),
    );
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
