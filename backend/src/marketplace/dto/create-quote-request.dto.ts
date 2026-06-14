import { IsInt, IsOptional, IsString, Min } from 'class-validator';

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
  @IsOptional()
  budgetMin?: string | null;

  @IsString()
  @IsOptional()
  budgetMax?: string | null;
}
