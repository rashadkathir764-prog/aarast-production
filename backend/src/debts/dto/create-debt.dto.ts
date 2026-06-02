import { DebtStatus } from '@prisma/client';
import { IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateDebtDto {
  @IsString()
  @IsNotEmpty()
  creditorName!: string;

  @IsString()
  @IsNotEmpty()
  title!: string;

  @IsNotEmpty()
  totalAmount!: string | number;

  @IsOptional()
  paidAmount?: string | number;

  @IsString()
  @IsOptional()
  dueDate?: string | null;

  @IsEnum(DebtStatus)
  @IsOptional()
  status?: DebtStatus;

  @IsString()
  @IsOptional()
  note?: string | null;
}
