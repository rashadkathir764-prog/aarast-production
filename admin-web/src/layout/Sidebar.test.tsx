import { createRef } from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { AdminPermission } from '../features/auth/api';
import { Sidebar } from './Sidebar';

const authState = vi.hoisted(() => ({
  user: {
    id: 'admin-1',
    name: 'مدير النظام',
    adminPermissions: [],
  } as {
    id: string;
    name: string;
    adminPermissions: string[];
  } | null,
}));

vi.mock('../features/auth/AuthProvider', () => ({
  useAuth: () => authState,
}));

function renderSidebar(pathname = '/') {
  const onClose = vi.fn();
  const onNavigate = vi.fn();
  const onLogout = vi.fn();

  render(
    <MemoryRouter initialEntries={[pathname]}>
      <Sidebar
        closeButtonRef={createRef<HTMLButtonElement>()}
        isOpen={false}
        onClose={onClose}
        onNavigate={onNavigate}
        onLogout={onLogout}
      />
    </MemoryRouter>,
  );

  return { onClose, onNavigate, onLogout };
}

describe('Sidebar', () => {
  beforeEach(() => {
    authState.user = {
      id: 'admin-1',
      name: 'مدير النظام',
      adminPermissions: Object.values(AdminPermission),
    };
  });

  it('marks only provider applications as current on an application detail page', () => {
    renderSidebar('/providers/applications/provider-1');

    const currentLinks = screen.getAllByRole('link', { current: 'page' });
    expect(currentLinks).toHaveLength(1);
    expect(currentLinks[0]).toHaveTextContent('طلبات الموردين');
    expect(screen.getByRole('link', { name: 'الموردون' })).not.toHaveAttribute(
      'aria-current',
    );
  });

  it('marks only the provider directory as current on a provider detail page', () => {
    renderSidebar('/providers/provider-1');

    const currentLinks = screen.getAllByRole('link', { current: 'page' });
    expect(currentLinks).toHaveLength(1);
    expect(currentLinks[0]).toHaveTextContent('الموردون');
  });

  it('does not render links without the matching server permission', () => {
    authState.user = {
      id: 'admin-1',
      name: 'مدير النظام',
      adminPermissions: [AdminPermission.DASHBOARD_READ],
    };

    renderSidebar('/');

    expect(screen.getByRole('link', { name: 'لوحة التحكم' })).toBeVisible();
    expect(
      screen.queryByRole('link', { name: 'طلبات الموردين' }),
    ).not.toBeInTheDocument();
    expect(screen.queryByText('السوق والكتالوج')).not.toBeInTheDocument();
  });

  it('closes the drawer after navigation and through its close control', () => {
    const { onClose, onNavigate } = renderSidebar('/');

    fireEvent.click(screen.getByRole('link', { name: 'التقارير' }));
    expect(onNavigate).toHaveBeenCalledTimes(1);

    fireEvent.click(screen.getByRole('button', { name: 'إغلاق القائمة' }));
    expect(onClose).toHaveBeenCalledTimes(1);
  });
});
