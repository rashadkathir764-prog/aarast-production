import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  UseGuards,
} from "@nestjs/common";
import { Throttle } from "@nestjs/throttler";
import { AuthenticatedUser } from "../public/identity-session.types";
import { CurrentUser } from "../public/current-user.decorator";
import { AllowedWhileDeletionPending, JwtAuthGuard } from "../public/jwt-auth.guard";
import { RequestAccountDeletionDto } from "./user-dto/account-deletion-status.dto";
import { AccountDeletionService } from "../internal/profile/account-deletion.service";

/**
 * D63: the account's deletion request and its status. The app asks for it
 * (w05), reads the day of the erasure and takes it back (w06); the hourly
 * purge erases the account once its 30 days are over. Nothing here erases.
 */
@Controller("api/v1/users/me/deletion")
@UseGuards(JwtAuthGuard)
export class AccountDeletionStatusController {
  constructor(private readonly accountDeletion: AccountDeletionService) {}

  // w05: what deleting the account takes with it.
  @Get("impact")
  deletionImpact(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.accountDeletion.impact(currentUser);
  }

  // w05: the account is erased after 30 days unless taken back. The limit is
  // per address, and Yemeni carriers put many phones behind one, so it is the
  // sign-in's 10 a minute rather than tighter.
  @Post()
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  requestDeletion(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: RequestAccountDeletionDto,
  ) {
    return this.accountDeletion.request(currentUser, dto.confirmWord);
  }

  // w06: the waiting account reads its day and may take it back.
  @Get()
  @AllowedWhileDeletionPending()
  deletionStatus(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.accountDeletion.status(currentUser);
  }

  @Delete()
  @AllowedWhileDeletionPending()
  cancelDeletion(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.accountDeletion.cancel(currentUser);
  }
}
