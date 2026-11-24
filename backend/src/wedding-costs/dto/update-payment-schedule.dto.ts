import {
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
} from "class-validator";
import { MaxCharacters } from "../../shared-kernel/text/text-length";

export class UpdatePaymentScheduleDto {
  /**
   * RA-MO-344: the row's `updatedAt` this edit was made from. A row changed
   * since is refused (409 CHANGED_ELSEWHERE); omitted, the edit is taken.
   */
  @IsISO8601()
  @IsOptional()
  expectedVersion?: string;
  @IsNotEmpty()
  @IsOptional()
  amount?: string | number;

  @IsISO8601({ strict: true, strictSeparator: true })
  @IsNotEmpty()
  @IsOptional()
  dueDate?: string;

  @IsString()
  @MaxCharacters(1000)
  @IsOptional()
  note?: string | null;

  /**
   * D106: the day to remind on, between today and the due day; null goes
   * back to the default (the week before, and when late).
   */
  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  remindAt?: string | null;
}
