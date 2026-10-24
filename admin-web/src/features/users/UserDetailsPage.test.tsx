import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { activateUser, disableUser, getUser, type AdminUserRecord } from './api';
import { AdminPermission } from '../auth/api';
import { UserDetailsPage } from './UserDetailsPage';

vi.mock('./api', () => ({
  getUser: vi.fn(),
  disableUser: vi.fn(),
  activateUser: vi.fn(),
}));

const authState = vi.hoisted(() => ({
  user: { id: 'admin-1', name: 'نادية', adminRole: 'OPERATIONS', adminPermissions: [] as string[] },
}));
vi.mock('../auth/AuthProvider', () => ({ useAuth: () => authState }));

function account(input: Partial<AdminUserRecord> = {}): AdminUserRecord {
  return {
    id: 'user-1',
    name: 'محمد الحمدي',
    phone: '777123456',
    email: null,
    role: 'USER',
    adminRole: null,
    adminPermissions: [],
    status: 'ACTIVE',
    createdAt: '2026-10-02T08:00:00.000Z',
    ...input,
  };
}

function renderUser() {
  render(
    <MemoryRouter initialEntries={['/users/user-1']}>
      <Routes>
        <Route path="/users/:id" element={<UserDetailsPage />} />
      </Routes>
    </MemoryRouter>,
  );
}

beforeEach(() => {
  vi.useFakeTimers({ toFake: ['Date'] });
  vi.setSystemTime(new Date('2026-10-24T08:00:00.000Z'));
  authState.user.adminRole = 'OPERATIONS';
  authState.user.adminPermissions = [AdminPermission.USERS_READ, AdminPermission.USERS_WRITE];
});

afterEach(() => {
  vi.useRealTimers();
  vi.clearAllMocks();
});

describe('UserDetailsPage (a13)', () => {
  it('confirms what disabling does before it does it', async () => {
    vi.mocked(getUser).mockResolvedValue(account());
    vi.mocked(disableUser).mockResolvedValue(account({ status: 'DISABLED' }));
    renderUser();

    expect(await screen.findByRole('heading', { name: 'محمد الحمدي' })).toBeVisible();
    expect(screen.getByText('777 123 456')).toBeVisible();
    expect(screen.getByText(/من 2 أكتوبر/)).toBeVisible();

    fireEvent.click(screen.getByRole('button', { name: 'تعطيل الحساب' }));
    expect(disableUser).not.toHaveBeenCalled();
    const dialog = screen.getByRole('dialog', { name: 'تعطيل حساب محمد الحمدي' });
    expect(within(dialog).getAllByRole('listitem').map((item) => item.textContent)).toEqual([
      'يطلع من كل أجهزته الآن.',
      'الدعوات اللي أرسلها للمشاركين تنلغي.',
      'خطته تبقى، والمشاركين معه يكملون.',
      'ما تقدر تشوف مال خطته ولا ضيوفه.',
    ]);
    fireEvent.click(within(dialog).getByRole('button', { name: 'عطّل' }));
    await waitFor(() => expect(disableUser).toHaveBeenCalledWith('user-1'));
  });

  it('turns a disabled account back on after asking', async () => {
    vi.mocked(getUser).mockResolvedValue(account({ status: 'DISABLED' }));
    vi.mocked(activateUser).mockResolvedValue(account());
    renderUser();

    fireEvent.click(await screen.findByRole('button', { name: 'تفعيل الحساب' }));
    fireEvent.click(within(screen.getByRole('dialog')).getByRole('button', { name: 'فعّل' }));
    await waitFor(() => expect(activateUser).toHaveBeenCalledWith('user-1'));
  });

  it('offers no status change on an admin account to a delegated admin, nor without write', async () => {
    vi.mocked(getUser).mockResolvedValue(account({ role: 'ADMIN' }));
    renderUser();
    await screen.findByRole('heading', { name: 'محمد الحمدي' });
    expect(screen.queryByRole('button', { name: 'تعطيل الحساب' })).not.toBeInTheDocument();
  });

  it('lets a super admin change another admin but never their own account', async () => {
    authState.user.adminRole = 'SUPER_ADMIN';
    vi.mocked(getUser).mockResolvedValue(account({ role: 'ADMIN' }));
    renderUser();
    expect(await screen.findByRole('button', { name: 'تعطيل الحساب' })).toBeVisible();
  });

  it('hides the button from read-only roles', async () => {
    authState.user.adminPermissions = [AdminPermission.USERS_READ];
    vi.mocked(getUser).mockResolvedValue(account());
    renderUser();
    await screen.findByRole('heading', { name: 'محمد الحمدي' });
    expect(screen.queryByRole('button', { name: 'تعطيل الحساب' })).not.toBeInTheDocument();
  });
});
