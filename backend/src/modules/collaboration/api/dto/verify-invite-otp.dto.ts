import {
  IsNotEmpty,
  IsOptional,
  IsString,
  Length,
  Matches,
  MaxLength,
  MinLength,
} from "class-validator";
import { MaxCharacters } from "../../../../shared-kernel/text/text-length";
import { MaxUtf8Bytes } from "../../../identity/public/max-utf8-bytes.decorator";

export class VerifyInviteOtpDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;

  @IsString()
  @IsNotEmpty()
  @Length(6, 6)
  @Matches(/^\d{6}$/)
  code!: string;

  @IsOptional()
  @IsString()
  @IsNotEmpty()
  @MaxCharacters(120)
  name?: string;

  @IsOptional()
  @IsString()
  @MinLength(6)
  @MaxUtf8Bytes(72)
  password?: string;
}
