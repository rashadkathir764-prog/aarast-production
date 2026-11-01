import { IsIn, IsOptional } from "class-validator";

/** «ما أحتاجها» (NOT_NEEDED), «بعدين» (LATER), or null to suggest it again. */
export class SetBudgetItemSuggestionDto {
  @IsOptional()
  @IsIn(["NOT_NEEDED", "LATER"])
  choice!: "NOT_NEEDED" | "LATER" | null;
}
