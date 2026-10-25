import { IsOptional, IsString } from 'class-validator';

/** a12 (B-40): filters of the read-only bookings list. Days are `YYYY-MM-DD`. */
export class AdminBookingQueryDto {
  @IsString()
  @IsOptional()
  providerId?: string;

  /** REQUESTED, CONFIRMED, DECLINED, CANCELLED or EXPIRED. */
  @IsString()
  @IsOptional()
  status?: string;

  @IsString()
  @IsOptional()
  from?: string;

  @IsString()
  @IsOptional()
  to?: string;

  @IsString()
  @IsOptional()
  page?: string;

  @IsString()
  @IsOptional()
  limit?: string;
}
