import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

export class RegisterDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  name!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;
}
