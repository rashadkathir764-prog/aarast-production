import {
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from "class-validator";

export class CreatePaymentScheduleDto {
  @IsNotEmpty()
  amount!: string | number;

  @IsISO8601({ strict: true, strictSeparator: true })
  @IsNotEmpty()
  dueDate!: string;

  @IsString()
  @MaxLength(1000)
  @IsOptional()
  note?: string | null;
}
