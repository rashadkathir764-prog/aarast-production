import {
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from "class-validator";

export class CreateWeddingCostDto {
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

  @IsString()
  @MaxLength(2000)
  @IsOptional()
  note?: string | null;
}
