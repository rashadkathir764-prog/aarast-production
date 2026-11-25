import {
  Body,
  ConflictException,
  Controller,
  HttpCode,
  HttpStatus,
  Post,
  Req,
} from "@nestjs/common";
import { Throttle } from "@nestjs/throttler";
import type { Request } from "express";
import { routeLimit } from "../../../platform/http/route-throttle";
import { clientRateContext } from "../../../platform/http/client-device";
import { AuthService } from "../internal/auth/auth.service";
import { AccountDeletionService } from "../internal/profile/account-deletion.service";
import {
  AccountDeletionCodeDto,
  AccountDeletionConfirmDto,
} from "./auth-dto/public-account-deletion.dto";

/**
 * Q-52 (أ, D124), RA-OP-21: a person without the app asks the account's
 * deletion from the public site's page (`/delete-account`), which talks to
 * these two routes on its own origin. The registered number is proven with
 * a WhatsApp code of its own purpose (ACCOUNT_DELETION_WEB); the account then
 * waits the same 30 days as a request from the app (D63), and signing in
 * takes it back (w06). The only public write that is not a guest's reply,
 * and it is proven by the code.
 */
@Controller("api/v1/public/account-deletion")
export class PublicAccountDeletionController {
  constructor(
    private readonly auth: AuthService,
    private readonly accountDeletion: AccountDeletionService,
  ) {}

  // The same answer for any well-formed number; the code limits count it.
  @Post("code")
  @HttpCode(HttpStatus.OK)
  @Throttle(routeLimit(10))
  requestCode(@Body() dto: AccountDeletionCodeDto, @Req() request: Request) {
    return this.auth.requestWebAccountDeletionCode(dto.phone, clientRateContext(request));
  }

  @Post("confirm")
  @HttpCode(HttpStatus.OK)
  @Throttle(routeLimit(10))
  async confirm(@Body() dto: AccountDeletionConfirmDto) {
    const userId = await this.auth.claimWebAccountDeletionCode(dto.phone, dto.code);
    try {
      const state = await this.accountDeletion.requestForAccount(userId);
      return { status: state.status, scheduledFor: state.scheduledFor };
    } catch (error) {
      // B-33: a provider with weddings still to do hands them over or
      // cancels them in the app first; the page says so without naming them.
      if (
        error instanceof ConflictException &&
        (error.getResponse() as { code?: unknown }).code === "PROVIDER_HAS_UPCOMING_BOOKINGS"
      ) {
        throw new ConflictException({
          statusCode: 409,
          code: "PROVIDER_HAS_UPCOMING_BOOKINGS",
          message: "Hand over or cancel the upcoming bookings in the app first",
        });
      }
      throw error;
    }
  }
}
