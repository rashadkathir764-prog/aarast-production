import { IsBoolean, IsInt, IsOptional, IsString, Max, MaxLength, Min } from 'class-validator';

// RA-AD-16: lengths as the reference catalog's (admin-reference-catalog.dto.ts);
// the panel's boxes stop at the same numbers.
export class AdminCategoryDto {
  @IsString()
  @MaxLength(160)
  nameAr!: string;

  @IsString()
  @IsOptional()
  @MaxLength(160)
  nameEn?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(120)
  slug?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(80)
  icon?: string | null;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsBoolean()
  @IsOptional()
  showForGroom?: boolean;

  @IsBoolean()
  @IsOptional()
  showForBride?: boolean;

  @IsInt()
  @Min(-1_000_000)
  @Max(1_000_000)
  @IsOptional()
  sortOrder?: number;
}

export class AdminCityDto {
  /** In the unique index with the country code: a btree row stops near 2.7 KB. */
  @IsString()
  @MaxLength(160)
  nameAr!: string;

  @IsString()
  @IsOptional()
  @MaxLength(160)
  nameEn?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(8)
  countryCode?: string | null;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsInt()
  @Min(-1_000_000)
  @Max(1_000_000)
  @IsOptional()
  sortOrder?: number;
}
