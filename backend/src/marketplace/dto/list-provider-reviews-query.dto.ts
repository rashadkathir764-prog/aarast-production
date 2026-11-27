import { IsOptional, IsString, Matches } from 'class-validator';

/**
 * `GET /api/v1/providers/:id/reviews` (2026-11-26 review): with `page` or
 * `limit` the answer is one page with the summary; without either it stays
 * the bare list the apps already out read.
 */
export class ListProviderReviewsQueryDto {
  @IsString()
  @Matches(/^\d{1,6}$/, { message: 'page must be a positive integer' })
  @IsOptional()
  page?: string;

  /** At most 50 a page (`REVIEWS_PAGE_MAX`). */
  @IsString()
  @Matches(/^\d{1,3}$/, { message: 'limit must be a positive integer' })
  @IsOptional()
  limit?: string;
}
