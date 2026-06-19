import { IsOptional, IsString } from 'class-validator';

export class UpdateQuoteOfferDto {
  @IsString()
  @IsOptional()
  title?: string | null;

  @IsString()
  @IsOptional()
  message?: string | null;

  @IsString()
  @IsOptional()
  amount?: string | null;

  @IsString()
  @IsOptional()
  currency?: string;

  @IsString()
  @IsOptional()
  validUntil?: string | null;
}
