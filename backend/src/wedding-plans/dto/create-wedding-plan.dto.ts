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

export class CreateWeddingPlanDto {
  @IsString()
  @IsNotEmpty()
  title!: string;

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

  @IsEnum(OnboardingPath)
  @IsOptional()
  onboardingPath?: OnboardingPath;

  @IsEnum(WeddingPersona)
  @IsOptional()
  persona?: WeddingPersona;

  @IsArray()
  @ArrayMaxSize(25)
  @IsString({ each: true })
  @MaxLength(80, { each: true })
  @IsOptional()
  selectedCategories?: string[];
}
