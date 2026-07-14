import { IsNotEmpty, IsString, MaxLength } from "class-validator";

export class ReverseCostPaymentDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(1000)
  reason!: string;
}
