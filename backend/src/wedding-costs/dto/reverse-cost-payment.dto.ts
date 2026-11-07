import { IsNotEmpty, IsString } from "class-validator";
import { MaxCharacters } from "../../shared-kernel/text/text-length";

export class ReverseCostPaymentDto {
  @IsString()
  @IsNotEmpty()
  @MaxCharacters(1000)
  reason!: string;
}
