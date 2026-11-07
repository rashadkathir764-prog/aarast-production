import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsNumber,
  IsObject,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { AdministrativeLocalityType } from '@prisma/client';

export type ReferenceCatalogMetadata = Record<
  string,
  string | number | boolean | null | string[]
>;

export class AdminCatalogItemDto {
  @IsString()
  @IsOptional()
  @MaxLength(120)
  key?: string;

  @IsString()
  @IsOptional()
  @MaxLength(160)
  nameAr?: string;

  @IsString()
  @IsOptional()
  @MaxLength(160)
  nameEn?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(120)
  groupKey?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(160)
  groupNameAr?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(240)
  groupSubtitleAr?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(80)
  icon?: string | null;

  @IsInt()
  @Min(-1_000_000)
  @Max(1_000_000)
  @IsOptional()
  sortOrder?: number;

  @IsBoolean()
  @IsOptional()
  showForGroom?: boolean;

  @IsBoolean()
  @IsOptional()
  showForBride?: boolean;

  @IsBoolean()
  @IsOptional()
  showForCustomer?: boolean;

  @IsBoolean()
  @IsOptional()
  showForProvider?: boolean;

  @IsBoolean()
  @IsOptional()
  isRecommended?: boolean;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  /**
   * Free-form, but `providerCategorySlugs` (D73, the money catalog's links)
   * must be a list of provider category slugs.
   */
  @IsObject()
  @IsOptional()
  metadata?: ReferenceCatalogMetadata | null;
}
export class PublishCatalogItemDto {
  @IsInt()
  @Min(1)
  @Max(1_000_000)
  @IsOptional()
  revision?: number;
}

export class AdminGovernorateDto {
  @IsString()
  @IsOptional()
  @MaxLength(40)
  code?: string;

  @IsString()
  @IsOptional()
  @MaxLength(160)
  nameAr?: string;

  @IsString()
  @IsOptional()
  @MaxLength(160)
  nameEn?: string;

  @IsNumber()
  @Min(-90)
  @Max(90)
  @IsOptional()
  latitude?: number | null;

  @IsNumber()
  @Min(-180)
  @Max(180)
  @IsOptional()
  longitude?: number | null;

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;

  @IsInt()
  @Min(-1_000_000)
  @Max(1_000_000)
  @IsOptional()
  sortOrder?: number;
}

export class AdminDistrictDto extends AdminGovernorateDto {
  @IsString()
  @IsOptional()
  governorateId?: string;
}

export class AdminLocalityDto extends AdminGovernorateDto {
  @IsString()
  @IsOptional()
  districtId?: string;

  @IsString()
  @IsOptional()
  parentId?: string | null;

  @IsEnum(AdministrativeLocalityType)
  @IsOptional()
  type?: AdministrativeLocalityType;
}
