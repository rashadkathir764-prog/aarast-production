import { CostPayer } from "@prisma/client";
import {
  IsEnum,
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from "class-validator";

export class UpdateWeddingCostDto {
  @IsString()
  @IsNotEmpty()
  @IsOptional()
  budgetCategoryId?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
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
