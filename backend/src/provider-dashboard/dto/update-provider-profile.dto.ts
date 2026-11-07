import {
  IsEmail,
  IsInt,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

// RA-BE-15: what every customer reads of a provider has a bound, above the
// phone's fields (the about stops at 280 there); the pictures are our own
// uploads (checked by the service), the coordinates numbers.
export class UpdateProviderProfileDto {
  @IsString()
  @IsOptional()
  @MaxCharacters(160)
  businessName?: string;

  @IsString()
  @IsOptional()
  @MaxCharacters(120)
  ownerName?: string | null;

  @IsString()
  @MaxLength(40)
  @IsOptional()
  phone?: string;

  @IsString()
  @MaxLength(40)
  @IsOptional()
  whatsapp?: string | null;

  @IsEmail()
  @IsOptional()
  email?: string | null;

  @IsString()
  @IsOptional()
  @MaxCharacters(2000)
  description?: string | null;

  @IsString()
  @IsOptional()
  @MaxCharacters(300)
  address?: string | null;

  @IsString()
  @IsOptional()
  cityId?: string;

  @IsString()
  @IsOptional()
  @MaxLength(32)
  latitude?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(32)
  longitude?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(2048)
  logoUrl?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(2048)
  coverUrl?: string | null;

  /**
   * The profile's category, changeable only before approval (PENDING or
   * NEEDS_CHANGES), when the review team may ask for it (B-01); the joining
   * services follow it. After approval a change goes through review (B-39).
   */
  @IsString()
  @IsOptional()
  primaryCategoryId?: string;

  /**
   * B-20: how many weddings he takes on one day, 1 to 20. Lowering it below
   * a day's confirmed bookings keeps them and refuses the next confirm.
   */
  @IsInt()
  @Min(1)
  @Max(20)
  @IsOptional()
  dailyBookingCapacity?: number;
}
