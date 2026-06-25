import {
  IsInt,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateQuoteRequestDto {
  @IsString()
  @IsOptional()
  weddingPlanId?: string;

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
}
