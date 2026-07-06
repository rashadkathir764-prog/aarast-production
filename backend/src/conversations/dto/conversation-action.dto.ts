import { IsBoolean, IsString, MaxLength, MinLength } from 'class-validator';

export class ConversationToggleDto {
  @IsBoolean()
  enabled!: boolean;
}

export class ReportConversationDto {
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}
