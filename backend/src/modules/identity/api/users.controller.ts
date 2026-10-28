import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Patch,
  Post,
  Query,
  UseGuards,
} from "@nestjs/common";
import { Throttle } from "@nestjs/throttler";
import { AuthenticatedUser } from "../public/identity-session.types";
import { CurrentUser } from "../public/current-user.decorator";
import { JwtAuthGuard } from "../public/jwt-auth.guard";
import { UpdateProfileDto } from "./user-dto/update-profile.dto";
import { UpdateSettingsDto } from "./user-dto/update-settings.dto";
import { UserLookupDto } from "./user-dto/user-lookup.dto";
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

  // D63 (w40): a one-time link to the account's own data.
  @Post("me/exports")
  @HttpCode(HttpStatus.CREATED)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
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

  @Get("lookup")
  @Throttle({ default: { limit: 15, ttl: 60_000 } })
  lookupByPhone(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Query() query: UserLookupDto,
  ) {
    return this.usersService.lookupByPhone(
      currentUser,
      query.weddingPlanId,
      query.phone,
    );
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
