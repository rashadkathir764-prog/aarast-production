import { IsString, Length, Matches } from 'class-validator';
import { RegisterDto } from './register.dto';

export class CompleteRegistrationDto extends RegisterDto {
  @IsString()
  @Length(6, 6)
  @Matches(/^\d{6}$/)
  otpCode!: string;
}
