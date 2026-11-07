import {
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
} from "class-validator";
import { MaxCharacters } from "../../shared-kernel/text/text-length";

export class UpdatePaymentScheduleDto {
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
}
