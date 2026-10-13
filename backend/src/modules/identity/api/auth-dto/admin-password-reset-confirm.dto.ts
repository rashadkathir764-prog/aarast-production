import { IsString, Length, Matches, MinLength } from 'class-validator';
import { MaxUtf8Bytes } from '../../public/max-utf8-bytes.decorator';

/** Step 2 of admin recovery: the new password, after the code was verified. */
export class AdminPasswordResetConfirmDto {
  @IsString()
  @Length(64, 64)
  @Matches(/^[a-f0-9]{64}$/)
  challengeToken!: string;

  // Same rule as application passwords: any characters, 6 or more. Admin
  // sign-in always asks for a WhatsApp code as well.
  @IsString()
  @MinLength(6)
  @MaxUtf8Bytes(72)
  newPassword!: string;
}
