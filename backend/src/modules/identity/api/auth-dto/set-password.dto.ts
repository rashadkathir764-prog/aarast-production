import { IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';
import { MaxUtf8Bytes } from '../../public/max-utf8-bytes.decorator';

/**
 * `POST /auth/password`: add the app password, or change it. Changing needs
 * the current one; an account without a password (D75) only sends the new.
 */
export class SetPasswordDto {
  @IsString()
  @MinLength(6)
  @MaxUtf8Bytes(72)
  newPassword!: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxUtf8Bytes(72)
  currentPassword?: string;
}
