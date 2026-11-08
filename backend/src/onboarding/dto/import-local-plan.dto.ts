import { Type } from "class-transformer";
import {
  CostEntryKind,
  CostPayer,
  EstimateCover,
  FundingSourceKind,
  FundingSourceStatus,
  LoanRepaymentStatus,
} from "@prisma/client";
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsISO8601,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
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

  /** D106: a partial payment of this agreement's date at this index. */
  @IsInt()
  @Min(0)
  // One of the agreement's dates (at most 500, below).
  @Max(499)
  @IsOptional()
  lowersScheduleIndex?: number | null;
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

  /** D106: its own reminder day (kept only between today and the due day). */
  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  remindAt?: string | null;

  /** D106: the first due day, when the date was moved. */
  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  rescheduledFrom?: string | null;
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

  /** Who is expected to pay it (D59): the phone's own answer is kept. */
  @IsEnum(CostPayer)
  @IsOptional()
  payer?: CostPayer | null;

  @IsString()
  @MaxCharacters(120)
  @IsOptional()
  payerName?: string | null;

  /** D107. */
  @IsEnum(CostEntryKind)
  @IsOptional()
  entryKind?: CostEntryKind;

  /** D105. */
  @IsEnum(EstimateCover)
  @IsOptional()
  estimateCover?: EstimateCover;

  @IsOptional()
  estimatePart?: string | number | null;
}

/** D109: an item's own estimate and its allocation, by the item's name. */
export class ImportLocalItemAmountDto {
  @IsString()
  @IsNotEmpty()
  @MaxCharacters(120)
  name!: string;

  @IsOptional()
  allocatedAmount?: string | number | null;

  @IsOptional()
  estimatedAmount?: string | number | null;
}

export class ImportLocalLoanRepaymentDto {
  @IsNotEmpty()
  amount!: string | number;

  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  dueDate?: string | null;

  @IsEnum(LoanRepaymentStatus)
  @IsOptional()
  status?: LoanRepaymentStatus;

  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  paidAt?: string | null;

  @IsString()
  @MaxCharacters(2000)
  @IsOptional()
  note?: string | null;
}

/** Money coming in that the plan kept on the phone recorded (D103, D108). */
export class ImportLocalFundingSourceDto {
  @IsEnum(FundingSourceKind)
  kind!: FundingSourceKind;

  @IsString()
  @IsNotEmpty()
  @MaxCharacters(160)
  sourceName!: string;

  @IsString()
  @MaxLength(40)
  @IsOptional()
  sourcePhone?: string | null;

  @IsString()
  @MaxCharacters(120)
  @IsOptional()
  contributorName?: string | null;

  @IsNotEmpty()
  amount!: string | number;

  @IsEnum(FundingSourceStatus)
  @IsOptional()
  status?: FundingSourceStatus;

  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  receivedAt?: string | null;

  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  expectedAt?: string | null;

  @IsString()
  @MaxCharacters(2000)
  @IsOptional()
  note?: string | null;

  @IsArray()
  @ArrayMaxSize(120)
  @ValidateNested({ each: true })
  @Type(() => ImportLocalLoanRepaymentDto)
  @IsOptional()
  repayments?: ImportLocalLoanRepaymentDto[];
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
export const LOCAL_PLAN_IMPORT_FUNDING_MAX = 300;
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

  /** D109: the items' estimates and allocations, by name. */
  @IsArray()
  @ArrayMaxSize(LOCAL_PLAN_IMPORT_COSTS_MAX)
  @ValidateNested({ each: true })
  @Type(() => ImportLocalItemAmountDto)
  @IsOptional()
  itemAmounts?: ImportLocalItemAmountDto[];

  /** The money in the phone's plan recorded (savings, family, loans, promises). */
  @IsArray()
  @ArrayMaxSize(LOCAL_PLAN_IMPORT_FUNDING_MAX)
  @ValidateNested({ each: true })
  @Type(() => ImportLocalFundingSourceDto)
  @IsOptional()
  fundingSources?: ImportLocalFundingSourceDto[];
}
