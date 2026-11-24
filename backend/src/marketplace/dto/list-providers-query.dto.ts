import { IsOptional, IsString } from 'class-validator';

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
   * says whether he takes that day (`availableOnEventDate`); nobody is
   * filtered out by it.
   */
  @IsString()
  @IsOptional()
  eventDate?: string;

  @IsString()
  @IsOptional()
  page?: string;

  @IsString()
  @IsOptional()
  limit?: string;
}
