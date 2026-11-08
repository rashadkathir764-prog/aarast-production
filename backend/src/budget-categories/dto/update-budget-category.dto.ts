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

  /**
   * D109: what the owner expects the item to cost. Free: may pass the
   * budget and needs none; 0 is an answer («ما بيكلف شي»). Omitted: kept.
   */
  @IsOptional()
  estimatedAmount?: string | number | null;
}
