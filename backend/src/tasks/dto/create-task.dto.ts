import { WeddingTaskPriority, WeddingTaskStatus } from '@prisma/client';
import { IsEnum, IsNotEmpty, IsOptional, IsString } from 'class-validator';

export class CreateTaskDto {
  @IsString()
  @IsNotEmpty()
  title!: string;

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
  reminderAt?: string | null;

  @IsEnum(WeddingTaskStatus)
  @IsOptional()
  status?: WeddingTaskStatus;

  @IsEnum(WeddingTaskPriority)
  @IsOptional()
  priority?: WeddingTaskPriority;
}
