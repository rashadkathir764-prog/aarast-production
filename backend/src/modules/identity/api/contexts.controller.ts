import { Body, Controller, Get, Post, UseGuards } from "@nestjs/common";
import { AuthenticatedUser } from "../public/identity-session.types";
import { CurrentUser } from "../public/current-user.decorator";
import { JwtAuthGuard } from "../public/jwt-auth.guard";
import { ContextsService } from "../internal/profile/contexts.service";
import { ValidateContextDto } from "./context-dto/validate-context.dto";

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
