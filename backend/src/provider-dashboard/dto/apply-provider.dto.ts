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
import { MaxCharacters } from '../../shared-kernel/text/text-length';

/** A service the provider joins with (B-10): its name and its price. */
export class ApplyProviderServiceDto {
  @IsString()
  @IsNotEmpty()
  @MaxCharacters(160)
  title!: string;

  @IsString()
  @IsOptional()
  basePrice?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(8)
  currency?: string;

  @IsString()
  @IsOptional()
  @MaxCharacters(2000)
  description?: string | null;
}

// RA-BE-15: the name and the about are what every customer reads, bounded as
// the profile is edited (update-provider-profile.dto.ts).
export class ApplyProviderDto {
  @IsString()
  @IsNotEmpty()
  @MaxCharacters(160)
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
  @ArrayMaxSize(50)
  @IsString({ each: true })
  categoryIds!: string[];

  @IsString()
  @IsOptional()
  @MaxCharacters(2000)
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
