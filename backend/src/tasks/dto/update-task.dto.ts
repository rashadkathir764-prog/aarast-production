import { WeddingTaskPriority, WeddingTaskStatus } from '@prisma/client';
import { IsBoolean, IsEnum, IsIn, IsOptional, IsString } from 'class-validator';

export class UpdateTaskDto {
  @IsString()
  @IsOptional()
  title?: string;

  @IsString()
  @IsOptional()
  description?: string | null;

  @IsString()
  @IsOptional()
  dueDate?: string | null;

  @IsString()
  @IsOptional()
  taskCategory?: string | null;

  @IsString()
  @IsOptional()
  responsibleName?: string | null;

  @IsString()
  @IsOptional()
  responsiblePhone?: string | null;

  @IsString()
  @IsIn(['manual', 'deviceContact', 'planContact'])
  @IsOptional()
  responsibleSource?: string | null;

  @IsString()
  @IsOptional()
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
}
