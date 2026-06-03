import { SharedMemberRole } from '@prisma/client';
import { IsBoolean, IsEnum, IsOptional } from 'class-validator';

export class UpdateSharedMemberDto {
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
}
