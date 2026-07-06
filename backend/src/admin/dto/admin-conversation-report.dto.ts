import { IsOptional, IsString } from 'class-validator';

export class AdminConversationReportQueryDto {
  @IsOptional()
  @IsString()
  status?: string;

  @IsOptional()
  @IsString()
  page?: string;

  @IsOptional()
  @IsString()
  limit?: string;
}

export class AdminConversationReportStatusDto {
  @IsString()
  status!: string;
}
