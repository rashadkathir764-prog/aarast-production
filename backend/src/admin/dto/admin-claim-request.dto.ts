import { IsOptional, IsString, MaxLength } from 'class-validator';

export class AdminClaimRequestQueryDto {
  @IsString()
  @IsOptional()
  status?: string;

  @IsString()
  @IsOptional()
  page?: string;

  @IsString()
  @IsOptional()
  limit?: string;
}

/** Why a claim of a listing was refused (B-12); the claimant reads it. */
export class AdminClaimDecisionDto {
  @IsString()
  @IsOptional()
  @MaxLength(1000)
  note?: string;
}
