import { OtpPurpose } from '@prisma/client';
import { IsIn, IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class RequestOtpDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;

  @IsIn([
    OtpPurpose.REGISTER,
    OtpPurpose.LOGIN,
    OtpPurpose.VERIFY_PHONE,
    OtpPurpose.RESET_PASSWORD,
  ])
  purpose!: OtpPurpose;
}
