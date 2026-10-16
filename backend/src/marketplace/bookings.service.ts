import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  BookingParty,
  BookingStatus,
  Prisma,
  QuoteRequestStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import {
  assertWeddingPlanWritable,
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
  seesWholePlan,
} from "../modules/collaboration/public/collaboration-permission.port";
import {
  NOTIFICATIONS_PORT,
  type NotificationsPort,
} from "../modules/notifications/public/notifications.port";
import * as bookings from "../modules/marketplace/infrastructure/marketplace-booking.repository";
import * as dashboardStore from "../modules/marketplace/infrastructure/provider-dashboard.repository";
import { assertProviderOperational } from "../modules/marketplace/public/provider-access-policy";
import {
  runRetryableTransaction,
  runSerializableTransaction,
} from "../platform/database/serializable-transaction";
import { PrismaService } from "../platform/database/prisma.service";
import {
  bookingActionViolation,
  bookingToday,
  canRequestBooking,
  parseBookingDate,
  toBookingResponse,
  type BookingAction,
  type BookingResponse,
} from "./booking-policy";
import {
  BOOKING_REMINDER_MILESTONES,
  bookingCustomerNotification,
  bookingProviderNotification,
  bookingReminderNotifications,
} from "./booking-notifications";
import { BookingDecisionDto, RequestBookingDto } from "./dto/booking.dto";
import { lockMarketplaceProvider } from "./marketplace-write-locks";

type Tx = Prisma.TransactionClient;

function bookingError(
  status: "BAD_REQUEST" | "CONFLICT",
  code: string,
  message: string,
): never {
  const body = { statusCode: status === "CONFLICT" ? 409 : 400, code, message };
  throw status === "CONFLICT"
    ? new ConflictException(body)
    : new BadRequestException(body);
}

function optionalNote(value: string | null | undefined): string | null {
  const trimmed = value?.trim();
  return trimmed ? trimmed : null;
}

function isUniqueViolation(error: unknown): boolean {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError &&
    error.code === "P2002"
  );
}

/**
 * Bookings without payment and the provider's calendar (V1 checklist 4.6).
 * A customer who accepted a provider's offer asks them to reserve the day;
 * the provider confirms or declines; either side may cancel before the day.
 * A provider is never confirmed twice on one day: the provider row is locked
 * for every availability decision and a partial unique index backs it.
 */
