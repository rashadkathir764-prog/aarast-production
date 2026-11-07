import { Transform } from 'class-transformer';
import { IsIn, IsOptional, IsString, MinLength } from 'class-validator';
import { MaxCharacters } from '../../../shared-kernel/text/text-length';
import { ASSISTANT_KINDS, type AssistantKind } from '../assistant.prompt';

const trimmed = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

/**
 * The longest answer a report carries. The app cuts a longer answer to it
 * before sending, so the team reads its start (the body stays within the
 * server's request size).
 */
export const ASSISTANT_REPORT_ANSWER_MAX = 20_000;

/** RA-ST-04 (D95): an assistant answer its reader reports, and why. */
export class ReportAssistantAnswerDto {
  @IsIn(ASSISTANT_KINDS)
  kind!: AssistantKind;

  /** The reader's own question, when the answer was to one. */
  @Transform(trimmed)
  @IsString()
  @IsOptional()
  @MaxCharacters(500)
  question?: string | null;

  @Transform(trimmed)
  @IsString()
  @MinLength(1)
  @MaxCharacters(ASSISTANT_REPORT_ANSWER_MAX)
  answer!: string;

  @Transform(trimmed)
  @IsString()
  @MinLength(1)
  @MaxCharacters(500)
  reason!: string;
}
