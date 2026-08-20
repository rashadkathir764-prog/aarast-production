import { OtpPurpose } from '@prisma/client';
import {
  IsIn,
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

  @IsIn([OtpPurpose.LOGIN, OtpPurpose.VERIFY_PHONE])
  purpose!: OtpPurpose;
}
