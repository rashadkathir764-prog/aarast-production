import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UseGuards,
} from "@nestjs/common";
import { Request } from "express";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { CurrentUser } from "../auth/current-user.decorator";
import { JwtAuthGuard } from "../auth/jwt-auth.guard";
import { CreatePlanInviteDto } from "./dto/create-plan-invite.dto";
import { CreateSharedMemberDto } from "./dto/create-shared-member.dto";
import { LeavePlanDto } from "./dto/leave-plan.dto";
import { RequestInviteOtpDto } from "./dto/request-invite-otp.dto";
import { VerifyInviteOtpDto } from "./dto/verify-invite-otp.dto";
import { UpdateSharedMemberDto } from "./dto/update-shared-member.dto";
import { InviteAccessService } from "./invite-access.service";
import { SharingService } from "./sharing.service";

@Controller("api/v1/invites")
export class ApiV1InviteAccessController {
  constructor(private readonly inviteAccess: InviteAccessService) {}

  @Post(":token/request-otp")
  requestOtp(
    @Param("token") token: string,
    @Body() dto: RequestInviteOtpDto,
    @Req() request: Request,
  ) {
    return this.inviteAccess.requestOtp(token, dto, { ip: request.ip });
  }

  @Post(":token/verify-otp")
  verifyOtp(@Param("token") token: string, @Body() dto: VerifyInviteOtpDto) {
    return this.inviteAccess.verifyOtp(token, dto);
  }
}

@Controller("api/v1/shared")
@UseGuards(JwtAuthGuard)
export class SharedWeddingPlansController {
  constructor(private readonly sharingService: SharingService) {}

  @Get("wedding-plans")
  findSharedPlans(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.sharingService.findSharedPlans(currentUser);
  }
}

@Controller("api/v1/wedding-plans/:weddingPlanId/members")
@UseGuards(JwtAuthGuard)
export class ApiV1WeddingPlanMembersController {
  constructor(private readonly sharingService: SharingService) {}

  @Post()
  createMember(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Body() dto: CreateSharedMemberDto,
  ) {
    return this.sharingService.create(currentUser, weddingPlanId, dto);
  }

  @Get()
  findMembers(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
  ) {
    return this.sharingService.findMembersForPlan(currentUser, weddingPlanId);
  }

  @Delete("me")
  leavePlan(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Body() dto: LeavePlanDto,
  ) {
    return this.sharingService.leaveCurrentMemberFromPlan(
      currentUser,
      weddingPlanId,
      dto,
    );
  }

  @Patch(":memberId")
  updateMember(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Param("memberId") memberId: string,
    @Body() dto: UpdateSharedMemberDto,
  ) {
    return this.sharingService.updateMemberForPlan(
      currentUser,
      weddingPlanId,
      memberId,
      dto,
    );
  }

  @Delete(":memberId")
  removeMember(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Param("memberId") memberId: string,
  ) {
    return this.sharingService.removeMemberFromPlan(
      currentUser,
      weddingPlanId,
      memberId,
    );
  }
}

@Controller("api/v1/wedding-plans/:weddingPlanId/invites")
@UseGuards(JwtAuthGuard)
export class ApiV1WeddingPlanInvitesController {
  constructor(private readonly sharingService: SharingService) {}

  @Post()
  createInvite(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Body() dto: CreatePlanInviteDto,
  ) {
    return this.sharingService.createInvite(currentUser, weddingPlanId, dto);
  }

  @Get()
  findInvites(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
  ) {
    return this.sharingService.findInvitesForPlan(currentUser, weddingPlanId);
  }

  @Delete(":inviteId")
  cancelInvite(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Param("inviteId") inviteId: string,
  ) {
    return this.sharingService.cancelInvite(
      currentUser,
      weddingPlanId,
      inviteId,
    );
  }

  @Post(":inviteId/reissue")
  reissueInvite(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
    @Param("inviteId") inviteId: string,
    @Body() dto: UpdateSharedMemberDto,
  ) {
    return this.sharingService.reissueInvite(
      currentUser,
      weddingPlanId,
      inviteId,
      dto,
    );
  }
}

@Controller("api/v1/invites")
@UseGuards(JwtAuthGuard)
export class ApiV1InvitesController {
  constructor(private readonly sharingService: SharingService) {}

  @Get("mine")
  findMyInvites(@CurrentUser() currentUser: AuthenticatedUser) {
    return this.sharingService.findInvitesForCurrentUser(currentUser);
  }

  @Get(":token")
  getInvite(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("token") token: string,
  ) {
    return this.sharingService.getInviteForCurrentUser(currentUser, token);
  }
}

@Controller("api/v1/invites")
@UseGuards(JwtAuthGuard)
export class ApiV1InviteAcceptController {
  constructor(private readonly sharingService: SharingService) {}

  @Post(":token/accept")
  acceptInvite(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("token") token: string,
  ) {
    return this.sharingService.acceptInvite(currentUser, token);
  }

  @Post(":token/decline")
  declineInvite(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("token") token: string,
  ) {
    return this.sharingService.declineInvite(currentUser, token);
  }
}

@Controller("api/v1/wedding-plans/:weddingPlanId/permissions")
@UseGuards(JwtAuthGuard)
export class ApiV1WeddingPlanPermissionsController {
  constructor(private readonly sharingService: SharingService) {}

  @Get("me")
  permissionsForMe(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param("weddingPlanId") weddingPlanId: string,
  ) {
    return this.sharingService.permissionsForCurrentUser(
      currentUser,
      weddingPlanId,
    );
  }
}
