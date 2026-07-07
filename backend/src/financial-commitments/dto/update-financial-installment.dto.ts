import { InstallmentStatus } from "@prisma/client";
import { IsEnum, IsOptional, IsString } from "class-validator";

export class UpdateFinancialInstallmentDto {
  @IsOptional()
  amount?: string | number;

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
