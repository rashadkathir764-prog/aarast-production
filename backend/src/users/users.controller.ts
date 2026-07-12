import {
  Body,
  Controller,
  Delete,
  Get,
  Patch,
  Query,
  UseGuards,
} from "@nestjs/common";
import { Throttle } from "@nestjs/throttler";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { UpdateProfileDto } from "./dto/update-profile.dto";
import { UpdateSettingsDto } from "./dto/update-settings.dto";
import { UserLookupDto } from "./dto/user-lookup.dto";
import { UsersService } from "./users.service";

@Controller("api/v1/users")
@UseGuards(JwtAuthGuard)
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Patch("me")
  updateMe(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: UpdateProfileDto,
  ) {
    return this.usersService.updateMe(currentUser, dto);
  }

  @Delete("me")
  deleteMe(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.usersService.deleteMe(currentUser);
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
