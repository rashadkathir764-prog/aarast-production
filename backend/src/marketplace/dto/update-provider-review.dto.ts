import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class UpdateProviderReviewDto {
  @IsInt()
  @Min(1)
  @Max(5)
  @IsOptional()
  rating?: number;

  @IsString()
  @IsOptional()
  comment?: string | null;
}
