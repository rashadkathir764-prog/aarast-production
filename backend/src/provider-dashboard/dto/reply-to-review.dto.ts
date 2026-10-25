import { IsNotEmpty, IsString, MaxLength } from 'class-validator';
import { REVIEW_REPLY_MAX_LENGTH } from '../../modules/marketplace/public/review-reply';

/** B-09 (p27): the provider's one reply to a review. */
export class ReplyToReviewDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(REVIEW_REPLY_MAX_LENGTH)
  body!: string;
}
