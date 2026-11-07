import { IsBoolean, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class AdminCategoryDto {
  @IsString()
  nameAr!: string;

  @IsString()
  @IsOptional()
  nameEn?: string | null;

  @IsString()
  @IsOptional()
  slug?: string | null;

  @IsString()
  @IsOptional()
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
  @IsString()
  nameAr!: string;

  @IsString()
  @IsOptional()
  nameEn?: string | null;

  @IsString()
  @IsOptional()
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
