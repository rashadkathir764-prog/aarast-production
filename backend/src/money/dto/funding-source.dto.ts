import { FundingSourceKind, FundingSourceStatus, LoanRepaymentStatus } from "@prisma/client";
import {
  IsEnum,
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
} from "class-validator";
import { MaxCharacters } from "../../shared-kernel/text/text-length";

export class CreateFundingSourceDto {
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

  /**
   * D108: who gave or promised it («الوالد», «خالي أحمد»), matched with the
   * agreements' payer name to show the family person by person.
   */
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

  /** PLEDGED money: the day it is expected. */
  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  expectedAt?: string | null;

  @IsString()
  @MaxCharacters(2000)
  @IsOptional()
  note?: string | null;
}

export class UpdateFundingSourceDto {
  @IsEnum(FundingSourceKind)
  @IsOptional()
  kind?: FundingSourceKind;

  @IsString()
  @IsNotEmpty()
  @MaxCharacters(160)
  @IsOptional()
  sourceName?: string;

  @IsString()
  @MaxLength(40)
  @IsOptional()
  sourcePhone?: string | null;

  /**
   * D108: who gave or promised it («الوالد», «خالي أحمد»), matched with the
   * agreements' payer name to show the family person by person.
   */
  @IsString()
  @MaxCharacters(120)
  @IsOptional()
  contributorName?: string | null;

  @IsOptional()
  amount?: string | number;

  @IsEnum(FundingSourceStatus)
  @IsOptional()
  status?: FundingSourceStatus;

  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  receivedAt?: string | null;

  /** PLEDGED money: the day it is expected. */
  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  expectedAt?: string | null;

  @IsString()
  @MaxCharacters(2000)
  @IsOptional()
  note?: string | null;
}

export class CreateLoanRepaymentDto {
  @IsNotEmpty()
  amount!: string | number;

  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  dueDate?: string | null;

  @IsString()
  @MaxCharacters(2000)
  @IsOptional()
  note?: string | null;
}

export class UpdateLoanRepaymentDto {
  @IsOptional()
  amount?: string | number;

  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  dueDate?: string | null;

  /** PAID records the repayment (paidAt defaults to now); PLANNED reopens it. */
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
