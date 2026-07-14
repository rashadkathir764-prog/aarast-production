import {
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from "class-validator";

export class CreateCostPaymentDto {
  @IsNotEmpty()
  amount!: string | number;

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
