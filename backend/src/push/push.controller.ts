import {
  Body,
  Controller,
  Delete,
  Header,
  Put,
  UseGuards,
} from "@nestjs/common";
import { Throttle } from "@nestjs/throttler";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { PushInstallationDto } from "./dto/push-installation.dto";
import { PushInstallationsService } from "./push-installations.service";

@Controller("api/v1/push/installations")
@UseGuards(JwtAuthGuard)
@Throttle({ default: { limit: 30, ttl: 60_000 } })
export class PushController {
  constructor(private readonly pushInstallations: PushInstallationsService) {}

  @Put("current")
  @Header("Cache-Control", "private, no-store")
  register(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: PushInstallationDto,
  ) {
    return this.pushInstallations.register(currentUser, dto.fid, dto.platform);
  }

  @Delete("current")
  @Header("Cache-Control", "private, no-store")
  unregister(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: PushInstallationDto,
  ) {
    return this.pushInstallations.unregister(currentUser, dto.fid);
  }
}
