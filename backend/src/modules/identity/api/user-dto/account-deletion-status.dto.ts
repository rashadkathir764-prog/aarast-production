import { IsString, Matches, MaxLength } from "class-validator";

const SAFE_OPAQUE_ID = /^[A-Za-z0-9][A-Za-z0-9._:-]*$/;

export class AccountDeletionStatusDto {
  @IsString()
  @MaxLength(128)
  @Matches(SAFE_OPAQUE_ID)
  userId!: string;

  @IsString()
  @MaxLength(128)
  @Matches(SAFE_OPAQUE_ID)
  clientRequestId!: string;
}
