import { IsBoolean, IsOptional, IsString } from 'class-validator';
import { CreateTaskDto } from './create-task.dto';

/**
 * A task created in a live plan: the importable task fields plus privacy.
 * A local plan import never carries privacy, so `CreateTaskDto` (which the
 * import re-expresses) stays as it is.
 */
export class CreatePlanTaskDto extends CreateTaskDto {
  /** V1 checklist 4.10: only the owner or the partner keeps a task private (seen by them alone). */
  @IsBoolean()
  @IsOptional()
  isPrivate?: boolean;

  /** R4: the starter template it came from; one that names a service waits on that item. */
  @IsString()
  @IsOptional()
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
