import { IsEmail, IsOptional, IsString } from 'class-validator';

export class UpdateProviderProfileDto {
  @IsString()
  @IsOptional()
  businessName?: string;

  @IsString()
  @IsOptional()
  ownerName?: string | null;

  @IsString()
  @IsOptional()
  phone?: string;

  @IsString()
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
