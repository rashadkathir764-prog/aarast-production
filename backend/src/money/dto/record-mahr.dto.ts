import { IsISO8601, IsNotEmpty, IsOptional } from "class-validator";

/** a06 «اتفقتوا على المهر؟»: the mahr, what was handed over, when the rest is due. */
export class RecordMahrDto {
  @IsNotEmpty()
  total!: string | number;

  /** Handed over (the groom) or received (the bride) so far; 0 when omitted. */
  @IsOptional()
  settled?: string | number | null;

  /** When the rest is handed over; ignored once nothing is left. */
  @IsISO8601({ strict: true, strictSeparator: true })
  @IsOptional()
  remainingDueDate?: string | null;
}
