import { CostEntryKind, CostPayer, EstimateCover } from "@prisma/client";
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
  @MaxCharacters(160)
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

  /** Who is expected to pay this cost. */
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

  /**
   * D107: EXPENSE is money paid in full the day it is recorded (its first
   * payment is the whole amount). Omitted: an agreement.
   */
  @IsEnum(CostEntryKind)
  @IsOptional()
  entryKind?: CostEntryKind;

  /**
   * D105: what it settles of its item's estimate. Omitted: the whole item
   * for an agreement, a part at its own value for an expense.
   */
  @IsEnum(EstimateCover)
  @IsOptional()
  estimateCover?: EstimateCover;

  /** D105: with PART, how much of the estimate it settles (default: its own amount). */
  @IsOptional()
  estimatePart?: string | number | null;
}
