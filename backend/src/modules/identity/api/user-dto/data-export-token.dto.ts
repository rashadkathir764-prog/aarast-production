import { IsString, Matches } from "class-validator";

/** D63: a download link's token (32 random bytes, base64url). */
export class DataExportTokenDto {
  @IsString()
  @Matches(/^[A-Za-z0-9_-]{43}$/)
  token!: string;
}
