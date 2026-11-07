import {
  IsBoolean,
  IsInt,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class CreatePlanQuoteRequestDto {
  @IsString()
  @IsNotEmpty()
  providerId!: string;

  @IsString()
  @IsOptional()
  serviceId?: string;

  @IsString()
  @IsOptional()
  eventDate?: string | null;

  @IsObject()
  @IsOptional()
  location?: Record<string, unknown> | null;

  @IsString()
  @IsOptional()
  cityId?: string;

  @IsInt()
  @Min(1)
  @Max(100_000)
  @IsOptional()
  guestCount?: number;

  @IsString()
  @IsOptional()
  message?: string | null;

  @IsString()
  @MaxLength(160)
  @IsOptional()
  contactName?: string | null;

  @IsString()
  @MaxLength(40)
  @IsOptional()
  contactPhone?: string | null;

  @IsString()
  @IsOptional()
  budgetMin?: string | null;

  @IsString()
  @IsOptional()
  budgetMax?: string | null;

  /** B-08: the provider reads the budget only when this is true. */
  @IsBoolean()
  @IsOptional()
  shareBudget?: boolean;

  /** B-08: the provider reads the phone only when this is true. */
  @IsBoolean()
  @IsOptional()
  shareContact?: boolean;
}
