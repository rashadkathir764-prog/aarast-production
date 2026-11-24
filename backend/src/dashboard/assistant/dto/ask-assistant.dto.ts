import { IsIn, IsOptional, IsString } from 'class-validator';
import { MaxCharacters } from '../../../shared-kernel/text/text-length';
import { ASSISTANT_KINDS, type AssistantKind } from '../assistant.prompt';

export class AskAssistantDto {
  @IsIn(ASSISTANT_KINDS)
  kind!: AssistantKind;

  /** The user's own question or addition (required for QUESTION). */
  @IsString()
  @IsOptional()
  @MaxCharacters(500)
  question?: string | null;

  // RA-BE-161: no consent flag. The asker's stored consent
  // (`PUT .../assistant/consent`) is what the server reads.
}
