import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { AdminPermission } from '../features/auth/api';
import { AdminLayout } from './AdminLayout';

const authState = vi.hoisted(() => ({
  user: {
    id: 'admin-1',
    name: 'مدير النظام',
    adminPermissions: [] as string[],
  },
  logout: vi.fn<() => Promise<void>>(),
}));

vi.mock('../features/auth/AuthProvider', () => ({
  useAuth: () => authState,
}));

vi.mock('./useQueueCounts', () => ({
  useQueueCounts: () => ({}),
}));

beforeEach(() => {
  authState.user.adminPermissions = Object.values(AdminPermission);
  authState.logout.mockReset();
  authState.logout.mockResolvedValue(undefined);
});

function renderLayout() {
  render(
    <MemoryRouter initialEntries={['/']}>
      <Routes>
        <Route path="/" element={<AdminLayout />}>
          <Route index element={<div>محتوى الصفحة</div>} />
        </Route>
        <Route path="/login" element={<p>صفحة الدخول</p>} />
      </Routes>
    </MemoryRouter>,
  );
}

describe('AdminLayout mobile drawer behavior', () => {
  it('moves focus into the drawer and restores it after Escape', async () => {
    renderLayout();

    const menuButton = screen.getByRole('button', { name: 'فتح القائمة' });
    fireEvent.click(menuButton);

    const drawerCloseButton = within(
      screen.getByRole('complementary', { name: 'التنقل الرئيسي' }),
    ).getByRole('button', { name: 'إغلاق القائمة' });
    await waitFor(() =>
      expect(drawerCloseButton).toHaveFocus(),
    );
    expect(menuButton).toHaveAttribute('aria-expanded', 'true');
    expect(document.querySelector('main')).toHaveAttribute('inert');

    fireEvent.keyDown(window, { key: 'Escape' });

    await waitFor(() =>
      expect(screen.getByRole('button', { name: 'فتح القائمة' })).toHaveFocus(),
    );
    expect(screen.getByRole('button', { name: 'فتح القائمة' })).toHaveAttribute(
      'aria-expanded',
      'false',
    );
    expect(document.querySelector('main')).not.toHaveAttribute('inert');
  });
});

describe('AdminLayout logout', () => {
  // RA-AD-06: a logout that did not go through leaves the session open on
  // this browser; the panel stays and says so, with a way to try again.
  it('stays and says the session is still open when the logout fails', async () => {
    authState.logout.mockRejectedValueOnce(
      new Error('تعذر الاتصال بالخادم. تأكد من الإنترنت ثم حاول مرة ثانية.'),
    );
    renderLayout();
    fireEvent.click(screen.getByRole('button', { name: 'تسجيل الخروج' }));

    expect(await screen.findByRole('alert')).toHaveTextContent(
      'ما سجّلنا خروجك، والجلسة ما زالت مفتوحة على هذا المتصفح.',
    );
    expect(screen.getByText('محتوى الصفحة')).toBeInTheDocument();
    expect(screen.queryByText('صفحة الدخول')).not.toBeInTheDocument();

    authState.logout.mockResolvedValueOnce();
    fireEvent.click(screen.getByRole('button', { name: 'حاول مرة ثانية' }));
    expect(await screen.findByText('صفحة الدخول')).toBeInTheDocument();
  });

  it('goes to the login page once the logout went through', async () => {
    renderLayout();
    fireEvent.click(screen.getByRole('button', { name: 'تسجيل الخروج' }));
    expect(await screen.findByText('صفحة الدخول')).toBeInTheDocument();
  });
});
