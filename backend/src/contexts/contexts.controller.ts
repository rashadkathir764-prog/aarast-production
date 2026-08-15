import { Body, Controller, Get, Post, UseGuards } from "@nestjs/common";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { ContextsService } from "./contexts.service";
import { ValidateContextDto } from "./dto/validate-context.dto";

@Controller("api/v1/contexts")
@UseGuards(JwtAuthGuard)
export class ContextsController {
  constructor(private readonly contextsService: ContextsService) {}

  @Get()
  list(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.contextsService.list(currentUser);
  }

  @Post("validate")
  validate(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: ValidateContextDto,
  ) {
    return this.contextsService.validate(currentUser, dto.contextKey);
  }
}
