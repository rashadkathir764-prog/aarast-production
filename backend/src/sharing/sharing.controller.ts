import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { CurrentUser } from '../auth/current-user.decorator';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CreatePlanInviteDto } from './dto/create-plan-invite.dto';
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

@Controller('api/v1/wedding-plans/:weddingPlanId/members')
@UseGuards(JwtAuthGuard)
export class ApiV1WeddingPlanMembersController {
  constructor(private readonly sharingService: SharingService) {}

  @Get()
  findMembers(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('weddingPlanId') weddingPlanId: string,
  ) {
    return this.sharingService.findMembersForPlan(currentUser, weddingPlanId);
  }

  @Patch(':memberId')
  updateMember(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('weddingPlanId') weddingPlanId: string,
    @Param('memberId') memberId: string,
    @Body() dto: UpdateSharedMemberDto,
  ) {
    return this.sharingService.updateMemberForPlan(
      currentUser,
      weddingPlanId,
      memberId,
      dto,
    );
  }

  @Delete(':memberId')
  removeMember(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('weddingPlanId') weddingPlanId: string,
    @Param('memberId') memberId: string,
  ) {
    return this.sharingService.removeMemberFromPlan(
      currentUser,
      weddingPlanId,
      memberId,
    );
  }
}

@Controller('api/v1/wedding-plans/:weddingPlanId/invites')
@UseGuards(JwtAuthGuard)
export class ApiV1WeddingPlanInvitesController {
  constructor(private readonly sharingService: SharingService) {}

  @Post()
  createInvite(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('weddingPlanId') weddingPlanId: string,
    @Body() dto: CreatePlanInviteDto,
  ) {
    return this.sharingService.createInvite(currentUser, weddingPlanId, dto);
  }

  @Get()
  findInvites(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('weddingPlanId') weddingPlanId: string,
  ) {
    return this.sharingService.findInvitesForPlan(currentUser, weddingPlanId);
  }

  @Delete(':inviteId')
  cancelInvite(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('weddingPlanId') weddingPlanId: string,
    @Param('inviteId') inviteId: string,
  ) {
    return this.sharingService.cancelInvite(
      currentUser,
      weddingPlanId,
      inviteId,
    );
  }
}

@Controller('api/v1/invites')
export class ApiV1InvitesController {
  constructor(private readonly sharingService: SharingService) {}

  @Get(':token')
  getInvite(@Param('token') token: string) {
    return this.sharingService.getInvite(token);
  }
}

@Controller('api/v1/invites')
@UseGuards(JwtAuthGuard)
export class ApiV1InviteAcceptController {
  constructor(private readonly sharingService: SharingService) {}

  @Post(':token/accept')
  acceptInvite(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('token') token: string,
  ) {
    return this.sharingService.acceptInvite(currentUser, token);
  }

  @Post(':token/decline')
  declineInvite(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('token') token: string,
  ) {
    return this.sharingService.declineInvite(currentUser, token);
  }
}

@Controller('api/v1/wedding-plans/:weddingPlanId/permissions')
@UseGuards(JwtAuthGuard)
export class ApiV1WeddingPlanPermissionsController {
  constructor(private readonly sharingService: SharingService) {}

  @Get('me')
  permissionsForMe(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('weddingPlanId') weddingPlanId: string,
  ) {
    return this.sharingService.permissionsForCurrentUser(
      currentUser,
      weddingPlanId,
    );
  }
}
