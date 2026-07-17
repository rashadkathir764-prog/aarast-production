import {
  IsNotEmpty,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';
import { MaxUtf8Bytes } from './max-utf8-bytes.decorator';

export class PasswordResetConfirmDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;

  @IsString()
  @IsNotEmpty()
  code!: string;

  @IsString()
  @MinLength(6)
  @MaxUtf8Bytes(72)
  newPassword!: string;
}
