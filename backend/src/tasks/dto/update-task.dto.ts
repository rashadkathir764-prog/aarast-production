import { WeddingTaskPriority, WeddingTaskStatus } from '@prisma/client';
import { IsBoolean, IsEnum, IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';
import {
  TASK_DESCRIPTION_MAX,
  TASK_PERSON_NAME_MAX,
  TASK_TITLE_MAX,
} from '../../modules/tasks/public/task-text-limits';

export class UpdateTaskDto {
  @IsString()
  @IsOptional()
  @MaxCharacters(TASK_TITLE_MAX)
  title?: string;

  @IsString()
  @IsOptional()
  @MaxCharacters(TASK_DESCRIPTION_MAX)
  description?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(40)
  dueDate?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(60)
  taskCategory?: string | null;

  @IsString()
  @IsOptional()
  @MaxCharacters(TASK_PERSON_NAME_MAX)
  responsibleName?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(40)
  responsiblePhone?: string | null;

  @IsString()
  @IsIn(['manual', 'deviceContact', 'planContact'])
  @IsOptional()
  responsibleSource?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(40)
  reminderAt?: string | null;

  @IsEnum(WeddingTaskStatus)
  @IsOptional()
  status?: WeddingTaskStatus;

  @IsEnum(WeddingTaskPriority)
  @IsOptional()
  priority?: WeddingTaskPriority;

  /** V1 checklist 4.10: false shares a private task with the plan; a shared task never becomes private. */
  @IsBoolean()
  @IsOptional()
  isPrivate?: boolean;

  /** R4: the money item it waits on; null takes the link off. */
  @IsString()
  @IsOptional()
  linkedBudgetCategoryId?: string | null;

  /** R4: the payment it waits on; null takes the link off. */
  @IsString()
  @IsOptional()
  linkedScheduleId?: string | null;
}
