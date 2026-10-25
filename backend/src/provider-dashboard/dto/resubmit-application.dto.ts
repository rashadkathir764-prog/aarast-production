import { IsUUID, ValidateIf } from 'class-validator';

/**
 * «أرسلت التعديل» (B-01) names the latest review decision the provider read
 * (`latestDecision.id` of his profile, null when none is on record). A newer
 * decision is `409 PROVIDER_REVIEW_CHANGED`: the team rewrote its notes
 * meanwhile, so he reads them before the profile goes back to review.
 */
export class ResubmitApplicationDto {
  // Required: undefined fails the UUID check; null passes as "no decision".
  @ValidateIf((_dto, value) => value !== null)
  @IsUUID()
  latestDecisionId!: string | null;
}
