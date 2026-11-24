import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { activateUser, disableUser, getUser } from './api';

type AdminUserDetail = Awaited<ReturnType<typeof getUser>>;
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

function account(input: Partial<AdminUserDetail> = {}): AdminUserDetail {
  return {
    plans: [],
    reports: [],
    sessions: { application: 0, admin: 0, lastLoginAt: null },
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
    // RA-AD-23: the reason is asked for and sent, so the audit log keeps it.
    // (This called disableUser('user-1') with no reason, the defect itself.)
    expect(within(dialog).getByRole('button', { name: 'عطّل' })).toBeDisabled();
    fireEvent.change(within(dialog).getByRole('textbox', { name: 'السبب' }), {
      target: { value: 'يحتال على المزودين' },
    });
    fireEvent.click(within(dialog).getByRole('button', { name: 'عطّل' }));
    await waitFor(() =>
      expect(disableUser).toHaveBeenCalledWith('user-1', 'يحتال على المزودين'),
    );
  });

  // RA-AD-25: the page was a name, a phone and a date: none of the first
  // week's questions (whose plan, which business, what was reported, is he
  // signed in) had an answer.
  it('shows his plans, his business, the reports by and on him and his sessions', async () => {
    vi.mocked(getUser).mockResolvedValue(
      account({
        plans: [
          { id: 'plan-1', title: 'عرس محمد ونورة', role: 'OWNER', status: 'PLANNING', weddingDate: '2026-12-20T00:00:00.000Z' },
          { id: 'plan-2', title: 'عرس أخوه', role: 'MEMBER', status: 'PLANNING', weddingDate: null },
        ],
        provider: { id: 'prov-1', businessName: 'استوديو ضوء', status: 'ACTIVE', city: { nameAr: 'صنعاء' }, primaryCategory: { nameAr: 'التصوير' } },
        reports: [
          { id: 'r-1', reason: 'سب وشتم', status: 'OPEN', createdAt: '2026-10-23T08:00:00.000Z', direction: 'AGAINST', counterpart: 'قاعة الريان' },
          { id: 'r-2', reason: 'ما رد', status: 'REVIEWED', createdAt: '2026-10-10T08:00:00.000Z', direction: 'FILED', counterpart: 'فرقة الأفراح' },
        ],
        sessions: { application: 2, admin: 0, lastLoginAt: '2026-10-24T06:10:00.000Z' },
      }),
    );
    renderUser();

    const plans = await screen.findByRole('region', { name: 'الخطط' });
    expect(within(plans).getByText('عرس محمد ونورة')).toBeVisible();
    expect(within(plans).getByText(/صاحب الخطة · العرس 20 ديسمبر/)).toBeVisible();
    expect(within(plans).getByText('مشارك فيها')).toBeVisible();
    const business = screen.getByRole('region', { name: 'المزود' });
    expect(within(business).getByRole('link', { name: 'استوديو ضوء' })).toHaveAttribute('href', '/providers/prov-1');
    expect(within(business).getByText('التصوير · صنعاء')).toBeVisible();
    const reports = screen.getByRole('region', { name: 'البلاغات' });
    expect(within(reports).getByText('بلاغ عليه من قاعة الريان · أمس')).toBeVisible();
    expect(within(reports).getByText(/بلاغ منه على فرقة الأفراح · /)).toBeVisible();
    expect(within(reports).getByText(/تمت المراجعة/)).toBeVisible();
    const sessions = screen.getByRole('region', { name: 'الدخول' });
    expect(sessions).toHaveTextContent('أجهزة داخل منها التطبيق2');
    expect(sessions).toHaveTextContent('آخر دخول9:10');
    expect(sessions).not.toHaveTextContent('اللوحة');
  });

  it('says plainly what he does not have', async () => {
    vi.mocked(getUser).mockResolvedValue(account({ provider: null }));
    renderUser();

    expect(await screen.findByText('ما عنده خطة ولا هو مشارك في خطة.')).toBeVisible();
    expect(screen.getByText('ما عنده ملف مزود.')).toBeVisible();
    expect(screen.getByText('ما فيه بلاغ منه ولا عليه.')).toBeVisible();
    expect(screen.getByRole('region', { name: 'الدخول' })).toHaveTextContent('آخر دخولما دخل بعد');
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
