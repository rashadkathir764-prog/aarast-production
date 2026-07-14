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

export class MoneyBudgetCategoryDto {
  @IsString()
  @IsOptional()
  id?: string;

  @IsUUID("4")
  @IsOptional()
  clientId?: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  name!: string;

  @IsOptional()
  allocatedAmount?: string | number | null;
}

export class ReplaceMoneyBudgetDto {
  @IsOptional()
  totalBudget!: string | number | null;

  @IsString()
  @IsNotEmpty()
  currency!: string;

  @IsArray()
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => MoneyBudgetCategoryDto)
  categories!: MoneyBudgetCategoryDto[];
}
