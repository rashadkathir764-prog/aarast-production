import {
  IsNotEmpty,
  IsOptional,
  IsString,
  Length,
  Matches,
  MaxLength,
} from "class-validator";
import { MaxUtf8Bytes } from "../../public/max-utf8-bytes.decorator";

/** V1 checklist 4.14: the number the account moves to. */
export class RequestPhoneChangeDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;
}

export class ConfirmPhoneChangeDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(12)
  code!: string;

  // RA-BE-141: one of the two proofs that the account's holder asks, beside
  // the new number's code: the code sent to the current number
  // (`phone-change/current-code`), or the account's password.
  @IsOptional()
  @IsString()
  @Length(6, 6)
  @Matches(/^\d{6}$/)
  currentCode?: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxUtf8Bytes(72)
  currentPassword?: string;
}
