import { IsOptional, IsString } from 'class-validator';

export class AdminNotificationQueryDto {
  @IsString()
  @IsOptional()
  type?: string;

  @IsString()
  @IsOptional()
  priority?: string;

  @IsString()
  @IsOptional()
  unreadOnly?: string;

  @IsString()
  @IsOptional()
  search?: string;

  @IsString()
  @IsOptional()
  page?: string;

  @IsString()
  @IsOptional()
  limit?: string;
}
