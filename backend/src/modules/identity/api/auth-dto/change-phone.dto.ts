import { IsNotEmpty, IsString, MaxLength } from "class-validator";

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
}
