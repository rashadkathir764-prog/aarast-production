import { ParticipantGender, SharedMemberRole } from "@prisma/client";
import { IsBoolean, IsEnum, IsOptional } from "class-validator";

export class UpdateSharedMemberDto {
  @IsEnum(SharedMemberRole)
  @IsOptional()
  role?: SharedMemberRole;

  /**
   * Q-67: how the plan speaks of the participant. Not a right: it moves no
   * authority. Missing keeps what is stored.
   */
  @IsEnum(ParticipantGender)
  @IsOptional()
  gender?: ParticipantGender;

  @IsBoolean()
  @IsOptional()
  canViewMoney?: boolean;

  @IsBoolean()
  @IsOptional()
  canEditPlan?: boolean;

  @IsBoolean()
  @IsOptional()
  canManageTasks?: boolean;

  @IsBoolean()
  @IsOptional()
  canManageGuests?: boolean;

  @IsBoolean()
  @IsOptional()
  canManageProviders?: boolean;

  @IsBoolean()
  @IsOptional()
  canInviteMembers?: boolean;

  @IsBoolean()
  @IsOptional()
  canManageMoney?: boolean;

  @IsBoolean()
  @IsOptional()
  receiveNotifications?: boolean;
}
