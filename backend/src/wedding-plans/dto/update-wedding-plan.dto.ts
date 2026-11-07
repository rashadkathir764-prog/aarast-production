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
import { MaxCharacters } from '../../shared-kernel/text/text-length';

export class UpdateWeddingPlanDto {
  /**
   * RA-BE-15: the phone's edit stops at 80; the title onboarding made (up to
   * 124) is sent back unchanged, so the server takes the onboarding's 160.
   */
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
  location?: Record<string, unknown> | null;

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

  @IsEnum(OnboardingPath)
  @IsOptional()
  onboardingPath?: OnboardingPath;

  @IsEnum(WeddingPersona)
  @IsOptional()
  persona?: WeddingPersona | null;
}
