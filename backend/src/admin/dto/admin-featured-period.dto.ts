import { IsOptional, IsString, Matches, MaxLength } from 'class-validator';

const DAY = /^\d{4}-\d{2}-\d{2}$/;

export class AdminFeaturedPeriodQueryDto {
  /** CURRENT (default), ACTIVE, SCHEDULED, FINISHED or ALL. */
  @IsString()
  @IsOptional()
  state?: string;

  @IsString()
  @IsOptional()
  providerId?: string;

  @IsString()
  @IsOptional()
  page?: string;

  @IsString()
  @IsOptional()
  limit?: string;
}

/**
 * A placement the provider paid for outside the app (B-43). Days are Yemen
 * calendar days; `endsOn` is the last day covered. Without `startsOn` it
 * starts now; `startsOn` is a later day (a renewal booked after the current
 * period). No amount or payment is taken: `note` says how he paid, if the
 * administrator wants it kept.
 */
export class AdminGrantFeaturedPeriodDto {
  @IsString()
  @Matches(DAY)
  endsOn!: string;

  @IsString()
  @IsOptional()
  @Matches(DAY)
  startsOn?: string;

  @IsString()
  @IsOptional()
  @MaxLength(500)
  note?: string;
}

/** Why the placement stops before its end; the provider reads it. */
export class AdminEndFeaturedPeriodDto {
  @IsString()
  @IsOptional()
  @MaxLength(500)
  note?: string;
}
