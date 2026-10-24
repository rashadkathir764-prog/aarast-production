import { createRef } from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter, Route, Routes, useLocation } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';
import { AdminPermission } from '../features/auth/api';
import { Topbar } from './Topbar';

const authState = vi.hoisted(() => ({
  user: {
    id: 'admin-1',
    name: 'نادية',
    adminPermissions: [] as string[],
  },
}));

vi.mock('../features/auth/AuthProvider', () => ({
  useAuth: () => authState,
}));

function Where() {
  const location = useLocation();
  return <output data-testid="where">{`${location.pathname}${location.search}`}</output>;
}

function renderTopbar(pathname: string, isMenuOpen = false) {
  render(
    <MemoryRouter initialEntries={[pathname]}>
      <Topbar
        isMenuOpen={isMenuOpen}
        menuButtonRef={createRef<HTMLButtonElement>()}
        onMenuClick={vi.fn()}
      />
      <Routes>
        <Route path="*" element={<Where />} />
      </Routes>
    </MemoryRouter>,
  );
}

describe('Topbar', () => {
  it('shows the section as drawn for a list page', () => {
    renderTopbar('/providers/applications');

    expect(screen.getByRole('navigation', { name: 'مسار الصفحة' })).toHaveTextContent(
      'لوحة الإدارة / المزودين',
    );
  });

  it('links back to the list from a provider application detail page', () => {
    renderTopbar('/providers/applications/provider-1');

    expect(screen.getByRole('navigation', { name: 'مسار الصفحة' })).toHaveTextContent(
      'لوحة الإدارة / المزودين / تفاصيل طلب',
    );
    expect(screen.getByRole('link', { name: 'المزودين' })).toHaveAttribute(
      'href',
      '/providers/applications',
    );
    expect(screen.getByText('تفاصيل طلب')).toHaveAttribute('aria-current', 'page');
  });

  it('writes the catalog under the system section', () => {
    renderTopbar('/reference-catalogs');

    expect(screen.getByRole('navigation', { name: 'مسار الصفحة' })).toHaveTextContent(
      'لوحة الإدارة / النظام / الكتالوج',
    );
  });

  it('searches the users by name or number', () => {
    authState.user.adminPermissions = [AdminPermission.USERS_READ];
    renderTopbar('/');

    const box = screen.getByRole('searchbox', { name: 'ابحث برقم أو اسم' });
    fireEvent.change(box, { target: { value: '777 123' } });
    fireEvent.submit(box);
    expect(screen.getByTestId('where')).toHaveTextContent('/users?search=777%20123');
  });

  it('hides the search from roles that cannot read users', () => {
    authState.user.adminPermissions = [];
    renderTopbar('/');

    expect(screen.queryByRole('search')).not.toBeInTheDocument();
  });

  it('exposes the mobile drawer state to assistive technology', () => {
    renderTopbar('/users/user-1', true);

    expect(screen.getByRole('button', { name: 'إغلاق القائمة' })).toHaveAttribute(
      'aria-controls',
      'admin-navigation-drawer',
    );
    expect(screen.getByRole('button', { name: 'إغلاق القائمة' })).toHaveAttribute(
      'aria-expanded',
      'true',
    );
    expect(screen.getByText('تفاصيل مستخدم')).toHaveAttribute(
      'aria-current',
      'page',
    );
  });
});
