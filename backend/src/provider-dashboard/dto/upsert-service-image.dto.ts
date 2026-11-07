import {
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

// RA-BE-15: the address is one of our own uploads (checked by the service),
// and the description is read by every customer.
export class CreateServiceImageDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(2048)
  imageUrl!: string;

  @IsString()
  @IsOptional()
  @MaxCharacters(300)
  altText?: string | null;

  @IsInt()
  @Min(0)
  @Max(1_000_000)
  @IsOptional()
  sortOrder?: number;
}

export class UpdateServiceImageDto {
  @IsString()
  @IsOptional()
  @MaxLength(2048)
  imageUrl?: string;

  @IsString()
  @IsOptional()
  @MaxCharacters(300)
  altText?: string | null;

  @IsInt()
  @Min(0)
  @Max(1_000_000)
  @IsOptional()
  sortOrder?: number;
}
