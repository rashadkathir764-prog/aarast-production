import { IsBoolean, IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

/** n07 (B-16): the photos of one status, PENDING by default, oldest first. */
export class AdminPortfolioQueryDto {
  @IsOptional()
  @IsString()
  status?: string;

  @IsString()
  @IsOptional()
  page?: string;

  @IsString()
  @IsOptional()
  limit?: string;
}

/** «سليمة» approves; «شِل» refuses with its reason. */
export class AdminPortfolioDecisionDto {
  @IsIn(['APPROVE', 'REJECT'])
  decision!: 'APPROVE' | 'REJECT';

  @IsOptional()
  @IsString()
  @MaxLength(400)
  reason?: string;

  /** The reviewer checked a women's-album photo shows no faces. */
  @IsOptional()
  @IsBoolean()
  noFacesChecked?: boolean;
}
