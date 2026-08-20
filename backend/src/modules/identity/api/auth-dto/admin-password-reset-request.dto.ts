import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class AdminPasswordResetRequestDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;
}
