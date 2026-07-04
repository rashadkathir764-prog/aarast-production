import { ExpenseStatus } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from 'class-validator';
import { CreateGuestDto } from '../../guests/dto/create-guest.dto';
import { CreateTaskDto } from '../../tasks/dto/create-task.dto';
import { CompleteOnboardingDto } from './complete-onboarding.dto';

/**
 * An expense captured while planning in local guest mode. Local budget
 * category ids are meaningless to the server, so the client sends the
 * category NAME and the server links it to the category created during
 * this same import.
 */
export class ImportLocalExpenseDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  title!: string;

  @IsNotEmpty()
  amount!: string | number;

  @IsString()
  @MaxLength(80)
  @IsOptional()
  categoryName?: string | null;

  @IsEnum(ExpenseStatus)
  @IsOptional()
  status?: ExpenseStatus;

  @IsString()
  @IsOptional()
  expenseDate?: string | null;

  @IsString()
  @IsOptional()
  note?: string | null;
}

/**
 * One-shot migration of a guest-mode local plan into the authenticated
 * account. Everything is created inside a single transaction, and
 * `clientMigrationId` makes the call idempotent: retrying after a network
 * timeout returns the already-imported plan instead of duplicating it.
 */
export class ImportLocalPlanDto extends CompleteOnboardingDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  clientMigrationId!: string;

  @IsArray()
  @ArrayMaxSize(300)
  @ValidateNested({ each: true })
  @Type(() => ImportLocalExpenseDto)
  @IsOptional()
  expenses?: ImportLocalExpenseDto[];

  @IsArray()
  @ArrayMaxSize(300)
  @ValidateNested({ each: true })
  @Type(() => CreateTaskDto)
  @IsOptional()
  tasks?: CreateTaskDto[];

  @IsArray()
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => CreateGuestDto)
  @IsOptional()
  guests?: CreateGuestDto[];
}
