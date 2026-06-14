import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class CreateProviderReviewDto {
  @IsInt()
  @Min(1)
  @Max(5)
  rating!: number;

  @IsString()
  @IsOptional()
  comment?: string | null;
}
