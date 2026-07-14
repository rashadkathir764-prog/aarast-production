import { SharedMemberRole } from "@prisma/client";
import { IsBoolean, IsEnum, IsOptional } from "class-validator";

export class UpdateSharedMemberDto {
  @IsEnum(SharedMemberRole)
  @IsOptional()
  role?: SharedMemberRole;

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
