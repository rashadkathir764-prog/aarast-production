import { IsString, Length, Matches, MaxLength, MinLength } from 'class-validator';
import { MaxUtf8Bytes } from './max-utf8-bytes.decorator';

export class AdminPasswordResetConfirmDto {
  @IsString()
  @Length(64, 64)
  @Matches(/^[a-f0-9]{64}$/)
  challengeToken!: string;

  @IsString()
  @Length(6, 6)
  @Matches(/^\d{6}$/)
  code!: string;

  @IsString()
  @MinLength(12)
  @MaxLength(72)
  @MaxUtf8Bytes(72)
  @Matches(/[A-Za-z]/)
  @Matches(/\d/)
  newPassword!: string;
}
