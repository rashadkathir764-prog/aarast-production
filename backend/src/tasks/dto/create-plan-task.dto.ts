import { IsBoolean, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';
import {
  TASK_DESCRIPTION_MAX,
  TASK_PERSON_NAME_MAX,
  TASK_TITLE_MAX,
} from '../../modules/tasks/public/task-text-limits';
import { CreateTaskDto } from './create-task.dto';

/**
 * A task created in a live plan: the importable task fields plus privacy.
 * A local plan import never carries privacy, so `CreateTaskDto` (which the
 * import re-expresses) stays as it is.
 *
 * RA-BE-15: the text fields' lengths live here, `CreateTaskDto` being
 * byte-pinned by the R12B parity proof. class-validator drops a parent's
 * rules on a field the child redeclares, so each redeclared field restates
 * them all (and `dto-text-bounds.test.ts` checks that it does).
 */
export class CreatePlanTaskDto extends CreateTaskDto {
  @IsString()
  @IsNotEmpty()
  @MaxCharacters(TASK_TITLE_MAX)
  title!: string;

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
  @IsOptional()
  @MaxLength(40)
  reminderAt?: string | null;

  /** V1 checklist 4.10: only the owner or the partner keeps a task private (seen by them alone). */
  @IsBoolean()
  @IsOptional()
  isPrivate?: boolean;

  /** R4: the starter template it came from; one that names a service waits on that item. */
  @IsString()
  @IsOptional()
  @MaxLength(120)
  starterKey?: string;

  /** R4: the money item it waits on. */
  @IsString()
  @IsOptional()
  linkedBudgetCategoryId?: string;

  /** R4: the payment it waits on. */
  @IsString()
  @IsOptional()
  linkedScheduleId?: string;
}
