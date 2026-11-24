import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { decideProfileChange, getProfileChanges, type ProfileChange } from './api';
import { ProfileChangesPage } from './ProfileChangesPage';

vi.mock('./api', () => ({ getProfileChanges: vi.fn(), decideProfileChange: vi.fn() }));

let permissions = ['PROVIDERS_READ', 'PROVIDERS_WRITE'];
vi.mock('../auth/AuthProvider', () => ({
  useAuth: () => ({ user: { id: 'admin-1', name: 'سارة', adminPermissions: permissions } }),
}));

const page = <T,>(items: T[]) => ({ items, page: 1, limit: 24, total: items.length, totalPages: 1 });

const change = (overrides: Partial<ProfileChange> = {}): ProfileChange => ({
  id: 'change-1',
  status: 'PENDING',
  rejectionReason: null,
  decidedAt: null,
  createdAt: '2026-11-24T10:00:00.000Z',
  updatedAt: '2026-11-24T10:00:00.000Z',
  asked: {
    businessName: 'استوديو ضوء الجديد',
    city: { id: 'city-2', nameAr: 'عدن' },
    primaryCategory: null,
    logoUrl: 'https://media.example/provider-logo/u/new.png',
    coverUrl: null,
    logoChanged: true,
    coverChanged: false,
  },
  provider: {
    id: 'provider-1',
    businessName: 'استوديو ضوء',
    status: 'ACTIVE',
    city: { id: 'city-1', nameAr: 'صنعاء' },
    primaryCategory: { id: 'cat-1', nameAr: 'تصوير' },
    logoUrl: 'https://media.example/provider-logo/u/old.png',
    coverUrl: null,
  },
  ...overrides,
});

function renderPage() {
  return render(
    <MemoryRouter>
      <ProfileChangesPage />
    </MemoryRouter>,
  );
}

// RA-BE-152 (Q-39 (أ)): an approved provider's new name, logo, cover, city
// or category waits here; the listing keeps the old until the team decides.
describe('provider profile changes waiting for review (RA-BE-152)', () => {
  beforeEach(() => {
    permissions = ['PROVIDERS_READ', 'PROVIDERS_WRITE'];
    vi.mocked(getProfileChanges).mockReset();
    vi.mocked(decideProfileChange).mockReset();
    vi.mocked(decideProfileChange).mockResolvedValue(change() as never);
  });

  it('shows what customers see now beside what he asked for, and approves', async () => {
    vi.mocked(getProfileChanges).mockResolvedValue(page([change()]) as never);
    renderPage();

    const card = (await screen.findByText('استوديو ضوء')).closest('li')!;
    expect(getProfileChanges).toHaveBeenCalledWith({ status: 'PENDING', page: 1, limit: 24 });
    expect(within(card).getByText('الاسم: استوديو ضوء ← استوديو ضوء الجديد')).toBeInTheDocument();
    expect(within(card).getByText('المدينة: صنعاء ← عدن')).toBeInTheDocument();
    expect(within(card).getByAltText('الشعار الجديد لـ استوديو ضوء')).toHaveAttribute(
      'src',
      'https://media.example/provider-logo/u/new.png',
    );
    expect(within(card).getByAltText('الشعار الحالي لـ استوديو ضوء')).toBeInTheDocument();

    fireEvent.click(within(card).getByRole('button', { name: 'وافق' }));
    await waitFor(() => expect(decideProfileChange).toHaveBeenCalledWith('change-1', { decision: 'APPROVE' }));
  });

  it('refuses with the reason the provider reads', async () => {
    vi.mocked(getProfileChanges).mockResolvedValue(page([change()]) as never);
    renderPage();

    const card = (await screen.findByText('استوديو ضوء')).closest('li')!;
    fireEvent.click(within(card).getByRole('button', { name: 'ارفض' }));
    const dialog = await screen.findByRole('dialog');
    fireEvent.change(within(dialog).getByRole('textbox'), { target: { value: 'الشعار فيه رقم جوال' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'ارفض' }));
    await waitFor(() =>
      expect(decideProfileChange).toHaveBeenCalledWith('change-1', {
        decision: 'REJECT',
        reason: 'الشعار فيه رقم جوال',
      }),
    );
  });

  it('reads without deciding when the team member may not change providers', async () => {
    permissions = ['PROVIDERS_READ'];
    vi.mocked(getProfileChanges).mockResolvedValue(page([change()]) as never);
    renderPage();

    const card = (await screen.findByText('استوديو ضوء')).closest('li')!;
    expect(within(card).queryByRole('button', { name: 'وافق' })).toBeNull();
  });

  it('says when nothing waits', async () => {
    vi.mocked(getProfileChanges).mockResolvedValue(page([]) as never);
    renderPage();
    expect(await screen.findByText('ما فيه تعديلات تنتظر المراجعة.')).toBeInTheDocument();
  });
});
