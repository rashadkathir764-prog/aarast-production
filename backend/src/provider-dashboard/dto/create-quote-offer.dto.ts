import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateQuoteOfferDto {
  @IsString()
  @IsOptional()
  title?: string | null;

  @IsString()
  @IsNotEmpty()
  message!: string;

  @IsString()
  @IsNotEmpty()
  amount!: string;

  @IsString()
  @IsOptional()
  currency?: string;

  @IsString()
  @IsOptional()
  validUntil?: string | null;
}
