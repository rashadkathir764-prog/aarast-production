import { OnboardingPath, WeddingPersona } from '@prisma/client';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsEnum,
  IsNotEmpty,
  IsObject,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';
import { SupportedCurrency } from '../../shared-kernel/money/currency';

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

  /**
   * D114: the groom counts the mahr inside the budget. Omitted is false;
   * `true` on a plan that does not pay the mahr is refused.
   */
  @IsBoolean()
  @IsOptional()
  budgetIncludesMahr?: boolean;

  @IsString()
  @SupportedCurrency()
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
