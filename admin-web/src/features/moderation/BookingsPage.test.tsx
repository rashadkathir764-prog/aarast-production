import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { getBooking, getBookings, type AdminBooking } from './api';
import { getProviders } from '../providers/api';
import { BookingsPage } from './BookingsPage';

vi.mock('./api', () => ({ getBookings: vi.fn(), getBooking: vi.fn() }));
vi.mock('../providers/api', () => ({ getProviders: vi.fn() }));

const page = <T,>(items: T[]) => ({ items, page: 1, limit: 20, total: items.length, totalPages: 1 });

const booking = (overrides: Partial<AdminBooking> = {}): AdminBooking => ({
  id: 'booking-1',
  eventDate: '2027-01-21',
  status: 'CONFIRMED',
  lifecycleStatus: 'CONFIRMED',
  provider: { id: 'provider-1', businessName: 'ضيافة الأصالة', status: 'ACTIVE' },
  customer: { userId: 'user-1', name: 'محمد الحمدي', weddingPlanId: 'plan-1' },
  quoteRequestId: 'quote-1',
  guestCount: 150,
  cancelledBy: null,
  note: null,
  requestedAt: '2026-08-05T10:00:00.000Z',
  confirmedAt: '2026-08-06T10:00:00.000Z',
  declinedAt: null,
  cancelledAt: null,
  expiredAt: null,
  updatedAt: '2026-08-06T10:00:00.000Z',
  ...overrides,
});

describe('a12 bookings (B-40)', () => {
  beforeEach(() => {
    vi.mocked(getProviders).mockResolvedValue(page([]) as never);
  });

  it('lists the bookings read only, with who ended one and why', async () => {
    vi.mocked(getBookings).mockResolvedValue(
      page([
        booking(),
        booking({
          id: 'booking-2',
          status: 'CANCELLED',
          lifecycleStatus: 'CANCELLED',
          cancelledBy: 'PROVIDER',
          cancelledAt: '2026-10-20T10:00:00.000Z',
          note: 'ظرف طارئ',
          customer: { userId: 'user-2', name: 'فهد العمري', weddingPlanId: null },
        }),
      ]),
    );
    render(
      <MemoryRouter>
        <BookingsPage />
      </MemoryRouter>,
    );

    expect(await screen.findByText('محمد الحمدي')).toBeInTheDocument();
    const table = screen.getByRole('table');
    expect(within(table).getByText('مؤكد')).toBeInTheDocument();
    expect(within(table).getAllByText(/ألغاه المزود/).length).toBe(2);
    // Read only: no amount and no action that changes a booking.
    expect(screen.queryByText(/ر\.ي|ريال|دفعة/)).toBeNull();
    expect(screen.queryByRole('button', { name: /ألغ|أكّد|انحلّت/ })).toBeNull();

    vi.mocked(getBooking).mockResolvedValue(
      booking({
        id: 'booking-2',
        status: 'CANCELLED',
        lifecycleStatus: 'CANCELLED',
        cancelledBy: 'PROVIDER',
        cancelledAt: '2026-10-20T10:00:00.000Z',
        note: 'ظرف طارئ',
        customer: { userId: 'user-2', name: 'فهد العمري', weddingPlanId: null },
      }),
    );
    fireEvent.click(screen.getByText('فهد العمري'));
    expect(await screen.findByText('السبب: «ظرف طارئ»')).toBeInTheDocument();
    expect(getBooking).toHaveBeenCalledWith('booking-2');
  });

  it('filters by status and day range on the server', async () => {
    vi.mocked(getBookings).mockResolvedValue(page([booking()]));
    render(
      <MemoryRouter>
        <BookingsPage />
      </MemoryRouter>,
    );
    await screen.findByText('محمد الحمدي');

    fireEvent.change(screen.getByLabelText('الحالة'), { target: { value: 'EXPIRED' } });
    fireEvent.change(screen.getByLabelText('من يوم'), { target: { value: '2027-01-01' } });
    await waitFor(() =>
      expect(getBookings).toHaveBeenLastCalledWith(
        expect.objectContaining({ status: 'EXPIRED', from: '2027-01-01', page: 1 }),
      ),
    );
  });

  // RA-AD-19: «كل الحجوزات» was shown while the filters were not the very
  // object it resets to, so it stayed after it had cleared them.
  it('hides «كل الحجوزات» once it has cleared the filters', async () => {
    vi.mocked(getBookings).mockResolvedValue(page([booking()]));
    render(
      <MemoryRouter>
        <BookingsPage />
      </MemoryRouter>,
    );
    await screen.findByText('محمد الحمدي');
    expect(screen.queryByRole('button', { name: 'كل الحجوزات' })).toBeNull();
    fireEvent.change(screen.getByLabelText('الحالة'), { target: { value: 'EXPIRED' } });
    fireEvent.click(await screen.findByRole('button', { name: 'كل الحجوزات' }));
    expect(screen.getByLabelText('الحالة')).toHaveValue('');
    expect(screen.queryByRole('button', { name: 'كل الحجوزات' })).toBeNull();
  });

  // RA-AD-18: the filter read the first 100 active providers, so the
  // suspended one behind «انتهى مع إيقاف المزود» could not be picked, nor
  // any active one past a hundred. An approved provider is active or
  // suspended, which is what the list without a status returns.
  it('offers every approved provider, the suspended ones marked', async () => {
    vi.mocked(getBookings).mockResolvedValue(page([booking()]));
    const active = Array.from({ length: 100 }, (_, index) => ({
      id: `active-${index}`,
      businessName: `مزود ${index}`,
      status: 'ACTIVE',
    }));
    vi.mocked(getProviders).mockImplementation(async (params) =>
      ({
        items:
          params?.page === 2
            ? [{ id: 'suspended-1', businessName: 'قاعة الندى', status: 'SUSPENDED' }]
            : active,
        page: params?.page ?? 1,
        limit: 100,
        total: 101,
        totalPages: 2,
      }) as never,
    );
    render(
      <MemoryRouter>
        <BookingsPage />
      </MemoryRouter>,
    );
    const filter = screen.getByLabelText('المزود');
    expect(await within(filter).findByRole('option', { name: 'قاعة الندى (موقوف)' })).toBeInTheDocument();
    expect(within(filter).getByRole('option', { name: 'مزود 99' })).toBeInTheDocument();
    expect(getProviders).not.toHaveBeenCalledWith(expect.objectContaining({ status: 'ACTIVE' }));
  });

  // RA-AD-16: «إلى يوم» before «من يوم» went to the server, which refuses
  // it, and came back as «تعذّر الحفظ» with a retry that failed the same way.
  it('says the days are the wrong way round instead of asking the server', async () => {
    vi.mocked(getBookings).mockResolvedValue(page([booking()]));
    render(
      <MemoryRouter>
        <BookingsPage />
      </MemoryRouter>,
    );
    await screen.findByText('محمد الحمدي');
    fireEvent.change(screen.getByLabelText('إلى يوم'), { target: { value: '2027-01-10' } });
    await waitFor(() =>
      expect(getBookings).toHaveBeenLastCalledWith(expect.objectContaining({ to: '2027-01-10' })),
    );
    const asked = vi.mocked(getBookings).mock.calls.length;

    fireEvent.change(screen.getByLabelText('من يوم'), { target: { value: '2027-02-01' } });
    expect(await screen.findByText('«من يوم» بعد «إلى يوم»: بدّل واحد منهم.')).toBeVisible();
    expect(screen.queryByText(/تعذّر الحفظ/)).toBeNull();
    expect(getBookings).toHaveBeenCalledTimes(asked);
  });
});
