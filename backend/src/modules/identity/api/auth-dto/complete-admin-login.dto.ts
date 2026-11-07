import { IsBoolean, IsNotEmpty, IsOptional, IsString, Length, Matches } from 'class-validator';

export class CompleteAdminLoginDto {
  @IsString()
  @IsNotEmpty()
  @Length(64, 64)
  @Matches(/^[a-f0-9]{64}$/)
  challengeToken!: string;

  @IsString()
  @IsNotEmpty()
  @Length(6, 6)
  @Matches(/^\d{6}$/)
  code!: string;

  /**
   * RA-AD-11 (D97): remember this browser for 30 days, so the password alone
   * signs in. Only when the admin asks: on a shared computer the WhatsApp
   * code is the second key.
   */
  @IsOptional()
  @IsBoolean()
  rememberDevice?: boolean;
}
