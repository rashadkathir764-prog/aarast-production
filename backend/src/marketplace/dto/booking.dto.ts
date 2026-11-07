import { IsIn, IsOptional, IsString, Matches, MaxLength } from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';
import { BOOKING_NOT_HAPPENED_REASONS } from '../booking-aftercare';

/** The customer asks the provider to reserve a day; the quote's date when omitted. */
export class RequestBookingDto {
  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  eventDate?: string;

  @IsOptional()
  @IsString()
  @MaxCharacters(500)
  note?: string | null;
}

/** Confirm, decline or cancel; the note travels to the other side. */
export class BookingDecisionDto {
  @IsOptional()
  @IsString()
  @MaxCharacters(500)
  note?: string | null;
}

export class BlockedDateDto {
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  date!: string;
}

/** B-22: «ما صار» and why. */
export class BookingNotHappenedDto {
  @IsIn(BOOKING_NOT_HAPPENED_REASONS)
  reason!: (typeof BOOKING_NOT_HAPPENED_REASONS)[number];
}

/** B-23: the provider's delivery: a download link and a note, both optional. */
export class BookingDeliveryDto {
  @IsOptional()
  @IsString()
  @MaxLength(1000)
  @Matches(/^https?:\/\/\S+$/i, { message: 'الرابط يبدأ بـ http' })
  link?: string | null;

  @IsOptional()
  @IsString()
  @MaxCharacters(500)
  note?: string | null;
}

/** B-24: the customer moves a confirmed booking to another day. */
export class BookingChangeDto {
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  eventDate!: string;

  @IsOptional()
  @IsString()
  @MaxCharacters(500)
  note?: string | null;
}

/** B-24: why the provider cannot take the new day. */
export class BookingChangeDecisionDto {
  @IsOptional()
  @IsString()
  @MaxCharacters(500)
  reason?: string | null;
}
