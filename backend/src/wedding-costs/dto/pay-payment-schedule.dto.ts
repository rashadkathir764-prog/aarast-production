import { IsISO8601, IsOptional, IsString } from "class-validator";
import { MaxCharacters } from "../../shared-kernel/text/text-length";

export class PayPaymentScheduleDto {
  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  paidAt?: string | null;

  @IsString()
  @MaxCharacters(80)
  @IsOptional()
  method?: string | null;

  @IsString()
  @MaxCharacters(1000)
  @IsOptional()
  note?: string | null;
}
