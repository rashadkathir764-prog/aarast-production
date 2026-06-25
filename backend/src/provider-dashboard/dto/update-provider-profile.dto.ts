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
}
