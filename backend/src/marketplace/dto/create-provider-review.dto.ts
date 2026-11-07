import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

// RA-BE-15: a review is read by everyone who opens the provider, so its text
// has a bound, above the phone's field (500 there).
export class CreateProviderReviewDto {
  @IsInt()
  @Min(1)
  @Max(5)
  rating!: number;

  @IsString()
  @IsOptional()
  @MaxCharacters(1000)
  comment?: string | null;
}
