import { IsBoolean, IsNumber, IsOptional, IsString } from 'class-validator';

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

  @IsNumber()
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

  @IsNumber()
  @IsOptional()
  sortOrder?: number;
}
