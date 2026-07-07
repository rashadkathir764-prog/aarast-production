import {
  FinancialCommitmentSourceType,
  FinancialCommitmentStatus,
} from "@prisma/client";
import {
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from "class-validator";

export class CreateFinancialCommitmentDto {
  @IsString()
  @IsNotEmpty()
  budgetCategoryId!: string;

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
  @IsNotEmpty()
  title!: string;

  @IsString()
  @IsOptional()
  partyName?: string | null;

  @IsString()
  @MaxLength(40)
  @IsOptional()
  partyPhone?: string | null;

  @IsNotEmpty()
  totalAmount!: string | number;

  @IsOptional()
  paidAmount?: string | number;

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
