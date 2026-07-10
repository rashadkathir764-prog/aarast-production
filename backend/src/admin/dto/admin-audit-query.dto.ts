import { AdminAuditPhase } from '@prisma/client';
import {
  IsDateString,
  IsEnum,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
} from 'class-validator';

export class AdminAuditQueryDto {
  @IsOptional()
  @Matches(/^\d+$/)
  page?: string;

  @IsOptional()
  @Matches(/^\d+$/)
  limit?: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  action?: string;

  @IsOptional()
  @IsString()
  @MaxLength(128)
  actorUserId?: string;

  @IsOptional()
  @IsEnum(AdminAuditPhase)
  phase?: AdminAuditPhase;

  @IsOptional()
  @IsDateString()
  from?: string;

  @IsOptional()
  @IsDateString()
  to?: string;
}
