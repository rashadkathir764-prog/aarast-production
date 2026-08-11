import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';
import { AdminPermission } from '../auth/adminPermissions';
import { AdminLayout } from './AdminLayout';

vi.mock('../auth/AuthProvider', () => ({
  useAuth: () => ({
    user: {
      id: 'admin-1',
      name: 'مدير النظام',
      adminPermissions: Object.values(AdminPermission),
    },
    logout: vi.fn().mockResolvedValue(undefined),
  }),
}));

function renderLayout() {
  render(
    <MemoryRouter initialEntries={['/']}>
      <Routes>
        <Route path="/" element={<AdminLayout />}>
          <Route index element={<div>محتوى الصفحة</div>} />
        </Route>
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
