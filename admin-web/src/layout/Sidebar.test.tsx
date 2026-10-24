import { createRef } from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { AdminPermission } from '../features/auth/api';
import { Sidebar } from './Sidebar';

const authState = vi.hoisted(() => ({
  user: {
    id: 'admin-1',
    name: 'نادية',
    adminRole: 'OPERATIONS',
    adminPermissions: [],
  } as {
    id: string;
    name: string;
    adminRole: string | null;
    adminPermissions: string[];
  } | null,
}));

const queueCounts = vi.hoisted(() => ({
  value: {} as Record<string, number | undefined>,
}));

vi.mock('../features/auth/AuthProvider', () => ({
  useAuth: () => authState,
}));

vi.mock('./useQueueCounts', () => ({
  useQueueCounts: () => queueCounts.value,
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
    queueCounts.value = {};
    authState.user = {
      id: 'admin-1',
      name: 'نادية',
      adminRole: 'OPERATIONS',
      adminPermissions: Object.values(AdminPermission),
    };
  });

  it('draws the design sections in order with only the built pages', () => {
    renderSidebar('/');

    const groups = Array.from(
      document.querySelectorAll('.desk-side__group-label'),
    ).map((node) => node.textContent);
    expect(groups).toEqual([
      'اليوم',
      'السوق',
      'المزودين',
      'الناس',
      'الرقابة',
      'النظام',
      'الفريق',
    ]);
    expect(screen.queryByText('جديد')).not.toBeInTheDocument();
    expect(screen.queryByText('1.1')).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /نظرة السوق/ })).not.toBeInTheDocument();
    expect(screen.queryByRole('link', { name: /الإشعارات/ })).not.toBeInTheDocument();
  });

  it('marks only provider applications as current on an application detail page', () => {
    renderSidebar('/providers/applications/provider-1');

    const currentLinks = screen.getAllByRole('link', { current: 'page' });
    expect(currentLinks).toHaveLength(1);
    expect(currentLinks[0]).toHaveTextContent('طلبات الانضمام');
    expect(screen.getByRole('link', { name: 'دليل المزودين' })).not.toHaveAttribute(
      'aria-current',
    );
  });

  it('marks only the provider directory as current on a provider detail page', () => {
    renderSidebar('/providers/provider-1');

    const currentLinks = screen.getAllByRole('link', { current: 'page' });
    expect(currentLinks).toHaveLength(1);
    expect(currentLinks[0]).toHaveTextContent('دليل المزودين');
  });

  it('keeps the catalog link current on every catalog page', () => {
    for (const path of ['/categories', '/reference-catalogs', '/cities', '/administrative-areas']) {
      const { unmount } = render(
        <MemoryRouter initialEntries={[path]}>
          <Sidebar
            closeButtonRef={createRef<HTMLButtonElement>()}
            isOpen={false}
            onClose={vi.fn()}
            onNavigate={vi.fn()}
            onLogout={vi.fn()}
          />
        </MemoryRouter>,
      );
      expect(screen.getByRole('link', { current: 'page' })).toHaveTextContent('الكتالوج');
      unmount();
    }
  });

  it('does not render links without the matching server permission', () => {
    authState.user = {
      id: 'admin-1',
      name: 'نادية',
      adminRole: 'SUPPORT',
      adminPermissions: [AdminPermission.DASHBOARD_READ],
    };

    renderSidebar('/');

    expect(screen.getByRole('link', { name: 'الصندوق' })).toBeVisible();
    expect(
      screen.queryByRole('link', { name: 'طلبات الانضمام' }),
    ).not.toBeInTheDocument();
    expect(screen.queryByText('المزودين')).not.toBeInTheDocument();
  });

  it('shows the queue counts the server gives, coral for the hot ones', () => {
    queueCounts.value = { inbox: 23, applications: 12, reports: undefined };
    renderSidebar('/');

    const inbox = screen.getByRole('link', { name: /الصندوق/ });
    expect(inbox).toHaveTextContent('23');
    expect(inbox.querySelector('.desk-side__count')).toHaveClass('is-hot');
    const applications = screen.getByRole('link', { name: /طلبات الانضمام/ });
    expect(applications.querySelector('.desk-side__count')).not.toHaveClass('is-hot');
    expect(
      screen.getByRole('link', { name: /البلاغات/ }).querySelector('.desk-side__count'),
    ).toBeNull();
  });

  it('shows the admin name and real role, and signs out', () => {
    const { onLogout } = renderSidebar('/');

    expect(screen.getByText('نادية')).toBeVisible();
    expect(screen.getByText('تشغيل')).toBeVisible();
    fireEvent.click(screen.getByRole('button', { name: 'تسجيل الخروج' }));
    expect(onLogout).toHaveBeenCalledTimes(1);
  });

  it('closes the drawer after navigation and through its close control', () => {
    const { onClose, onNavigate } = renderSidebar('/');

    fireEvent.click(screen.getByRole('link', { name: 'التقارير' }));
    expect(onNavigate).toHaveBeenCalledTimes(1);

    fireEvent.click(screen.getByRole('button', { name: 'إغلاق القائمة' }));
    expect(onClose).toHaveBeenCalledTimes(1);
  });
});
