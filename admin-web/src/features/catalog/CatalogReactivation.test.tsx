import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  getCategories,
  getCities,
  updateCategory,
  updateCity,
  type City,
  type ProviderCategory,
} from './api';
import { CategoriesPage } from './CategoriesPage';
import { CitiesPage } from './CitiesPage';

vi.mock('./api', () => ({
  getCategories: vi.fn(),
  createCategory: vi.fn(),
  updateCategory: vi.fn(),
  deleteCategory: vi.fn(),
  getCities: vi.fn(),
  createCity: vi.fn(),
  updateCity: vi.fn(),
  deleteCity: vi.fn(),
}));

vi.mock('../auth/AuthProvider', () => ({
  useAuth: () => ({
    user: { id: 'admin-1', name: 'مدير', adminPermissions: ['CATALOG_WRITE'] },
  }),
}));

const category = (id: string, isActive: boolean): ProviderCategory => ({
  id,
  nameAr: isActive ? 'تصوير' : 'زفة',
  nameEn: null,
  slug: id,
  icon: null,
  showForGroom: true,
  showForBride: true,
  isActive,
  sortOrder: 0,
});

const city = (id: string, isActive: boolean): City => ({
  id,
  nameAr: isActive ? 'صنعاء' : 'عدن',
  nameEn: null,
  countryCode: 'YE',
  isActive,
  sortOrder: 0,
});

function rowOf(name: string) {
  return screen.getByText(name).closest('tr') as HTMLElement;
}

describe('catalog reactivation', () => {
  beforeEach(() => {
    vi.mocked(getCategories).mockResolvedValue([
      category('active', true),
      category('disabled', false),
    ]);
    vi.mocked(getCities).mockResolvedValue([city('active', true), city('disabled', false)]);
    vi.mocked(updateCategory).mockResolvedValue(category('disabled', true));
    vi.mocked(updateCity).mockResolvedValue(city('disabled', true));
  });

  it('offers to enable a disabled category and not to disable it again', async () => {
    render(<CategoriesPage />);
    await waitFor(() => expect(screen.getByText('زفة')).toBeInTheDocument());

    expect(within(rowOf('تصوير')).getByRole('button', { name: 'تعطيل' })).toBeInTheDocument();
    expect(within(rowOf('تصوير')).queryByRole('button', { name: 'تفعيل' })).toBeNull();
    const disabledRow = rowOf('زفة');
    expect(within(disabledRow).queryByRole('button', { name: 'تعطيل' })).toBeNull();

    fireEvent.click(within(disabledRow).getByRole('button', { name: 'تفعيل' }));
    const dialog = await screen.findByRole('dialog');
    fireEvent.click(within(dialog).getByRole('button', { name: 'تفعيل' }));

    await waitFor(() =>
      expect(updateCategory).toHaveBeenCalledWith('disabled', {
        nameAr: 'زفة',
        isActive: true,
      }),
    );
  });

  it('offers to enable a disabled city', async () => {
    render(<CitiesPage />);
    await waitFor(() => expect(screen.getByText('عدن')).toBeInTheDocument());

    const disabledRow = rowOf('عدن');
    expect(within(disabledRow).queryByRole('button', { name: 'تعطيل' })).toBeNull();
    fireEvent.click(within(disabledRow).getByRole('button', { name: 'تفعيل' }));
    const dialog = await screen.findByRole('dialog');
    fireEvent.click(within(dialog).getByRole('button', { name: 'تفعيل' }));

    await waitFor(() =>
      expect(updateCity).toHaveBeenCalledWith('disabled', {
        nameAr: 'عدن',
        isActive: true,
      }),
    );
  });
});
