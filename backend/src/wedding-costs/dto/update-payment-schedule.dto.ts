import {
  IsISO8601,
  IsObject,
  IsNotEmpty,
  IsOptional,
  IsString,
} from "class-validator";
import { MaxCharacters } from "../../shared-kernel/text/text-length";

export class UpdatePaymentScheduleDto {
  /**
   * RA-MO-344: the value this edit last read of each field it changes. A
   * field changed since is refused (409 CHANGED_ELSEWHERE); omitted, the
   * edit is taken as before.
   */
  @IsObject()
  @IsOptional()
  expected?: Record<string, unknown>;
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
