import { Controller, Get, UseGuards } from "@nestjs/common";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../modules/identity/public/current-user.decorator";
import { JwtAuthGuard } from "../modules/identity/public/jwt-auth.guard";
import { toSafeUser } from "../modules/identity/public/safe-user";

@Controller("api/v1/me")
@UseGuards(JwtAuthGuard)
export class MeController {
  @Get()
  me(@CurrentUser() user: AuthenticatedUser) {
    return toSafeUser(user);
  }
}
