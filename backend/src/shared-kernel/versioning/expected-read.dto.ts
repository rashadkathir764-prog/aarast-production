import { IsObject, IsOptional } from "class-validator";

/**
 * RA-MO-344: the body of a delete. The value the phone last read of each
 * field of the row it deletes; a field changed since refuses the delete
 * (409 CHANGED_ELSEWHERE, `assertFieldsUnchangedSince`). Omitted, the delete
 * is taken as before.
 */
export class ExpectedReadDto {
  @IsObject()
  @IsOptional()
  expected?: Record<string, unknown>;
}
