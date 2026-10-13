import { IsString, Length, Matches } from 'class-validator';

/** Step 1 of admin recovery: prove the WhatsApp code. */
export class AdminPasswordResetVerifyDto {
  @IsString()
  @Length(64, 64)
  @Matches(/^[a-f0-9]{64}$/)
  challengeToken!: string;

  @IsString()
  @Length(6, 6)
  @Matches(/^\d{6}$/)
  code!: string;
}
