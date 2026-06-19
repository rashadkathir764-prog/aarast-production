import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateQuoteOfferDto {
  @IsString()
  @IsOptional()
  title?: string | null;

  @IsString()
  @IsNotEmpty()
  message!: string;

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
