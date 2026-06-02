import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateBudgetCategoryDto {
  @IsString()
  @IsNotEmpty()
  name!: string;

  @IsOptional()
  targetAmount?: string | number | null;
}