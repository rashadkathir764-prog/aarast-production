import { IsString, MaxLength } from "class-validator";

/** D63 (w05): the word typed to confirm the deletion request («حذف»). */
export class RequestAccountDeletionDto {
  @IsString()
  @MaxLength(20)
  confirmWord!: string;
}
