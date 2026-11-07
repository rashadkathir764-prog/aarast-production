import { Transform } from 'class-transformer';
import { IsString, MinLength } from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

/** RA-ST-05: why a review is reported (offensive, false, or the reader's words). */
export class ReportProviderReviewDto {
  @Transform(({ value }) => (typeof value === 'string' ? value.trim() : value))
  @IsString()
  @MinLength(1)
  @MaxCharacters(500)
  reason!: string;
}
