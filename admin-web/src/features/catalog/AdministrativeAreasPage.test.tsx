import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  disableLocality,
  getDistricts,
  getGovernorates,
  getLocalities,
  type AdministrativeLocality,
  type District,
  type Governorate,
} from './api';
import { AdministrativeAreasPage } from './AdministrativeAreasPage';

vi.mock('./api', () => ({
  getGovernorates: vi.fn(),
  getDistricts: vi.fn(),
  getLocalities: vi.fn(),
  createGovernorate: vi.fn(),
  createDistrict: vi.fn(),
  createLocality: vi.fn(),
  updateGovernorate: vi.fn(),
  updateDistrict: vi.fn(),
  updateLocality: vi.fn(),
  disableGovernorate: vi.fn(),
  disableDistrict: vi.fn(),
  disableLocality: vi.fn(),
}));
const authState = vi.hoisted(() => ({
  user: { id: 'admin-1', name: 'نادية', adminPermissions: ['CATALOG_READ', 'CATALOG_WRITE'] },
}));
vi.mock('../auth/AuthProvider', () => ({ useAuth: () => authState }));

const sanaa = { id: 'g1', code: 'SAN', nameAr: 'أمانة العاصمة', nameEn: 'Sanaa', isActive: true, sortOrder: 0 } as Governorate;
const tahrir = { id: 'd1', code: 'TAH', nameAr: 'التحرير', nameEn: 'Tahrir', isActive: true, sortOrder: 0 } as District;
const hadda = {
  id: 'l1',
  code: 'HAD',
  nameAr: 'حدة',
  nameEn: null,
  type: 'NEIGHBORHOOD',
  parentId: null,
  isActive: true,
  sortOrder: 0,
} as AdministrativeLocality;

function renderPage() {
  render(
    <MemoryRouter>
      <AdministrativeAreasPage />
    </MemoryRouter>,
  );
}

beforeEach(() => {
  authState.user.adminPermissions = ['CATALOG_READ', 'CATALOG_WRITE'];
  vi.mocked(getGovernorates).mockResolvedValue([sanaa]);
  vi.mocked(getDistricts).mockResolvedValue([tahrir]);
  vi.mocked(getLocalities).mockResolvedValue([hadda]);
});

afterEach(() => vi.clearAllMocks());

describe('AdministrativeAreasPage', () => {
  it('reads a governorate, its district and the district areas, with the catalog links', async () => {
    renderPage();
    const row = (await screen.findByRole('button', { name: 'عدّل حدة' })).closest('tr') as HTMLElement;
    expect(within(row).getByText('حي')).toBeVisible();
    expect(within(row).getByText('المديرية نفسها')).toBeVisible();
    expect(screen.getByLabelText('المحافظة')).toHaveValue('g1');
    expect(screen.getByLabelText('المديرية')).toHaveValue('d1');
    expect(screen.getByRole('navigation', { name: 'صفحات الكتالوج' })).toBeVisible();
  });

  it('stops an area from its edit window after saying what that does', async () => {
    vi.mocked(disableLocality).mockResolvedValue({ ...hadda, isActive: false });
    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: 'عدّل حدة' }));
    const editor = screen.getByRole('dialog', { name: 'تعديل حدة' });
    fireEvent.click(within(editor).getByRole('button', { name: 'أوقف' }));
    const confirm = await screen.findByRole('dialog', { name: 'إيقاف حدة' });
    fireEvent.click(within(confirm).getByRole('button', { name: 'أوقفها' }));
    await waitFor(() => expect(disableLocality).toHaveBeenCalledWith('l1'));
  });

  it('shows a read-only role the areas without any change', async () => {
    authState.user.adminPermissions = ['CATALOG_READ'];
    renderPage();
    expect(await screen.findByText('حدة')).toBeVisible();
    expect(screen.queryByRole('button', { name: /عدّل|جديدة/ })).not.toBeInTheDocument();
  });
});
