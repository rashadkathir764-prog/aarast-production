import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';

/** A service the provider joins with (B-10): its name and its price. */
export class ApplyProviderServiceDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(160)
  title!: string;

  @IsString()
  @IsOptional()
  basePrice?: string | null;

  @IsString()
  @IsOptional()
  currency?: string;

  @IsString()
  @IsOptional()
  @MaxLength(2000)
  description?: string | null;
}

export class ApplyProviderDto {
  @IsString()
  @IsNotEmpty()
  businessName!: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;

  @IsString()
  @IsNotEmpty()
  cityId!: string;

  /** The first is the profile's category, which the joining services take. */
  @IsArray()
  @ArrayMinSize(1)
  @IsString({ each: true })
  categoryIds!: string[];

  @IsString()
  @IsOptional()
  description?: string | null;

  /**
   * At least one service with its price before review (B-10, D41); a
   * missing or unpriced one is refused with 422 PROVIDER_SERVICE_REQUIRED.
   */
  @IsArray()
  @IsOptional()
  @ArrayMaxSize(5)
  @ValidateNested({ each: true })
  @Type(() => ApplyProviderServiceDto)
  services?: ApplyProviderServiceDto[];
}
