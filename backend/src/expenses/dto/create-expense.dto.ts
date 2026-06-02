import { ExpenseStatus } from '@prisma/client';
import { IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateExpenseDto {
  @IsString()
  @IsNotEmpty()
  title!: string;

  @IsNotEmpty()
  amount!: string | number;

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