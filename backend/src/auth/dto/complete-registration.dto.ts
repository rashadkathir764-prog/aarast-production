import {
  IsNotEmpty,
  IsString,
  Length,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { MaxUtf8Bytes } from '../../modules/identity/public/max-utf8-bytes.decorator';

// Email is intentionally absent. A phone OTP proves phone ownership only and
// must never be used to probe, claim, or replace an unverified email address.
export class CompleteRegistrationDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  name!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;

  @IsString()
  @MinLength(6)
  @MaxUtf8Bytes(72)
  password!: string;

  @IsString()
  @Length(6, 6)
  @Matches(/^\d{6}$/)
  otpCode!: string;
}
