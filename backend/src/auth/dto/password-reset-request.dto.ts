import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class PasswordResetRequestDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;
}
