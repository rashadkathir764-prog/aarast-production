import { SharedMemberRole } from "@prisma/client";
import {
  IsBoolean,
  IsEmail,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from "class-validator";
import { MaxCharacters } from "../../../../shared-kernel/text/text-length";

export class CreatePlanInviteDto {
  @IsString()
  @MaxCharacters(160)
  @IsOptional()
  name?: string;

  @IsString()
  @IsNotEmpty()
  @IsOptional()
  userId?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  @IsOptional()
  phone?: string;

  @IsEmail()
  @IsOptional()
  email?: string;

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

  @IsInt()
  @Min(1)
  @Max(30)
  @IsOptional()
  expiresInDays?: number;
}
