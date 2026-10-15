import { IsOptional, IsString, MaxLength } from "class-validator";

/** Names a receipt photo the app uploaded (V1 checklist 4.4). */
export class CreateCostReceiptDto {
  /** The private upload's reference returned by the media upload. */
  @IsString()
  @MaxLength(512)
  attachmentRef!: string;

  /** The payment the receipt is for; omitted for the cost as a whole. */
  @IsOptional()
  @IsString()
  @MaxLength(64)
  costPaymentId?: string | null;
}
