import { IsIn, IsOptional, IsString } from 'class-validator';

export class ListProvidersQueryDto {
  @IsString()
  @IsOptional()
  cityId?: string;

  @IsString()
  @IsOptional()
  categoryId?: string;

  /**
   * G40: several categories, comma-separated (a budget item's
   * `providerCategoryIds`); a provider in any of them is listed. Not with
   * `categoryId`.
   */
  @IsString()
  @IsOptional()
  categoryIds?: string;

  @IsString()
  @IsOptional()
  search?: string;

  @IsString()
  @IsOptional()
  featured?: string;

  /**
   * RA-BE-150 (Q-36): the wedding's day (`YYYY-MM-DD`). Each provider then
   * says what is known of that day (`dayStatus`); nobody is filtered out by
   * it unless `hideBusy` asks.
   */
  @IsString()
  @IsOptional()
  eventDate?: string;

  /**
   * D131: `best` (default, «الأنسب»), `rating` («الأعلى تقييمًا») or
   * `price` («الأقل سعرًا»); docs/project/PROVIDER_RANKING.md.
   */
  @IsString()
  @IsIn(['best', 'rating', 'price'])
  @IsOptional()
  sort?: string;

  /**
   * D131: `true` leaves out the providers known to take nothing on
   * `eventDate` (he closed it, or Aarast's bookings filled it). Needs
   * `eventDate`. A provider kept is not known to be free.
   */
  @IsString()
  @IsIn(['true', 'false'])
  @IsOptional()
  hideBusy?: string;

  @IsString()
  @IsOptional()
  page?: string;

  @IsString()
  @IsOptional()
  limit?: string;
}
