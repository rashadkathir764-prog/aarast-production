import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

// RA-BE-15: bounded as the review is written (create-provider-review.dto.ts).
export class UpdateProviderReviewDto {
  @IsInt()
  @Min(1)
  @Max(5)
  @IsOptional()
  rating?: number;

  @IsString()
  @IsOptional()
  @MaxCharacters(1000)
  comment?: string | null;
}
