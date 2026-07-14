import { IsNotEmpty, IsOptional, IsString } from "class-validator";

export class CreateBudgetCategoryDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsOptional()
  allocatedAmount?: string | number | null;
}
