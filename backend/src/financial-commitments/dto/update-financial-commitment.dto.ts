import {
  FinancialCommitmentSourceType,
  FinancialCommitmentStatus,
} from "@prisma/client";
import { IsEnum, IsOptional, IsString, MaxLength } from "class-validator";

export class UpdateFinancialCommitmentDto {
  @IsString()
  @IsOptional()
  budgetCategoryId?: string;

  @IsEnum(FinancialCommitmentSourceType)
  @IsOptional()
  sourceType?: FinancialCommitmentSourceType;

  @IsString()
  @IsOptional()
  providerId?: string | null;

  @IsString()
  @IsOptional()
  planProviderLinkId?: string | null;

  @IsString()
  @IsOptional()
  quoteRequestId?: string | null;

  @IsString()
  @IsOptional()
  quoteOfferId?: string | null;

  @IsString()
  @IsOptional()
  title?: string;

  @IsString()
  @IsOptional()
  partyName?: string | null;

  @IsString()
  @MaxLength(40)
  @IsOptional()
  partyPhone?: string | null;

  @IsOptional()
  totalAmount?: string | number;

  @IsString()
  @IsOptional()
  dueDate?: string | null;

  @IsString()
  @IsOptional()
  agreementDate?: string | null;

  @IsEnum(FinancialCommitmentStatus)
  @IsOptional()
  status?: FinancialCommitmentStatus;

  @IsString()
  @IsOptional()
  note?: string | null;
}
