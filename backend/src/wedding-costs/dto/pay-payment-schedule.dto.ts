import { IsISO8601, IsOptional, IsString, MaxLength } from "class-validator";

export class PayPaymentScheduleDto {
  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  paidAt?: string | null;

  @IsString()
  @MaxLength(80)
  @IsOptional()
  method?: string | null;

  @IsString()
  @MaxLength(1000)
  @IsOptional()
  note?: string | null;
}
