import { IsNotEmpty, IsOptional, IsString } from "class-validator";
import { MaxCharacters } from "../../shared-kernel/text/text-length";

export class CreateBudgetCategoryDto {
  /** RA-BE-15: as a money budget item's name (replace-money-budget.dto.ts). */
  @IsString()
  @IsNotEmpty()
  @MaxCharacters(120)
  name!: string;

  @IsOptional()
  allocatedAmount?: string | number | null;
}
