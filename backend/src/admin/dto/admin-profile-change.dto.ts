import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

/** RA-BE-152: providers' profile changes of one status, PENDING by default, oldest first. */
export class AdminProfileChangeQueryDto {
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

/** «وافق» puts the change on the listing; «ارفض» keeps the listing and needs its reason. */
export class AdminProfileChangeDecisionDto {
  @IsIn(['APPROVE', 'REJECT'])
  decision!: 'APPROVE' | 'REJECT';

  @IsOptional()
  @IsString()
  @MaxLength(400)
  reason?: string;
}
