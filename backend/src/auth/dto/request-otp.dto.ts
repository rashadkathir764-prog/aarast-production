import { OtpPurpose } from '@prisma/client';
import { IsEnum, IsNotEmpty, IsString } from 'class-validator';

export class RequestOtpDto {
  @IsString()
  @IsNotEmpty()
  phone!: string;

  @IsEnum(OtpPurpose)
  purpose!: OtpPurpose;
}
