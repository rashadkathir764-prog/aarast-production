import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class RequestInviteOtpDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;
}
