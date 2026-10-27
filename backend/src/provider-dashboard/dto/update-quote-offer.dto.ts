import { IsArray, IsInt, Max, Min, IsOptional, IsString } from 'class-validator';

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
