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
});
