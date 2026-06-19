import { SharedMemberRole } from '@prisma/client';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';

export class CreatePlanInviteDto {
  @IsString()
  @IsNotEmpty()
  @IsOptional()
  userId?: string;

  @IsString()
  @IsNotEmpty()
  @IsOptional()
  phone?: string;

  @IsEnum(SharedMemberRole)
  @IsOptional()
  role?: SharedMemberRole;

  @IsBoolean()
  @IsOptional()
  canViewBudget?: boolean;

  @IsBoolean()
  @IsOptional()
  canViewExpenses?: boolean;

  @IsBoolean()
  @IsOptional()
  canViewDebts?: boolean;

  @IsBoolean()
  @IsOptional()
  canManageTasks?: boolean;

  @IsBoolean()
  @IsOptional()
  canManageFinancialRecords?: boolean;

  @IsInt()
  @Min(1)
  @Max(30)
  @IsOptional()
  expiresInDays?: number;
}
