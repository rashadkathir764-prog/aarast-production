import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';

/** B-16: one photo of «معرض الشغل», by its verified upload key. */
export class PortfolioItemDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  key!: string;

  @IsOptional()
  @IsString()
  @MaxLength(60)
  album?: string | null;

  @IsOptional()
  @IsBoolean()
  noFaces?: boolean;
}

export class PortfolioSocialLinksDto {
  @IsOptional()
  @IsString()
  @MaxLength(200)
  tiktok?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  instagram?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  facebook?: string | null;
}

/** B-16: the whole portfolio, in its order, and the provider's links. */
export class UpdateProviderPortfolioDto {
  @IsArray()
  // The limit itself (60) answers with its own code; this only bounds the body.
  @ArrayMaxSize(100)
  @ValidateNested({ each: true })
  @Type(() => PortfolioItemDto)
  items!: PortfolioItemDto[];

  @IsOptional()
  @IsObject()
  @ValidateNested()
  @Type(() => PortfolioSocialLinksDto)
  socialLinks?: PortfolioSocialLinksDto;
}
