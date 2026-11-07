import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Patch,
  Post,
  UseGuards,
} from "@nestjs/common";
import { Throttle } from "@nestjs/throttler";
import { AuthenticatedUser } from "../public/identity-session.types";
import { CurrentUser } from "../public/current-user.decorator";
import { AllowedWhileDeletionPending, JwtAuthGuard } from "../public/jwt-auth.guard";
import { UpdateProfileDto } from "./user-dto/update-profile.dto";
import { UpdateSettingsDto } from "./user-dto/update-settings.dto";
import { UpdatePrivacyDto } from "./user-dto/privacy.dto";
import { UsersService } from "../internal/profile/users.service";
import { DataExportService } from "../internal/profile/data-export.service";

@Controller("api/v1/users")
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(
    private readonly usersService: UsersService,
    private readonly dataExports: DataExportService,
  ) {}

  @Patch("me")
  updateMe(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: UpdateProfileDto,
  ) {
    return this.usersService.updateMe(currentUser, dto);
  }

  // D63 (w40): a one-time link to the account's own data. RA-BE-56: also in
  // the 30 days before erasure, when someone leaving wants it most; it was
  // refused then, and the only way was to take the deletion back, download
  // and ask again, which started the 30 days over.
  @Post("me/exports")
  @HttpCode(HttpStatus.CREATED)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @AllowedWhileDeletionPending()
  createExport(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.dataExports.create(currentUser);
  }

  @Get("me/privacy")
  getPrivacy(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.usersService.getPrivacy(currentUser);
  }

  @Patch("me/privacy")
  updatePrivacy(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: UpdatePrivacyDto,
  ) {
    return this.usersService.updatePrivacy(currentUser, dto);
  }

  @Get("me/settings")
  getSettings(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.usersService.getSettings(currentUser);
  }

  @Patch("me/settings")
  updateSettings(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: UpdateSettingsDto,
  ) {
    return this.usersService.updateSettings(currentUser, dto);
  }
}
