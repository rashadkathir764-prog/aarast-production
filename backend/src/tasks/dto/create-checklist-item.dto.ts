import { IsBoolean, IsInt, IsNotEmpty, IsOptional, IsString, Max, Min } from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';
import { CHECKLIST_TITLE_MAX } from '../../modules/tasks/public/task-text-limits';

export class CreateChecklistItemDto {
  @IsString()
  @IsNotEmpty()
  @MaxCharacters(CHECKLIST_TITLE_MAX)
  title!: string;

  @IsBoolean()
  @IsOptional()
  isDone?: boolean;

  @IsInt()
  @Min(0)
  @Max(1_000_000)
  @IsOptional()
  sortOrder?: number;
}
