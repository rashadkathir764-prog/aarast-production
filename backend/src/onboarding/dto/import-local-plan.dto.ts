import { Type } from "class-transformer";
import {
  ArrayMaxSize,
  IsArray,
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  ValidateNested,
} from "class-validator";
import { ImportLocalGuestDto } from "./import-local-guest.dto";
import { ImportLocalTaskDto } from "./import-local-task.dto";
import { CompleteOnboardingDto } from "./complete-onboarding.dto";

export class ImportLocalCostPaymentDto {
  @IsNotEmpty()
  amount!: string | number;

  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  paidAt?: string | null;

  @IsString()
  @MaxLength(80)
  @IsOptional()
  method?: string | null;

  @IsString()
  @MaxLength(1000)
  @IsOptional()
  note?: string | null;
}

export class ImportLocalPaymentScheduleDto {
  @IsNotEmpty()
  amount!: string | number;

  @IsISO8601({ strict: true, strictSeparator: true })
  @IsNotEmpty()
  dueDate!: string;

  @IsString()
  @MaxLength(1000)
  @IsOptional()
  note?: string | null;
}

/** A local-planning cost imported once into the unified money ledger. */
export class ImportLocalCostDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  title!: string;

  @IsNotEmpty()
  totalAmount!: string | number;

  @IsString()
  @IsNotEmpty()
  @MaxLength(120)
  categoryName!: string;

  @IsString()
  @MaxLength(200)
  @IsOptional()
  partyName?: string | null;

  @IsString()
  @MaxLength(40)
  @IsOptional()
  partyPhone?: string | null;

  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  agreementDate?: string | null;

  @IsString()
  @MaxLength(1000)
  @IsOptional()
  note?: string | null;

  @IsArray()
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => ImportLocalCostPaymentDto)
  @IsOptional()
  payments?: ImportLocalCostPaymentDto[];

  @IsArray()
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => ImportLocalPaymentScheduleDto)
  @IsOptional()
  paymentSchedules?: ImportLocalPaymentScheduleDto[];
}

/**
 * One-shot migration of a guest-mode local plan into the authenticated
 * account. Everything is created inside one transaction and the migration id
 * makes retries idempotent.
 */
export class ImportLocalPlanDto extends CompleteOnboardingDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(80)
  clientMigrationId!: string;

  @IsArray()
  @ArrayMaxSize(300)
  @ValidateNested({ each: true })
  @Type(() => ImportLocalCostDto)
  @IsOptional()
  costs?: ImportLocalCostDto[];

  @IsArray()
  @ArrayMaxSize(300)
  @ValidateNested({ each: true })
  @Type(() => ImportLocalTaskDto)
  @IsOptional()
  tasks?: ImportLocalTaskDto[];

  @IsArray()
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => ImportLocalGuestDto)
  @IsOptional()
  guests?: ImportLocalGuestDto[];
}
