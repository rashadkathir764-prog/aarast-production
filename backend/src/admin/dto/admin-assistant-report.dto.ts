import { IsIn, IsOptional, IsString } from 'class-validator';

/** RA-ST-04 (D95): the reported assistant answers, open or reviewed. */
export class AdminAssistantReportQueryDto {
  @IsOptional()
  @IsIn(['OPEN', 'RESOLVED'])
  status?: 'OPEN' | 'RESOLVED';

  @IsOptional()
  @IsString()
  page?: string;

  @IsOptional()
  @IsString()
  limit?: string;
}
