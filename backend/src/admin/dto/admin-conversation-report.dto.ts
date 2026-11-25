import { IsOptional, IsString } from 'class-validator';

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
   * reporter. Its length is checked after trimming, by the mutation.
   */
  @IsOptional()
  @IsString()
  note?: string;
}
