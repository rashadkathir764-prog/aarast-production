import {
  IsNotEmpty,
  IsOptional,
  IsString,
  Length,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { MaxCharacters } from '../../../../shared-kernel/text/text-length';
import { MaxUtf8Bytes } from '../../public/max-utf8-bytes.decorator';

// Email is intentionally absent. A phone OTP proves phone ownership only and
// must never be used to probe, claim, or replace an unverified email address.
export class CompleteRegistrationDto {
  @IsString()
  @IsNotEmpty()
  @MaxCharacters(120)
  name!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;

  // Sign-up is phone + code; a password can be added later (POST /auth/password).
  @IsOptional()
  @IsString()
  @MinLength(6)
  @MaxUtf8Bytes(72)
  password?: string;

  // The phone is proven by exactly one of these: a REGISTER code, or the
  // `phoneProof` a LOGIN code for a number without an account answered with.
  @IsOptional()
  @IsString()
  @Length(6, 6)
  @Matches(/^\d{6}$/)
  otpCode?: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxLength(2048)
  phoneProof?: string;
}
