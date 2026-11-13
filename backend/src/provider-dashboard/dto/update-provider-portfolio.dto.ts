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
import { MaxCharacters } from '../../shared-kernel/text/text-length';

/** B-16: one photo of «معرض الشغل», by its verified upload key. */
export class PortfolioItemDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  key!: string;

  @IsOptional()
  @IsString()
  @MaxCharacters(60)
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

  /**
   * RA-MO-287: the keys of the photos this client had read when it built
   * `items`. A stored photo outside them was added elsewhere meanwhile and
   * is kept; without the field, `items` is the whole portfolio.
   */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(100)
  @IsString({ each: true })
  @MaxLength(200, { each: true })
  knownKeys?: string[];

  @IsOptional()
  @IsObject()
  @ValidateNested()
  @Type(() => PortfolioSocialLinksDto)
  socialLinks?: PortfolioSocialLinksDto;
}
