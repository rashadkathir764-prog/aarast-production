import {
  ArrayMaxSize,
  IsArray,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

// RA-BE-15: what a provider writes is read by every customer, so it has a
// bound, above the phone's fields (the description stops at 220 there). The
// items were any JSON, stored and served as sent; the phone sends a list of
// lines, and that is what is taken.
export class CreateProviderPackageDto {
  @IsString()
  @IsOptional()
  serviceId?: string | null;

  @IsString()
  @IsNotEmpty()
  @MaxCharacters(160)
  title!: string;

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
}
