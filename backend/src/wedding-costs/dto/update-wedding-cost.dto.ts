import { CostPayer, EstimateCover } from "@prisma/client";
import {
  IsBoolean,
  IsEnum,
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from "class-validator";
import { MaxCharacters } from "../../shared-kernel/text/text-length";

export class UpdateWeddingCostDto {
  /** V1 checklist 4.10: false shares a private cost with the plan; a shared cost never becomes private. */
  @IsBoolean()
  @IsOptional()
  isPrivate?: boolean;

  @IsString()
  @IsNotEmpty()
  @IsOptional()
  budgetCategoryId?: string;

  @IsString()
  @IsNotEmpty()
  @MaxCharacters(160)
  @IsOptional()
  title?: string;

  @IsOptional()
  totalAmount?: string | number;

  @IsString()
  @IsOptional()
  providerId?: string | null;

  @IsString()
  @IsOptional()
  quoteOfferId?: string | null;

  @IsString()
  @MaxCharacters(160)
  @IsOptional()
  partyName?: string | null;

  @IsString()
  @MaxLength(40)
  @IsOptional()
  partyPhone?: string | null;

  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  agreementDate?: string | null;

  @IsEnum(CostPayer)
  @IsOptional()
  payer?: CostPayer | null;

  @IsString()
  @MaxCharacters(120)
  @IsOptional()
  payerName?: string | null;

  @IsString()
  @MaxCharacters(2000)
  @IsOptional()
  note?: string | null;

  /** D105: what it settles of its item's estimate. */
  @IsEnum(EstimateCover)
  @IsOptional()
  estimateCover?: EstimateCover;

  /** D105: with PART, how much of the estimate it settles. */
  @IsOptional()
  estimatePart?: string | number | null;
}
