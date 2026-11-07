import { OnboardingPath, WeddingPersona } from '@prisma/client';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

export class CreateWeddingPlanDto {
  /** RA-BE-15: as the onboarding title, «عرس» and a name of up to 120. */
  @IsString()
  @IsNotEmpty()
  @MaxCharacters(160)
  title!: string;

  @IsString()
  @MaxCharacters(160)
  @IsOptional()
  city?: string;

  @IsObject()
  @IsOptional()
  location?: Record<string, unknown>;

  @IsString()
  @MaxLength(40)
  @IsOptional()
  weddingDate?: string;

  @IsArray()
  @ArrayMaxSize(12)
  @IsString({ each: true })
  @MaxCharacters(60, { each: true })
  @IsOptional()
  priorities?: string[];

  @IsOptional()
  estimatedBudget?: string | number;

  @IsString()
  @MaxLength(8)
  @IsOptional()
  currency?: string;

  @IsEnum(OnboardingPath)
  @IsOptional()
  onboardingPath?: OnboardingPath;

  @IsEnum(WeddingPersona)
  @IsOptional()
  persona?: WeddingPersona;

  @IsArray()
  @ArrayMaxSize(25)
  @IsString({ each: true })
  @MaxCharacters(80, { each: true })
  @IsOptional()
  selectedCategories?: string[];
}
