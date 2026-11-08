import { IsISO8601, IsOptional, IsString } from "class-validator";
import { MaxCharacters } from "../../shared-kernel/text/text-length";

export class PayPaymentScheduleDto {
  /**
   * D106: what was paid, when it is not what the date asks for. Less is a
   * partial payment that lowers the date by it; more pays the date and the
   * rest goes to the agreement. Omitted: what the date asks for.
   */
  @IsOptional()
  amount?: string | number | null;

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
