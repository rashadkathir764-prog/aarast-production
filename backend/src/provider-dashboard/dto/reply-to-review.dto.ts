import { IsNotEmpty, IsString } from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';
import { REVIEW_REPLY_MAX_LENGTH } from '../../modules/marketplace/public/review-reply';

/** B-09 (p27): the provider's one reply to a review. */
export class ReplyToReviewDto {
  @IsString()
  @IsNotEmpty()
  @MaxCharacters(REVIEW_REPLY_MAX_LENGTH)
  body!: string;
}
