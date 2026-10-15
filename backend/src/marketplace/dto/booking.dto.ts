import { IsOptional, IsString, Matches, MaxLength } from 'class-validator';

/** The customer asks the provider to reserve a day; the quote's date when omitted. */
export class RequestBookingDto {
  @IsOptional()
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  eventDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string | null;
}

/** Confirm, decline or cancel; the note travels to the other side. */
export class BookingDecisionDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string | null;
}

export class BlockedDateDto {
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  date!: string;
}
