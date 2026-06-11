import { OtpPurpose } from '@prisma/client';
import { IsEnum, IsNotEmpty, IsString } from 'class-validator';

export class VerifyOtpDto {
  @IsString()
  @IsNotEmpty()
  phone!: string;

  @IsString()
  @IsNotEmpty()
  code!: string;

  @IsEnum(OtpPurpose)
  purpose!: OtpPurpose;
}
