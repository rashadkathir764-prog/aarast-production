import {
  IsNotEmpty,
  IsOptional,
  IsString,
  Length,
  Matches,
  MinLength,
} from 'class-validator';
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

  /**
   * RA-BE-133: this phone's push registration (its FID, as
   * `PUT /push/installations/current` takes it). A change signs every other
   * phone out and lets go of their push registrations; the one named here
   * stays. Without it, this phone's registration goes too and comes back
   * the next time the app registers.
   */
  @IsOptional()
  @IsString()
  @Length(10, 200)
  @Matches(/^[A-Za-z0-9_-]+$/)
  pushInstallationId?: string;
}
