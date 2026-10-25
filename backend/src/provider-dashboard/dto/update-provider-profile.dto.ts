import { IsEmail, IsOptional, IsString, MaxLength } from 'class-validator';

export class UpdateProviderProfileDto {
  @IsString()
  @IsOptional()
  businessName?: string;

  @IsString()
  @IsOptional()
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
  description?: string | null;

  @IsString()
  @IsOptional()
  address?: string | null;

  @IsString()
  @IsOptional()
  cityId?: string;

  @IsString()
  @IsOptional()
  latitude?: string | null;

  @IsString()
  @IsOptional()
  longitude?: string | null;

  @IsString()
  @IsOptional()
  logoUrl?: string | null;

  @IsString()
  @IsOptional()
  coverUrl?: string | null;

  /**
   * The profile's category, changeable only before approval (PENDING or
   * NEEDS_CHANGES), when the review team may ask for it (B-01); the joining
   * services follow it. After approval a change goes through review (B-39).
   */
  @IsString()
  @IsOptional()
  primaryCategoryId?: string;
}