@Injectable()
export class BookingsService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: PermissionService,
    @Inject(NOTIFICATIONS_PORT)
    private readonly notifications: NotificationsPort,
  ) {}

  // ── Customer ─────────────────────────────────────────────────────────

  async requestBooking(
    currentUser: AuthenticatedUser,
    quoteRequestId: string,
    dto: RequestBookingDto,
  ): Promise<BookingResponse> {
    return runSerializableTransaction(this.prisma, async (tx) => {
      const quote = await bookings.findQuoteForBooking(tx, quoteRequestId);
      if (!quote) throw new NotFoundException("Quote request not found");
      await this.assertCustomerAccess(tx, quote, currentUser);
      if (quote.status !== QuoteRequestStatus.ACCEPTED || !quote.offers[0]) {
        bookingError(
          "CONFLICT",
          "BOOKING_QUOTE_NOT_ACCEPTED",
          "A booking follows an accepted offer",
        );
      }
      if (!canRequestBooking(quote.booking?.status ?? null)) {
        bookingError(
          "CONFLICT",
          "BOOKING_ALREADY_OPEN",
          "This quote already has an open booking",
        );
      }
      const day = parseBookingDate(dto.eventDate, quote.eventDate);
      if (typeof day === "string") {
        if (day === "DATE_IN_PAST") {
          bookingError("BAD_REQUEST", "BOOKING_DATE_IN_PAST", "The day has passed");
        }
        bookingError("BAD_REQUEST", "BOOKING_INVALID_DATE", "Choose the wedding day");
      }

      const provider = await lockMarketplaceProvider(tx, quote.providerId, "UPDATE");
      assertProviderOperational(provider);
      await this.assertDayAvailable(tx, quote.providerId, day);

      const booking = await bookings.upsertBookingRequest(tx, {
        quoteRequestId: quote.id,
        quoteOfferId: quote.offers[0].id,
        providerId: quote.providerId,
        eventDate: day,
        requestedByUserId: currentUser.id,
        note: optionalNote(dto.note),
      });
      if (provider.userId) {
        await this.notifications.createNotificationInTransaction(
          tx,
          bookingProviderNotification("REQUESTED", {
            bookingId: booking.id,
            quoteRequestId: quote.id,
            providerId: quote.providerId,
            eventDate: day,
            revision: booking.updatedAt.getTime(),
            providerUserId: provider.userId,
            customerName: quote.contactName,
          }),
        );
      }
      return toBookingResponse(booking);
    });
  }

  async cancelAsCustomer(
    currentUser: AuthenticatedUser,
    bookingId: string,
    dto: BookingDecisionDto,
  ): Promise<BookingResponse> {
    return runSerializableTransaction(this.prisma, async (tx) => {
      const booking = await bookings.findBooking(tx, bookingId);
      if (!booking) throw new NotFoundException("Booking not found");
      await this.assertCustomerAccess(tx, booking.quoteRequest, currentUser);
      const provider = await lockMarketplaceProvider(tx, booking.providerId, "UPDATE");
      const updated = await this.transition(
        tx,
        booking,
        "CANCEL",
        BookingParty.CUSTOMER,
        dto,
      );
      if (provider.userId) {
        await this.notifications.createNotificationInTransaction(
          tx,
          bookingProviderNotification("CANCELLED", {
            bookingId: updated.id,
            quoteRequestId: updated.quoteRequestId,
            providerId: updated.providerId,
            eventDate: updated.eventDate,
            revision: updated.updatedAt.getTime(),
            providerUserId: provider.userId,
            customerName: booking.quoteRequest.contactName,
          }),
        );
      }
      return toBookingResponse(updated);
    });
  }

  /**
   * The plan's open booking requests and upcoming confirmed bookings (V1
   * checklist 4.13: when the wedding moves, the app names the bookings made
   * for the old day). The owner and partner see the plan's; another member
   * with provider rights sees the ones they requested; without provider
   * rights, none.
   */
  async listForPlan(currentUser: AuthenticatedUser, weddingPlanId: string) {
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const context = await this.permissions.assertPlanReadableInTransaction(
          tx,
          weddingPlanId,
          currentUser,
        );
        if (!this.permissions.canManageProviders(context)) return [];
        const wholePlan = seesWholePlan(context);
        const rows = await bookings.listPlanBookings(tx, weddingPlanId, bookingToday());
        return rows
          .filter((row) => wholePlan || row.quoteRequest.userId === currentUser.id)
          .map((row) => ({
            ...toBookingResponse(row),
            providerName: row.provider.businessName,
            weddingPlanId: row.quoteRequest.weddingPlanId,
          }));
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  // ── Provider ─────────────────────────────────────────────────────────

  async listForProvider(currentUser: AuthenticatedUser) {
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const provider = await this.ownedProvider(tx, currentUser);
        const rows = await bookings.listProviderBookings(
          tx,
          provider.id,
          bookingToday(),
        );
        return rows.map((row) => ({
          ...toBookingResponse(row),
          customerName: row.quoteRequest.contactName,
          guestCount: row.quoteRequest.guestCount,
          location: row.quoteRequest.location,
          weddingPlanId: row.quoteRequest.weddingPlanId,
        }));
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
  }

  async decideAsProvider(
    currentUser: AuthenticatedUser,
    bookingId: string,
    action: BookingAction,
    dto: BookingDecisionDto,
  ): Promise<BookingResponse> {
    try {
      return await runSerializableTransaction(this.prisma, async (tx) => {
        const provider = await this.ownedProvider(tx, currentUser);
        const booking = await bookings.findBooking(tx, bookingId);
        if (!booking || booking.providerId !== provider.id) {
          throw new NotFoundException("Booking not found");
        }
        await lockMarketplaceProvider(tx, provider.id, "UPDATE");
        if (action === "CONFIRM") {
          assertProviderOperational(provider);
          await this.assertDayAvailable(tx, provider.id, booking.eventDate, booking.id);
        }
        const updated = await this.transition(
          tx,
          booking,
          action,
          BookingParty.PROVIDER,
          dto,
        );
        const event =
          action === "CONFIRM" ? "CONFIRMED" : action === "DECLINE" ? "DECLINED" : "CANCELLED";
        await this.notifications.createNotificationInTransaction(
          tx,
          bookingCustomerNotification(event, {
            bookingId: updated.id,
            quoteRequestId: updated.quoteRequestId,
            providerId: updated.providerId,
            eventDate: updated.eventDate,
            revision: updated.updatedAt.getTime(),
            customerUserId: booking.quoteRequest.userId,
            weddingPlanId: booking.quoteRequest.weddingPlanId,
            providerName: provider.businessName,
          }),
        );
        return toBookingResponse(updated);
      });
    } catch (error) {
      // Two confirmations raced for one day: the partial unique index won.
      if (isUniqueViolation(error)) this.dayUnavailable();
      throw error;
    }
  }

  async listBlockedDates(currentUser: AuthenticatedUser) {
    const provider = await this.ownedProvider(this.prisma, currentUser);
    const rows = await bookings.listBlockedDates(this.prisma, provider.id, bookingToday());
    return rows.map((row) => row.date.toISOString().slice(0, 10));
  }

  async blockDate(currentUser: AuthenticatedUser, date: string) {
    return runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await this.ownedProvider(tx, currentUser);
      const day = parseBookingDate(date, null);
      if (typeof day === "string") {
        bookingError("BAD_REQUEST", "BOOKING_INVALID_DATE", "Choose a day from today on");
      }
      await lockMarketplaceProvider(tx, provider.id, "UPDATE");
      if (await bookings.hasConfirmedBookingOn(tx, provider.id, day)) {
        bookingError(
          "CONFLICT",
          "BOOKING_DATE_HAS_BOOKING",
          "A confirmed booking holds this day",
        );
      }
      await bookings.insertBlockedDate(tx, provider.id, day);
      return { date: day.toISOString().slice(0, 10) };
    });
  }

  async unblockDate(currentUser: AuthenticatedUser, date: string) {
    const provider = await this.ownedProvider(this.prisma, currentUser);
    const day = parseBookingDate(date, null, new Date(0));
    if (typeof day === "string") {
      bookingError("BAD_REQUEST", "BOOKING_INVALID_DATE", "Invalid day");
    }
    await bookings.deleteBlockedDate(this.prisma, provider.id, day);
    return { date: day.toISOString().slice(0, 10) };
  }

  // ── Reminders (V1 checklist 4.17) ────────────────────────────────────

  /**
   * Reminds both sides of each confirmed booking a week and a day before.
   * Each reminder is its own transaction that re-reads the booking, and its
   * dedupe key makes a repeated scan (or a second replica) a no-op. A failed
   * reminder is reported, not swallowed, and does not stop the others.
   */
  async sendDueReminders(
    now: Date = new Date(),
  ): Promise<{ sent: number; failures: Array<{ bookingId: string; error: unknown }> }> {
    const today = bookingToday(now);
    const until = new Date(
      today.getTime() + BOOKING_REMINDER_MILESTONES[0] * 24 * 60 * 60 * 1000,
    );
    const due = await bookings.listConfirmedBookingsDue(this.prisma, today, until);
    let sent = 0;
    const failures: Array<{ bookingId: string; error: unknown }> = [];
    for (const booking of due) {
      const reminders = bookingReminderNotifications(
        {
          bookingId: booking.id,
          quoteRequestId: booking.quoteRequestId,
          providerId: booking.providerId,
          eventDate: booking.eventDate,
          customerUserId: booking.quoteRequest.userId,
          weddingPlanId: booking.quoteRequest.weddingPlanId,
          customerName: booking.quoteRequest.contactName,
          providerUserId: booking.provider.userId,
          providerName: booking.provider.businessName,
        },
        today,
      );
      for (const reminder of reminders) {
        try {
          const created = await runSerializableTransaction(this.prisma, async (tx) => {
            const live = await bookings.findBooking(tx, booking.id);
            if (
              live?.status !== BookingStatus.CONFIRMED ||
              live.eventDate.getTime() !== booking.eventDate.getTime()
            ) {
              return null;
            }
            return this.notifications.createNotificationInTransaction(tx, reminder);
          });
          if (created) sent += 1;
        } catch (error) {
          // Already reminded in this window: the dedupe key holds.
          if (isUniqueViolation(error)) continue;
          failures.push({ bookingId: booking.id, error });
        }
      }
    }
    return { sent, failures };
  }

  // ── Shared ───────────────────────────────────────────────────────────

  /** The quote's requester, or the plan owner, with the right to manage providers. */
  private async assertCustomerAccess(
    tx: Tx,
    quote: { userId: string; weddingPlanId: string | null },
    currentUser: AuthenticatedUser,
  ) {
    if (!quote.weddingPlanId) {
      if (quote.userId !== currentUser.id) {
        throw new NotFoundException("Booking not found");
      }
      return null;
    }
    const context = await this.permissions.assertPlanReadableInTransaction(
      tx,
      quote.weddingPlanId,
      currentUser,
    );
    if (!this.permissions.canManageProviders(context)) {
      throw new ForbiddenException({
        statusCode: 403,
        code: "PROVIDER_PERMISSION_REVOKED",
        message: "Provider access has been revoked",
      });
    }
    assertWeddingPlanWritable(context.plan);
    if (!seesWholePlan(context) && quote.userId !== currentUser.id) {
      throw new NotFoundException("Booking not found");
    }
    return context;
  }

  private async ownedProvider(
    client: Tx | PrismaService,
    currentUser: AuthenticatedUser,
  ) {
    const provider = await dashboardStore.findProviderByUserId(client, currentUser.id);
    if (!provider) throw new NotFoundException("Provider profile not found");
    return provider;
  }

  private async assertDayAvailable(
    tx: Tx,
    providerId: string,
    day: Date,
    exceptBookingId?: string,
  ) {
    if (
      (await bookings.isProviderDateBlocked(tx, providerId, day)) ||
      (await bookings.hasConfirmedBookingOn(tx, providerId, day, exceptBookingId))
    ) {
      this.dayUnavailable();
    }
  }

  private dayUnavailable(): never {
    bookingError(
      "CONFLICT",
      "BOOKING_DATE_UNAVAILABLE",
      "The provider is not available on this day",
    );
  }

  private async transition(
    tx: Tx,
    booking: bookings.BookingWithQuote,
    action: BookingAction,
    actor: BookingParty,
    dto: BookingDecisionDto,
  ) {
    if (bookingActionViolation(booking.status, action, actor, booking.eventDate)) {
      bookingError(
        "CONFLICT",
        "BOOKING_NOT_ALLOWED",
        "This booking cannot change that way now",
      );
    }
    const now = new Date();
    const note = optionalNote(dto.note);
    const data: bookings.BookingTransition =
      action === "CONFIRM"
        ? { status: BookingStatus.CONFIRMED, confirmedAt: now, ...(note ? { note } : {}) }
        : action === "DECLINE"
          ? { status: BookingStatus.DECLINED, declinedAt: now, note }
          : { status: BookingStatus.CANCELLED, cancelledAt: now, cancelledBy: actor, note };
    const moved = await bookings.transitionBooking(tx, booking.id, booking.status, data);
    if (moved.count !== 1) {
      bookingError(
        "CONFLICT",
        "BOOKING_NOT_ALLOWED",
        "The booking changed meanwhile; refresh and retry",
      );
    }
    return bookings.requireBooking(tx, booking.id);
  }
}
