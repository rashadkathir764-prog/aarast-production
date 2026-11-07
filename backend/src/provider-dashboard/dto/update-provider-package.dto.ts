import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

// RA-BE-15: bounded as the package is created (create-provider-package.dto.ts).
export class UpdateProviderPackageDto {
  @IsString()
  @IsOptional()
  serviceId?: string | null;

  @IsString()
  @IsOptional()
  @MaxCharacters(160)
  title?: string;

  @IsString()
  @IsOptional()
  @MaxCharacters(2000)
  description?: string | null;

  @IsString()
  @IsOptional()
  price?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(8)
  currency?: string;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(50)
  @IsString({ each: true })
  @MaxCharacters(200, { each: true })
  items?: string[];

  @IsBoolean()
  @IsOptional()
  isActive?: boolean;
}
