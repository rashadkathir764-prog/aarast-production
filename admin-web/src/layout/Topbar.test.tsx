import { createRef } from 'react';
import { render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';
import { Topbar } from './Topbar';

vi.mock('../features/auth/AuthProvider', () => ({
  useAuth: () => ({
    user: {
      id: 'admin-1',
      name: 'مدير النظام',
    },
  }),
}));

function renderTopbar(pathname: string, isMenuOpen = false) {
  render(
    <MemoryRouter initialEntries={[pathname]}>
      <Topbar
        isMenuOpen={isMenuOpen}
        menuButtonRef={createRef<HTMLButtonElement>()}
        onMenuClick={vi.fn()}
      />
    </MemoryRouter>,
  );
}

describe('Topbar', () => {
  it('shows a readable location for a list page', () => {
    renderTopbar('/providers/applications');

    expect(screen.getByRole('navigation', { name: 'مسار الصفحة' })).toHaveTextContent(
      'لوحة الإدارة / السوق والكتالوج',
    );
    expect(screen.getByText('طلبات الموردين')).toHaveAttribute(
      'aria-current',
      'page',
    );
  });

  it('links back to the list from a provider application detail page', () => {
    renderTopbar('/providers/applications/provider-1');

    expect(
      screen.getByRole('link', { name: 'طلبات الموردين' }),
    ).toHaveAttribute('href', '/providers/applications');
    expect(screen.getByText('تفاصيل طلب مورد')).toHaveAttribute(
      'aria-current',
      'page',
    );
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
