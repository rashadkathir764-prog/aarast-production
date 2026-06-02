import { InstallmentStatus } from '@prisma/client';
import { IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateInstallmentDto {
  @IsNotEmpty()
  amount!: string | number;

  @IsString()
  @IsOptional()
  dueDate?: string | null;

  @IsString()
  @IsOptional()
  paidAt?: string | null;

  @IsEnum(InstallmentStatus)
  @IsOptional()
  status?: InstallmentStatus;

  @IsString()
  @IsOptional()
  note?: string | null;
}
