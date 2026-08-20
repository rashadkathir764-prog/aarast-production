import { IsNotEmpty, IsString, MaxLength } from 'class-validator';
import { MaxUtf8Bytes } from '../../public/max-utf8-bytes.decorator';

export class LoginDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;

  @IsString()
  @IsNotEmpty()
  @MaxUtf8Bytes(72)
  password!: string;
}
