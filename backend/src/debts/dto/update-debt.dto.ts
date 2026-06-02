import { DebtStatus } from '@prisma/client';
import { IsEnum, IsOptional, IsString } from 'class-validator';

export class UpdateDebtDto {
  @IsString()
  @IsOptional()
  creditorName?: string;

  @IsString()
  @IsOptional()
  title?: string;

  @IsOptional()
  totalAmount?: string | number;

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
