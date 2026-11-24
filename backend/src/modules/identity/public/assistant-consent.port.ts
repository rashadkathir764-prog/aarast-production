export const ASSISTANT_CONSENT_PORT = Symbol('ASSISTANT_CONSENT_PORT');

// RA-BE-161 (Q-41, D124): identity keeps the account's consent to the
// planning assistant as one dated record on the account (`assistantConsentAt`).
// The assistant asks only with the asker's record, and sends a plan's money
// for a partner only with its owner's.
export interface AssistantConsentPort {
  /** When the account agreed, or null when it has not (or took it back). */
  consentedAt(userId: string): Promise<Date | null>;
  /** Records the account's consent; an existing record keeps its first date. */
  recordConsent(userId: string): Promise<Date>;
  /** Takes the account's consent back (w40). */
  withdrawConsent(userId: string): Promise<void>;
}
