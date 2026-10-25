import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
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
  // The section's name also fills its groom and bride columns (a08).
  return screen.getAllByText(name)[0].closest('tr') as HTMLElement;
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
    // a08: the active section is disabled from its edit window; a disabled
    // one shows «معطّل» with «فعّله».
    render(
      <MemoryRouter>
        <CategoriesPage />
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getAllByText('زفة')[0]).toBeInTheDocument());

    expect(within(rowOf('تصوير')).queryByRole('button', { name: 'فعّله' })).toBeNull();
    fireEvent.click(within(rowOf('تصوير')).getByRole('button', { name: 'عدّل تصوير' }));
    const editor = screen.getByRole('dialog', { name: 'تعديل تصوير' });
    expect(within(editor).getByRole('button', { name: 'عطّل القسم' })).toBeInTheDocument();
    fireEvent.click(within(editor).getByRole('button', { name: 'سكّر' }));

    const disabledRow = rowOf('زفة');
    expect(within(disabledRow).getByText('معطّل')).toBeInTheDocument();
    fireEvent.click(within(disabledRow).getByRole('button', { name: 'عدّل زفة' }));
    expect(screen.queryByRole('button', { name: 'عطّل القسم' })).toBeNull();
    fireEvent.click(screen.getByRole('button', { name: 'سكّر' }));

    fireEvent.click(within(disabledRow).getByRole('button', { name: 'فعّله' }));
    const dialog = await screen.findByRole('dialog', { name: 'تفعيل زفة' });
    fireEvent.click(within(dialog).getByRole('button', { name: 'فعّله' }));

    await waitFor(() =>
      expect(updateCategory).toHaveBeenCalledWith('disabled', {
        nameAr: 'زفة',
        isActive: true,
      }),
    );
  });

  it('offers to enable a disabled city and not to disable it again', async () => {
    // The cities page follows a08 on the desk kit (D56): an active city is
    // disabled from its edit window; a disabled one shows «فعّلها».
    render(
      <MemoryRouter>
        <CitiesPage />
      </MemoryRouter>,
    );
    await waitFor(() => expect(screen.getByText('عدن')).toBeInTheDocument());

    expect(within(rowOf('صنعاء')).queryByRole('button', { name: 'فعّلها' })).toBeNull();
    fireEvent.click(within(rowOf('صنعاء')).getByRole('button', { name: 'عدّل صنعاء' }));
    const editor = screen.getByRole('dialog', { name: 'تعديل صنعاء' });
    expect(within(editor).getByRole('button', { name: 'عطّل المدينة' })).toBeInTheDocument();
    fireEvent.click(within(editor).getByRole('button', { name: 'سكّر' }));

    const disabledRow = rowOf('عدن');
    expect(within(disabledRow).getByText('معطّلة')).toBeInTheDocument();
    fireEvent.click(within(disabledRow).getByRole('button', { name: 'عدّل عدن' }));
    expect(screen.queryByRole('button', { name: 'عطّل المدينة' })).toBeNull();
    fireEvent.click(screen.getByRole('button', { name: 'سكّر' }));

    fireEvent.click(within(disabledRow).getByRole('button', { name: 'فعّلها' }));
    const dialog = await screen.findByRole('dialog', { name: 'تفعيل عدن' });
    fireEvent.click(within(dialog).getByRole('button', { name: 'فعّلها' }));

    await waitFor(() =>
      expect(updateCity).toHaveBeenCalledWith('disabled', {
        nameAr: 'عدن',
        isActive: true,
      }),
    );
  });
});
