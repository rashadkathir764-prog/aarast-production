import { IsBoolean, IsString, MinLength } from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

export class ConversationToggleDto {
  @IsBoolean()
  enabled!: boolean;
}

export class ReportConversationDto {
  @IsString()
  @MinLength(3)
  @MaxCharacters(500)
  reason!: string;
}
