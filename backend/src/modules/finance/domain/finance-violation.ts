/**
 * A money rule a request would break: `invalid` input, or a `conflict` with
 * the ledger's current state. The domain only names the violation; the
 * application maps it to its transport error.
 */
export interface FinanceViolation {
  readonly kind: 'invalid' | 'conflict';
  readonly message: string;
}

export function invalid(message: string): FinanceViolation {
  return { kind: 'invalid', message };
}

export function conflict(message: string): FinanceViolation {
  return { kind: 'conflict', message };
}
