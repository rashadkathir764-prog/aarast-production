import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateGuestDto } from './dto/create-guest.dto';
import { UpdateGuestDto } from './dto/update-guest.dto';
import { GuestsService } from './guests.service';

@Controller('wedding-plans/:weddingPlanId/guests')
@UseGuards(JwtAuthGuard)
export class WeddingPlanGuestsController {
  constructor(private readonly guestsService: GuestsService) {}

  @Get()
  findForPlan(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('weddingPlanId') weddingPlanId: string,
  ) {
    return this.guestsService.findForPlan(currentUser, weddingPlanId);
  }

  @Post()
  create(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('weddingPlanId') weddingPlanId: string,
    @Body() dto: CreateGuestDto,
  ) {
    return this.guestsService.create(currentUser, weddingPlanId, dto);
  }
}

@Controller('guests')
@UseGuards(JwtAuthGuard)
export class GuestsController {
  constructor(private readonly guestsService: GuestsService) {}

  @Patch(':id')
  update(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: UpdateGuestDto,
  ) {
    return this.guestsService.update(currentUser, id, dto);
  }

  @Delete(':id')
  remove(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.guestsService.remove(currentUser, id);
  }
}
