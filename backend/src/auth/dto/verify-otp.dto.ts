import { OtpPurpose } from '@prisma/client';
import {
  IsEnum,
  IsNotEmpty,
  IsString,
  Length,
  Matches,
  MaxLength,
} from 'class-validator';

export class VerifyOtpDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;

  @IsString()
  @IsNotEmpty()
  @Length(6, 6)
  @Matches(/^\d{6}$/)
  code!: string;

  @IsEnum(OtpPurpose)
  purpose!: OtpPurpose;
}
