import { IsString } from "class-validator";
import { MaxCharacters } from "../../../../shared-kernel/text/text-length";

/** D63 (w05): the word typed to confirm the deletion request («حذف»). */
export class RequestAccountDeletionDto {
  @IsString()
  @MaxCharacters(20)
  confirmWord!: string;
}
