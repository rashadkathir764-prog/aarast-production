import { IsArray, IsInt, Max, Min, IsNotEmpty, IsOptional, IsString } from 'class-validator';

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

  /** B-07: `[{ label, kind: INCLUDED|EXCLUDED|EXTRA, amount? }]`; checked by the service. */
  @IsOptional()
  @IsArray()
  lines?: unknown[] | null;

  /** B-07/B-23: days after the wedding to deliver (photos, video…). */
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(365)
  deliveryDays?: number | null;
}
