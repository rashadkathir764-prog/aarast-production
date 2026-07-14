import { IsOptional, IsString } from "class-validator";

export class UpdateBudgetCategoryDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsOptional()
  allocatedAmount?: string | number | null;
}
