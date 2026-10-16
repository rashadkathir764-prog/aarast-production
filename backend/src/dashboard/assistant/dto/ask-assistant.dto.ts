import { IsBoolean, IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { ASSISTANT_KINDS, type AssistantKind } from '../assistant.prompt';

export class AskAssistantDto {
  @IsIn(ASSISTANT_KINDS)
  kind!: AssistantKind;

  /** The user's own question or addition (required for QUESTION). */
  @IsString()
  @IsOptional()
  @MaxLength(500)
  question?: string | null;

  /** V1 checklist 4.12: the user agreed to send the plan's data to the assistant's model. */
  @IsBoolean()
  consent!: boolean;
}
