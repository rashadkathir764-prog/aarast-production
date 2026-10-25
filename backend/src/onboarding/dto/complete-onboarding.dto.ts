import { OnboardingPath, WeddingPersona } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsISO8601,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';

/** a06 «اتفقتوا على المهر؟», answered before the plan exists. */
export class OnboardingMahrDto {
  @IsNotEmpty()
  total!: string | number;

  @IsOptional()
  settled?: string | number | null;

  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  remainingDueDate?: string | null;
}

export class CompleteOnboardingDto {
  @IsEnum(OnboardingPath)
  @IsOptional()
  path?: OnboardingPath;

  @IsEnum(WeddingPersona)
  @IsOptional()
  persona?: WeddingPersona;

  @IsString()
  @IsOptional()
  title?: string;

  @IsString()
  @MaxLength(160)
  @IsOptional()
  city?: string;

  @IsObject()
  @IsOptional()
  location?: Record<string, unknown>;

  @IsString()
  @IsOptional()
  weddingDate?: string;

  @IsArray()
  @ArrayMaxSize(12)
  @IsString({ each: true })
  @MaxLength(60, { each: true })
  @IsOptional()
  priorities?: string[];

  @IsOptional()
  estimatedBudget?: string | number;

  @IsString()
  @IsOptional()
  currency?: string;

  @IsArray()
  @ArrayMaxSize(25)
  @IsString({ each: true })
  @MaxLength(80, { each: true })
  @IsOptional()
  selectedCategories?: string[];

  /** The mahr from a06; only a groom's or a bride's plan takes it (C1). */
  @ValidateNested()
  @Type(() => OnboardingMahrDto)
  @IsOptional()
  mahr?: OnboardingMahrDto;
}
