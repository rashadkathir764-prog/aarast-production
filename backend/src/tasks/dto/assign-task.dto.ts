import { IsOptional, IsString } from 'class-validator';

export class AssignTaskDto {
  @IsString()
  @IsOptional()
  assigneeUserId?: string | null;
}
