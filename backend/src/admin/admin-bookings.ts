import { BadRequestException } from '@nestjs/common';
import { BookingStatus } from '@prisma/client';
import type {
  AdminBookingFilter,
  AdminBookingRow,
} from '../modules/marketplace/public/marketplace-admin.port';
import type { AdminBookingQueryDto } from './dto/admin-booking.dto';

// a12 «الحجوزات» (B-40): the back office reads bookings and never changes
// one. No amount, offer or payment is shown: the money is the customer's.

const DAY = /^(\d{4})-(\d{2})-(\d{2})$/;

function parseDay(value: string | undefined, field: string): Date | null {
  const text = value?.trim();
  if (!text) return null;
  const match = DAY.exec(text);
  const day = match
    ? new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])))
    : null;
  if (!day || day.toISOString().slice(0, 10) !== text) {
    throw new BadRequestException(`${field} must be a day (YYYY-MM-DD)`);
  }
  return day;
}

export function adminBookingFilter(query: AdminBookingQueryDto): AdminBookingFilter {
  const status = query.status?.trim().toUpperCase() || null;
  if (status && !(status in BookingStatus)) {
    throw new BadRequestException('booking status is not supported');
  }
  const from = parseDay(query.from, 'from');
  const to = parseDay(query.to, 'to');
  if (from && to && from > to) {
    throw new BadRequestException('from must not be after to');
  }
  return {
    providerId: query.providerId?.trim() || null,
    status: status ? BookingStatus[status as keyof typeof BookingStatus] : null,
    from,
    to,
  };
}

export function toAdminBookingResponse(booking: AdminBookingRow) {
  return {
    id: booking.id,
    eventDate: booking.eventDate.toISOString().slice(0, 10),
    status: booking.status,
    lifecycleStatus: booking.lifecycleStatus,
    provider: {
      id: booking.provider.id,
      businessName: booking.provider.businessName,
      status: booking.provider.status,
    },
    customer: {
      userId: booking.quoteRequest.userId,
      name: booking.quoteRequest.contactName,
      weddingPlanId: booking.quoteRequest.weddingPlanId,
    },
    quoteRequestId: booking.quoteRequestId,
    guestCount: booking.quoteRequest.guestCount,
    // Who ended it and why (the decline's or the cancel's note).
    cancelledBy: booking.cancelledBy,
    note: booking.note,
    requestedAt: booking.createdAt,
    confirmedAt: booking.confirmedAt,
    declinedAt: booking.declinedAt,
    cancelledAt: booking.cancelledAt,
    expiredAt: booking.expiredAt,
    updatedAt: booking.updatedAt,
  };
}
