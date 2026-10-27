import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from "@nestjs/common";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../modules/identity/public/current-user.decorator";
import { JwtAuthGuard } from "../modules/identity/public/jwt-auth.guard";
import { BookingsService } from "./bookings.service";
import {
  BlockedDateDto,
  BookingChangeDecisionDto,
  BookingChangeDto,
  BookingDecisionDto,
  BookingDeliveryDto,
  BookingNotHappenedDto,
  RequestBookingDto,
} from "./dto/booking.dto";

/** The customer's side of a booking (V1 checklist 4.6). */
@Controller("api/v1/me")
@UseGuards(JwtAuthGuard)
export class MeBookingsController {
  constructor(private readonly bookings: BookingsService) {}

  @Post("quote-requests/:id/booking")
  requestBooking(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() dto: RequestBookingDto,
  ) {
    return this.bookings.requestBooking(currentUser, id, dto);
  }

  @Patch("bookings/:id/cancel")
  cancelBooking(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() dto: BookingDecisionDto,
  ) {
    return this.bookings.cancelAsCustomer(currentUser, id, dto);
  }

  /** B-23: the customer confirms the provider's delivery. */
  @Post("bookings/:id/delivery/confirm")
  confirmDelivery(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id", ParseUUIDPipe) id: string,
  ) {
    return this.bookings.confirmDeliveryAsCustomer(currentUser, id);
  }

  /** B-24: the customer asks to move a confirmed booking to another day. */
  @Post("bookings/:id/change")
  requestChange(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() dto: BookingChangeDto,
  ) {
    return this.bookings.requestChangeAsCustomer(currentUser, id, dto);
  }

  /** The plan's open and upcoming bookings (V1 checklist 4.13). */
  @Get("wedding-plans/:weddingPlanId/bookings")
  listPlanBookings(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
  ) {
    return this.bookings.listForPlan(currentUser, weddingPlanId);
  }
}

/** The provider's bookings and calendar. */
@Controller("api/v1/provider/me")
@UseGuards(JwtAuthGuard)
export class ProviderBookingsController {
  constructor(private readonly bookings: BookingsService) {}

  @Get("bookings")
  listBookings(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.bookings.listForProvider(currentUser);
  }

  /** p47 «حساباتك»: a month's agreed, paid and left (B-18, read only). */
  @Get("ledger")
  ledger(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Query("month") month: string,
  ) {
    return this.bookings.ledgerForProvider(currentUser, month);
  }

  @Patch("bookings/:id/confirm")
  confirm(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() dto: BookingDecisionDto,
  ) {
    return this.bookings.decideAsProvider(currentUser, id, "CONFIRM", dto);
  }

  @Patch("bookings/:id/decline")
  decline(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() dto: BookingDecisionDto,
  ) {
    return this.bookings.decideAsProvider(currentUser, id, "DECLINE", dto);
  }

  @Patch("bookings/:id/cancel")
  cancel(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() dto: BookingDecisionDto,
  ) {
    return this.bookings.decideAsProvider(currentUser, id, "CANCEL", dto);
  }

  /** B-22: «تم», from the day to a week after. */
  @Post("bookings/:id/complete")
  complete(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id", ParseUUIDPipe) id: string,
  ) {
    return this.bookings.recordOutcomeAsProvider(currentUser, id, { happened: true });
  }

  /** B-22: «ما صار» and why. */
  @Post("bookings/:id/not-happened")
  notHappened(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() dto: BookingNotHappenedDto,
  ) {
    return this.bookings.recordOutcomeAsProvider(currentUser, id, {
      happened: false,
      reason: dto.reason,
    });
  }

  /** B-23: the delivery, once the wedding is done. */
  @Post("bookings/:id/delivery")
  deliver(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() dto: BookingDeliveryDto,
  ) {
    return this.bookings.deliverAsProvider(currentUser, id, dto);
  }

  /** B-24: the provider takes the customer's new day. */
  @Post("booking-changes/:id/accept")
  acceptChange(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id", ParseUUIDPipe) id: string,
  ) {
    return this.bookings.decideChangeAsProvider(currentUser, id, true, {});
  }

  /** B-24: the provider cannot take the new day; the booking keeps its day. */
  @Post("booking-changes/:id/decline")
  declineChange(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("id", ParseUUIDPipe) id: string,
    @Body() dto: BookingChangeDecisionDto,
  ) {
    return this.bookings.decideChangeAsProvider(currentUser, id, false, dto);
  }

  @Get("blocked-dates")
  listBlockedDates(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.bookings.listBlockedDates(currentUser);
  }

  @Post("blocked-dates")
  blockDate(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: BlockedDateDto,
  ) {
    return this.bookings.blockDate(currentUser, dto.date);
  }

  @Delete("blocked-dates/:date")
  unblockDate(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("date") date: string,
  ) {
    return this.bookings.unblockDate(currentUser, date);
  }
}
