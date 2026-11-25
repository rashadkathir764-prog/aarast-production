import { IsOptional, IsString, MaxLength } from 'class-validator';

/** Q-50 (أ): the reason a closed report's reporter is told, at most this long. */
export const CONVERSATION_REPORT_CLOSING_NOTE_MAX_LENGTH = 500;

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

  /**
   * Q-50 (أ), D124: closing (REVIEWED or DISMISSED) needs it; it reaches the
   * reporter. The form bounds what is sent (RA-BE-15); the mutation checks
   * it again after trimming.
   */
  @IsOptional()
  @IsString()
  @MaxLength(CONVERSATION_REPORT_CLOSING_NOTE_MAX_LENGTH)
  note?: string;
}
