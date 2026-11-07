import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { decidePortfolioPhoto, getPortfolioPhotos, type PortfolioPhoto } from './api';
import { PhotosPage } from './PhotosPage';

vi.mock('./api', () => ({ getPortfolioPhotos: vi.fn(), decidePortfolioPhoto: vi.fn() }));

let permissions = ['PROVIDERS_READ', 'REVIEWS_WRITE'];
vi.mock('../auth/AuthProvider', () => ({
  useAuth: () => ({ user: { id: 'admin-1', name: 'سارة', adminPermissions: permissions } }),
}));

const page = <T,>(items: T[]) => ({ items, page: 1, limit: 24, total: items.length, totalPages: 1 });

const photo = (overrides: Partial<PortfolioPhoto> = {}): PortfolioPhoto => ({
  id: 'photo-1',
  imageUrl: 'https://media.example/provider-portfolio/u/1.jpg',
  album: 'الزفة',
  forWomen: false,
  noFaces: false,
  status: 'PENDING',
  rejectionReason: null,
  reviewedAt: null,
  createdAt: '2026-10-25T10:00:00.000Z',
  provider: { id: 'provider-1', businessName: 'استوديو ضوء صنعاء', status: 'ACTIVE' },
  ...overrides,
});

function renderPage() {
  return render(
    <MemoryRouter>
      <PhotosPage />
    </MemoryRouter>,
  );
}

describe('n07 photos waiting for review (B-16)', () => {
  beforeEach(() => {
    permissions = ['PROVIDERS_READ', 'REVIEWS_WRITE'];
    vi.mocked(getPortfolioPhotos).mockReset();
    vi.mocked(decidePortfolioPhoto).mockReset();
    vi.mocked(decidePortfolioPhoto).mockResolvedValue(photo() as never);
  });

  it('lists the waiting photos oldest first, the women\'s album marked, and approves one', async () => {
    vi.mocked(getPortfolioPhotos).mockResolvedValue(
      page([
        photo(),
        photo({ id: 'photo-2', album: 'حفلات النساء', forWomen: true, noFaces: true }),
      ]) as never,
    );
    renderPage();

    expect(await screen.findByText('استوديو ضوء صنعاء · الزفة')).toBeInTheDocument();
    expect(getPortfolioPhotos).toHaveBeenCalledWith({ status: 'PENDING', page: 1, limit: 24 });
    expect(screen.getByText('للعرائس بس · المزود أكّد: بدون وجوه')).toBeInTheDocument();

    const first = screen.getByText('استوديو ضوء صنعاء · الزفة').closest('li')!;
    fireEvent.click(within(first).getByRole('button', { name: 'سليمة' }));
    await waitFor(() => expect(decidePortfolioPhoto).toHaveBeenCalledWith('photo-1', { decision: 'APPROVE' }));
  });

  // RA-AD-12: the server answers a page past the end with no rows; deciding
  // the last photo of page 2 said «ما فيه صور تنتظر المراجعة» while 24 waited.
  it('goes back to the last page when the last photo of a later page is decided', async () => {
    const firstPage = Array.from({ length: 24 }, (_, index) =>
      photo({ id: `p${index}`, album: `ألبوم ${index}` }),
    );
    let lastOneDecided = false;
    vi.mocked(getPortfolioPhotos).mockImplementation(async (params) => {
      const asked = params?.page;
      const total = lastOneDecided ? 24 : 25;
      const items = asked === 1 ? firstPage : !lastOneDecided && asked === 2 ? [photo({ id: 'last', album: 'الأخيرة' })] : [];
      return { items, page: asked ?? 1, limit: 24, total, totalPages: Math.ceil(total / 24) } as never;
    });
    vi.mocked(decidePortfolioPhoto).mockImplementation(async () => {
      lastOneDecided = true;
      return photo() as never;
    });
    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: 'الصفحة التالية' }));
    const last = (await screen.findByText('استوديو ضوء صنعاء · الأخيرة')).closest('li')!;
    fireEvent.click(within(last).getByRole('button', { name: 'سليمة' }));

    expect(await screen.findByText('استوديو ضوء صنعاء · ألبوم 0')).toBeInTheDocument();
    expect(screen.queryByText('ما فيه صور تنتظر المراجعة.')).not.toBeInTheDocument();
  });

  it('approves a women\'s photo only after the no-faces check', async () => {
    vi.mocked(getPortfolioPhotos).mockResolvedValue(
      page([photo({ id: 'photo-2', album: 'حفلات النساء', forWomen: true, noFaces: true })]) as never,
    );
    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: 'سليمة' }));
    expect(decidePortfolioPhoto).not.toHaveBeenCalled();
    fireEvent.click(await screen.findByRole('button', { name: 'سليمة، ما فيها وجوه' }));
    await waitFor(() =>
      expect(decidePortfolioPhoto).toHaveBeenCalledWith('photo-2', { decision: 'APPROVE', noFacesChecked: true }),
    );
  });

  it('refuses a photo with the reason the provider reads', async () => {
    vi.mocked(getPortfolioPhotos).mockResolvedValue(page([photo()]) as never);
    renderPage();
    fireEvent.click(await screen.findByRole('button', { name: 'شِل' }));
    const dialog = await screen.findByRole('dialog');
    fireEvent.change(within(dialog).getByRole('textbox'), { target: { value: 'الصورة مأخوذة من حساب ثاني' } });
    fireEvent.click(within(dialog).getByRole('button', { name: 'شِل' }));
    await waitFor(() =>
      expect(decidePortfolioPhoto).toHaveBeenCalledWith('photo-1', {
        decision: 'REJECT',
        reason: 'الصورة مأخوذة من حساب ثاني',
      }),
    );
  });

  it('shows the queue without the decisions to who may only read', async () => {
    permissions = ['PROVIDERS_READ'];
    vi.mocked(getPortfolioPhotos).mockResolvedValue(page([photo()]) as never);
    renderPage();
    expect(await screen.findByText('استوديو ضوء صنعاء · الزفة')).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'سليمة' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'شِل' })).not.toBeInTheDocument();
  });

  it('says when nothing waits', async () => {
    vi.mocked(getPortfolioPhotos).mockResolvedValue(page([]) as never);
    renderPage();
    expect(await screen.findByText('ما فيه صور تنتظر المراجعة.')).toBeInTheDocument();
  });
});
