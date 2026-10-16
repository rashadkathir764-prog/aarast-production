import { CostPayer } from "@prisma/client";
import {
  IsBoolean,
  IsEnum,
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from "class-validator";

export class CreateWeddingCostDto {
  /** V1 checklist 4.10: only the owner or the partner records a private cost (seen by them alone). */
  @IsBoolean()
  @IsOptional()
  isPrivate?: boolean;

  @IsString()
  @IsNotEmpty()
  budgetCategoryId!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  title!: string;

  @IsNotEmpty()
  totalAmount!: string | number;

  @IsOptional()
  initialPaymentAmount?: string | number | null;

  @IsString()
  @IsOptional()
  providerId?: string | null;

  @IsString()
  @IsOptional()
  quoteOfferId?: string | null;

  @IsString()
  @MaxLength(160)
  @IsOptional()
  partyName?: string | null;

  @IsString()
  @MaxLength(40)
  @IsOptional()
  partyPhone?: string | null;

  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  agreementDate?: string | null;

  /** Who is expected to pay this cost. */
  @IsEnum(CostPayer)
  @IsOptional()
  payer?: CostPayer | null;

  @IsString()
  @MaxLength(120)
  @IsOptional()
  payerName?: string | null;

  @IsString()
  @MaxLength(2000)
  @IsOptional()
  note?: string | null;
}
