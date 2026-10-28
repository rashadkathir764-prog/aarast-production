import { IsBoolean } from "class-validator";

/** D63 (w40): the privacy choices the account keeps on the server. */
export class UpdatePrivacyDto {
  @IsBoolean()
  reviewFirstNameOnly!: boolean;
}
