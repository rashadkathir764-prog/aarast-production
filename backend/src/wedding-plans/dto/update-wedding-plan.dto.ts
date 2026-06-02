import { IsOptional, IsString } from 'class-validator';

export class UpdateWeddingPlanDto {
  @IsString()
  @IsOptional()
  title?: string;

  @IsString()
  @IsOptional()
  city?: string;

  @IsString()
  @IsOptional()
  weddingDate?: string;

  @IsOptional()
  estimatedBudget?: string | number;

  @IsString()
  @IsOptional()
  currency?: string;
}