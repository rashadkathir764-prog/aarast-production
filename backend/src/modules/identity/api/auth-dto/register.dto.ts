import { IsNotEmpty, IsString, MaxLength } from 'class-validator';
import { MaxCharacters } from '../../../../shared-kernel/text/text-length';

export class RegisterDto {
  @IsString()
  @IsNotEmpty()
  @MaxCharacters(120)
  name!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;
}
