import { OnboardingPath, WeddingPersona } from '@prisma/client';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class UpdateWeddingPlanDto {
  @IsString()
  @IsOptional()
  title?: string;

  @IsString()
  @MaxLength(160)
  @IsOptional()
  city?: string;

  @IsObject()
  @IsOptional()
  location?: Record<string, unknown> | null;

  @IsString()
  @IsOptional()
  weddingDate?: string;

  @IsOptional()
  estimatedBudget?: string | number;

  @IsString()
  @IsOptional()
  currency?: string;

  @IsArray()
  @ArrayMaxSize(12)
  @IsString({ each: true })
  @MaxLength(60, { each: true })
  @IsOptional()
  priorities?: string[];

  @IsEnum(OnboardingPath)
  @IsOptional()
  onboardingPath?: OnboardingPath;

  @IsEnum(WeddingPersona)
  @IsOptional()
  persona?: WeddingPersona | null;
}
