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
import { MaxCharacters } from "../../shared-kernel/text/text-length";
import { PLAN_GUESTS_MAX } from "../../modules/guests/public/guest-text-limits";
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
  @MaxCharacters(80)
  @IsOptional()
  method?: string | null;

  @IsString()
  @MaxCharacters(1000)
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
  @MaxCharacters(1000)
  @IsOptional()
  note?: string | null;
}

/** A local-planning cost imported once into the unified money ledger. */
export class ImportLocalCostDto {
  // The same limit as an agreement made in the account
  // (create-wedding-cost.dto.ts), so an imported title can be edited later.
  @IsString()
  @IsNotEmpty()
  @MaxCharacters(160)
  title!: string;

  @IsNotEmpty()
  totalAmount!: string | number;

  @IsString()
  @IsNotEmpty()
  @MaxCharacters(120)
  categoryName!: string;

  @IsString()
  @MaxCharacters(200)
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
  @MaxCharacters(1000)
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
 * RA-BE-64: the import takes any plan a phone holds. Guests stop where a plan
 * stops (D99); a phone plan has no cap on tasks or agreements, so these are
 * bounds no real wedding reaches, there only to bound one request. The phone
 * checks the same numbers before it sends (`LocalPlanMigrationService`), and
 * the request's body may be up to LOCAL_PLAN_IMPORT_BODY_LIMIT bytes.
 */
export const LOCAL_PLAN_IMPORT_TASKS_MAX = 2000;
export const LOCAL_PLAN_IMPORT_COSTS_MAX = 1000;
export const LOCAL_PLAN_IMPORT_BODY_LIMIT = 8 * 1024 * 1024;
export const LOCAL_PLAN_IMPORT_PATH = "/api/v1/onboarding/import-local";

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
  @ArrayMaxSize(LOCAL_PLAN_IMPORT_COSTS_MAX)
  @ValidateNested({ each: true })
  @Type(() => ImportLocalCostDto)
  @IsOptional()
  costs?: ImportLocalCostDto[];

  @IsArray()
  @ArrayMaxSize(LOCAL_PLAN_IMPORT_TASKS_MAX)
  @ValidateNested({ each: true })
  @Type(() => ImportLocalTaskDto)
  @IsOptional()
  tasks?: ImportLocalTaskDto[];

  @IsArray()
  @ArrayMaxSize(PLAN_GUESTS_MAX)
  @ValidateNested({ each: true })
  @Type(() => ImportLocalGuestDto)
  @IsOptional()
  guests?: ImportLocalGuestDto[];
}
