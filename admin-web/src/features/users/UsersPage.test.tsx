import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { getUsers, type AdminUserRecord } from './api';
import { UsersPage } from './UsersPage';

vi.mock('./api', () => ({ getUsers: vi.fn() }));

function account(input: Partial<AdminUserRecord> = {}): AdminUserRecord {
  return {
    id: 'user-1',
    name: 'محمد الحمدي',
    phone: '+967777000101',
    email: null,
    role: 'USER',
    adminRole: null,
    adminPermissions: [],
    status: 'ACTIVE',
    createdAt: '2026-10-02T08:00:00.000Z',
    ...input,
  };
}

function renderAt(path: string) {
  render(
    <MemoryRouter initialEntries={[path]}>
      <Routes>
        <Route path="/users" element={<UsersPage />} />
        <Route path="/users/:id" element={<p>صفحة الحساب</p>} />
      </Routes>
    </MemoryRouter>,
  );
}

beforeEach(() => {
  vi.mocked(getUsers).mockResolvedValue({
    items: [
      account(),
      account({
        id: 'user-2',
        name: 'علي الشامي',
        phone: '+967777000201',
        role: 'PROVIDER',
        status: 'DISABLED',
        provider: { id: 'p-1', businessName: 'استوديو ضوء صنعاء', status: 'ACTIVE' },
      }),
    ],
    page: 1,
    limit: 20,
    total: 2,
    totalPages: 1,
  });
});

afterEach(() => vi.clearAllMocks());

describe('UsersPage', () => {
  it('lists the accounts on the desk and changes none of them', async () => {
    renderAt('/users');
    const row = (await screen.findByText('علي الشامي')).closest('tr') as HTMLElement;
    expect(within(row).getByText('مزود')).toBeVisible();
    expect(within(row).getByText('استوديو ضوء صنعاء')).toBeVisible();
    expect(within(row).getByText('معطّل')).toBeVisible();
    expect(screen.getByText('777 000 101')).toBeVisible();
    // Disabling and enabling live on a13 with what they do (D56).
    expect(screen.queryByRole('button', { name: /تعطيل|تفعيل/ })).not.toBeInTheDocument();
  });

  it('opens a13 from a row', async () => {
    renderAt('/users');
    fireEvent.click(await screen.findByRole('row', { name: 'افتح محمد الحمدي' }));
    expect(await screen.findByText('صفحة الحساب')).toBeVisible();
  });

  it('searches from the top bar term and says when nothing matches', async () => {
    vi.mocked(getUsers).mockResolvedValue({ items: [], page: 1, limit: 20, total: 0, totalPages: 1 });
    renderAt('/users?search=777');
    expect(await screen.findByText('ما فيه حساب يطابق «777».')).toBeVisible();
    expect(getUsers).toHaveBeenCalledWith({ search: '777', page: 1, limit: 20 });
    expect(screen.getByLabelText('ابحث بالاسم أو الرقم')).toHaveValue('777');
  });

  it('says in Arabic when the list cannot load and tries again', async () => {
    vi.mocked(getUsers).mockRejectedValueOnce(
      new Error('تعذر الاتصال بالخادم. تأكد من الإنترنت ثم حاول مرة ثانية.'),
    );
    renderAt('/users');
    const alert = await screen.findByRole('alert');
    expect(alert).toHaveTextContent('تعذر الاتصال بالخادم');
    fireEvent.click(within(alert).getByRole('button', { name: 'حاول مرة ثانية' }));
    await waitFor(() => expect(screen.getByText('محمد الحمدي')).toBeVisible());
  });
});
