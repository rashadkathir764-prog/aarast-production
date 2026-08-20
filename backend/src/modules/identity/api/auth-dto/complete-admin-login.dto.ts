import { IsNotEmpty, IsString, Length, Matches } from 'class-validator';

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
}
