import { Controller, Get, UseGuards } from "@nestjs/common";
import { AuthenticatedUser } from "../public/identity-session.types";
import { CurrentUser } from "../public/current-user.decorator";
import { JwtAuthGuard } from "../public/jwt-auth.guard";
import { toSafeUser } from "../internal/safe-user.presenter";

@Controller("api/v1/me")
@UseGuards(JwtAuthGuard)
export class MeController {
  @Get()
  me(@CurrentUser() user: AuthenticatedUser) {
    return toSafeUser(user);
  }
}
