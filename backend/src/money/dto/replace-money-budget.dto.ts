import { Type } from "class-transformer";
import {
  ArrayMaxSize,
  IsArray,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  ValidateNested,
} from "class-validator";
import { MaxCharacters } from "../../shared-kernel/text/text-length";

export class MoneyBudgetCategoryDto {
  @IsString()
  @IsOptional()
  id?: string;

  @IsUUID("4")
  @IsOptional()
  clientId?: string;

  /** The phone's field stops at 120 (budget_category_form_screen.dart). */
  @IsString()
  @IsNotEmpty()
  @MaxCharacters(120)
  name!: string;

  @IsOptional()
  allocatedAmount?: string | number | null;

  /**
   * D109: what the owner expects the item to cost. Free: may pass the
   * budget and needs none; 0 is an answer («ما بيكلف شي»). Omitted: kept.
   */
  @IsOptional()
  estimatedAmount?: string | number | null;
}

export class ReplaceMoneyBudgetDto {
  @IsOptional()
  totalBudget!: string | number | null;

  @IsString()
  @IsNotEmpty()
  @MaxLength(8)
  currency!: string;

  @IsArray()
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => MoneyBudgetCategoryDto)
  categories!: MoneyBudgetCategoryDto[];

  /**
   * D112 (Q-4): the money summary's `budgetVersion` this save was made
   * from. When the budget changed since, the save is refused
   * (`409 BUDGET_CHANGED_ELSEWHERE`). Omitted: the save is taken as before.
   */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  expectedBudgetVersion?: string;
}
