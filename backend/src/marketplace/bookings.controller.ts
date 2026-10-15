import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  UseGuards,
} from "@nestjs/common";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../modules/identity/public/current-user.decorator";
import { JwtAuthGuard } from "../modules/identity/public/jwt-auth.guard";
import { BookingsService } from "./bookings.service";
import {
  BlockedDateDto,
  BookingDecisionDto,
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
