import { WeddingPersona } from '@prisma/client';
import {
  IsEmail,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { MaxCharacters } from '../../../../shared-kernel/text/text-length';

// RA-BE-15: the name is bounded as at sign-up (register.dto.ts) and shown to
// everyone the person plans with; the picture is one of our own uploads
// (checked by the service); the locale is a short code.
export class UpdateProfileDto {
  @IsString()
  @IsOptional()
  @MaxCharacters(120)
  name?: string;

  @IsEmail()
  @IsOptional()
  email?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(2048)
  avatarUrl?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(35)
  locale?: string;

  @IsEnum(WeddingPersona)
  @IsOptional()
  persona?: WeddingPersona | null;
}
