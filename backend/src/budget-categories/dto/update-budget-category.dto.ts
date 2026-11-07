import { IsOptional, IsString } from "class-validator";
import { MaxCharacters } from "../../shared-kernel/text/text-length";

export class UpdateBudgetCategoryDto {
  /** RA-BE-15: as a money budget item's name (replace-money-budget.dto.ts). */
  @IsString()
  @MaxCharacters(120)
  @IsOptional()
  name?: string;

  @IsOptional()
  allocatedAmount?: string | number | null;
}
