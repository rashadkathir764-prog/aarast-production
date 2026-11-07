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
import { MaxCharacters } from '../../shared-kernel/text/text-length';

/**
 * J1-13: the items a new plan starts with. A phone plan carries every
 * starter item it picked (the managed catalogue offers up to 26 per persona,
 * the mahr's included) plus the items its owner added, so the cap leaves
 * room for both; each name is as long as a budget item's may be.
 */
export const PLAN_STARTER_ITEMS_MAX = 60;
export const PLAN_ITEM_NAME_MAX_LENGTH = 120;

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

  /** RA-BE-15: «عرس» and the phone's name field (120). */
  @IsString()
  @MaxCharacters(160)
  @IsOptional()
  title?: string;

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

  @IsArray()
  @ArrayMaxSize(PLAN_STARTER_ITEMS_MAX)
  @IsString({ each: true })
  @MaxCharacters(PLAN_ITEM_NAME_MAX_LENGTH, { each: true })
  @IsOptional()
  selectedCategories?: string[];

  /** The mahr from a06; only a groom's or a bride's plan takes it (C1). */
  @ValidateNested()
  @Type(() => OnboardingMahrDto)
  @IsOptional()
  mahr?: OnboardingMahrDto;
}
