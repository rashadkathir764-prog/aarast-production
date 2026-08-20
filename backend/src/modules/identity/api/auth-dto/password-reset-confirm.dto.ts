import {
  IsNotEmpty,
  IsString,
  Length,
  Matches,
  MaxLength,
  MinLength,
} from 'class-validator';
import { MaxUtf8Bytes } from '../../public/max-utf8-bytes.decorator';

export class PasswordResetConfirmDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;

  @IsString()
  @IsNotEmpty()
  @Length(6, 6)
  @Matches(/^\d{6}$/)
  code!: string;

  @IsString()
  @MinLength(6)
  @MaxUtf8Bytes(72)
  newPassword!: string;
}
