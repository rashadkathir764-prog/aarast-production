import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreateSharedMemberDto } from './dto/create-shared-member.dto';
import { UpdateSharedMemberDto } from './dto/update-shared-member.dto';
import { SharingService } from './sharing.service';

@Controller('wedding-plans/:weddingPlanId/shared-members')
@UseGuards(JwtAuthGuard)
export class WeddingPlanSharedMembersController {
  constructor(private readonly sharingService: SharingService) {}

  @Post()
  create(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('weddingPlanId') weddingPlanId: string,
    @Body() dto: CreateSharedMemberDto,
  ) {
    return this.sharingService.create(currentUser, weddingPlanId, dto);
  }

  @Get()
  findForPlan(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('weddingPlanId') weddingPlanId: string,
  ) {
    return this.sharingService.findForPlan(currentUser, weddingPlanId);
  }
}

@Controller('shared-members')
@UseGuards(JwtAuthGuard)
export class SharedMembersController {
  constructor(private readonly sharingService: SharingService) {}

  @Patch(':id')
  update(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: UpdateSharedMemberDto,
  ) {
    return this.sharingService.update(currentUser, id, dto);
  }

  @Delete(':id')
  remove(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.sharingService.remove(currentUser, id);
  }
}

@Controller('shared')
@UseGuards(JwtAuthGuard)
export class SharedWeddingPlansController {
  constructor(private readonly sharingService: SharingService) {}

  @Get('wedding-plans')
  findSharedPlans(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.sharingService.findSharedPlans(currentUser);
  }
}
