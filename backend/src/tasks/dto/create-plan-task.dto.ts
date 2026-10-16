import { IsBoolean, IsOptional } from 'class-validator';
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
}
