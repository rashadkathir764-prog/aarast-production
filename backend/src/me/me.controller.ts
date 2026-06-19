import { Controller, Get, UseGuards } from '@nestjs/common';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { toSafeUser } from '../auth/safe-user';

@Controller('me')
@UseGuards(JwtAuthGuard)
export class MeController {
  @Get()
  me(@CurrentUser() user: AuthenticatedUser) {
    return toSafeUser(user);
  }
}

@Controller('api/v1/me')
@UseGuards(JwtAuthGuard)
export class ApiV1MeController {
  @Get()
  me(@CurrentUser() user: AuthenticatedUser) {
    return toSafeUser(user);
  }
}
