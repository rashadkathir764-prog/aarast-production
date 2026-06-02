import { IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateWeddingPlanDto {
  @IsString()
  @IsNotEmpty()
  title!: string;

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