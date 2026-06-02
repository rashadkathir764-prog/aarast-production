import { IsOptional, IsString } from 'class-validator';

export class UpdateBudgetCategoryDto {
  @IsString()
  @IsOptional()
  name?: string;

  @IsOptional()
  targetAmount?: string | number | null;
}