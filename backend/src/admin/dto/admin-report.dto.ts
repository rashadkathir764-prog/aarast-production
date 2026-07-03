import { IsOptional, IsString } from 'class-validator';

export class AdminReportQueryDto {
  @IsString()
  @IsOptional()
  from?: string;

  @IsString()
  @IsOptional()
  to?: string;
}
