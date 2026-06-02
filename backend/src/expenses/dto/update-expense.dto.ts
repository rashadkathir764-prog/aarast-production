import { ExpenseStatus } from '@prisma/client';
import { IsEnum, IsOptional, IsString } from 'class-validator';

export class UpdateExpenseDto {
  @IsString()
  @IsOptional()
  title?: string;

  @IsOptional()
  amount?: string | number;

  @IsString()
  @IsOptional()
  budgetCategoryId?: string | null;

  @IsEnum(ExpenseStatus)
  @IsOptional()
  status?: ExpenseStatus;

  @IsString()
  @IsOptional()
  expenseDate?: string | null;

  @IsString()
  @IsOptional()
  note?: string | null;
}