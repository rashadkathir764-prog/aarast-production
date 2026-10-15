import { IsInt, Max, Min } from "class-validator";

/** V1 checklist 4.13: how far the wedding moved, in days (negative: earlier). */
export class ShiftTaskDatesDto {
  @IsInt()
  @Min(-730)
  @Max(730)
  days!: number;
}
