import { IsNotEmpty, IsOptional, IsString } from "class-validator";

export class CreateFinancialPaymentRecordDto {
  @IsNotEmpty()
  amount!: string | number;

  @IsString()
  @IsOptional()
  title?: string | null;

  @IsString()
  @IsOptional()
  paidAt?: string | null;

  @IsString()
  @IsOptional()
  method?: string | null;

  @IsString()
  @IsOptional()
  note?: string | null;
}
