import { AppRole, WeddingPersona } from '@prisma/client';
import { IsEmail, IsEnum, IsOptional, IsString } from 'class-validator';

export class UpdateProfileDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsEmail()
  @IsOptional()
  email?: string | null;

  @IsString()
  @IsOptional()
  avatarUrl?: string | null;

  @IsString()
  @IsOptional()
  locale?: string;

  @IsEnum(AppRole)
  @IsOptional()
  appRole?: AppRole;

  @IsEnum(WeddingPersona)
  @IsOptional()
  persona?: WeddingPersona | null;
}
