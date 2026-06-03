import { SharedMemberRole } from '@prisma/client';
import { IsBoolean, IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateSharedMemberDto {
  @IsString()
  @IsNotEmpty()
  userId!: string;

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
