import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { AdminPermission } from '../auth/api';
import {
  getDataRequests,
  restoreAccountDeletion,
  type DataRequests,
  type PendingDeletion,
} from './api';
import { DataRequestsPage } from './DataRequestsPage';

vi.mock('./api', () => ({ getDataRequests: vi.fn(), restoreAccountDeletion: vi.fn() }));

const authState = vi.hoisted(() => ({
  user: { id: 'admin-1', name: 'نادية', adminPermissions: [] as string[] },
}));
vi.mock('../auth/AuthProvider', () => ({ useAuth: () => authState }));

beforeEach(() => {
  authState.user.adminPermissions = [AdminPermission.USERS_READ, AdminPermission.USERS_WRITE];
});

const deletion = (overrides: Partial<PendingDeletion> = {}): PendingDeletion => ({
  userId: 'user-1',
  name: 'سلمان المنصور',
  phone: '+967771554220',
  kind: 'ACCOUNT_DELETION',
  requestedAt: '2026-10-19T09:00:00.000Z',
  scheduledFor: '2026-11-18T09:00:00.000Z',
  daysLeft: 27,
  purgeFailedAt: null,
  purgeFailure: null,
  ...overrides,
});

const requests: DataRequests = {
  exports: [
    {
      id: 'export-1',
      userId: 'user-3',
      name: 'خالد',
      phone: '+967770998321',
      createdAt: '2026-10-26T09:00:00.000Z',
      expiresAt: '2026-10-26T09:15:00.000Z',
      downloadedAt: '2026-10-26T09:02:00.000Z',
      state: 'DOWNLOADED',
    },
  ],
  deletions: [
    deletion(),
    deletion({
      userId: 'user-2',
      name: 'ضيافة الأصالة',
      phone: '+967733445566',
      kind: 'PROVIDER_ACCOUNT_DELETION',
      daysLeft: 0,
      purgeFailedAt: '2026-10-28T09:35:00.000Z',
      purgeFailure: 'PROVIDER_HAS_UPCOMING_BOOKINGS',
    }),
  ],
};

describe('n06 data requests (A-15, D63)', () => {
  it('lists the downloads and the pending deletions, and never a link', async () => {
    vi.mocked(getDataRequests).mockResolvedValue(requests);
    render(
      <MemoryRouter>
        <DataRequestsPage />
      </MemoryRouter>,
    );

    const table = await screen.findByRole('table');
    expect(within(table).getByText('نسخة من بياناته')).toBeInTheDocument();
    expect(within(table).getByText('نزّلها')).toBeInTheDocument();
    expect(within(table).getByText('حذف الحساب')).toBeInTheDocument();
    expect(within(table).getByText('مهلة: باقي 27 يوم')).toBeInTheDocument();
    expect(within(table).getByText('حذف حساب مزود')).toBeInTheDocument();
    expect(within(table).getByText('موقوف: عنده حجوزات جاية')).toBeInTheDocument();
    // The link is the account's alone.
    expect(screen.queryByText(/data-exports|أرسل الرابط/)).toBeNull();
  });

  it('takes a deletion back at the account request, then reads again', async () => {
    vi.mocked(getDataRequests).mockResolvedValue(requests);
    vi.mocked(restoreAccountDeletion).mockResolvedValue({ userId: 'user-1', status: 'NONE' });
    render(
      <MemoryRouter>
        <DataRequestsPage />
      </MemoryRouter>,
    );

    const restore = await screen.findByRole('button', {
      name: 'رجّع حساب سلمان المنصور بطلبه',
    });
    const readsBefore = vi.mocked(getDataRequests).mock.calls.length;
    fireEvent.click(restore);
    await waitFor(() => expect(restoreAccountDeletion).toHaveBeenCalledWith('user-1'));
    await waitFor(() =>
      expect(vi.mocked(getDataRequests).mock.calls.length).toBe(readsBefore + 1),
    );
  });

  // RA-AD-10: support reads the requests (USERS_READ) but cannot take a
  // deletion back (USERS_WRITE): the button it would press only to be refused
  // is not shown.
  it('shows the take-back only to a role that may use it', async () => {
    authState.user.adminPermissions = [AdminPermission.USERS_READ];
    vi.mocked(getDataRequests).mockResolvedValue(requests);
    render(
      <MemoryRouter>
        <DataRequestsPage />
      </MemoryRouter>,
    );
    const table = await screen.findByRole('table');
    expect(within(table).getByText('مهلة: باقي 27 يوم')).toBeInTheDocument();
    expect(
      screen.queryByRole('button', { name: 'رجّع حساب سلمان المنصور بطلبه' }),
    ).not.toBeInTheDocument();
  });

  it('says plainly when nothing waits', async () => {
    vi.mocked(getDataRequests).mockResolvedValue({ exports: [], deletions: [] });
    render(
      <MemoryRouter>
        <DataRequestsPage />
      </MemoryRouter>,
    );
    expect(await screen.findByText('ما فيه طلب الحين.')).toBeInTheDocument();
  });
});
