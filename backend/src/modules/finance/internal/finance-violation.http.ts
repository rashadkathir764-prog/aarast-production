import { BadRequestException, ConflictException } from '@nestjs/common';
import type { FinanceViolation } from '../domain/finance-violation';

/**
 * Raises a Finance domain violation as the HTTP error the money endpoints
 * return for it: invalid input is 400, a ledger conflict is 409.
 */
export function raiseFinanceViolation(violation: FinanceViolation | null): void {
  if (!violation) return;
  throw violation.kind === 'conflict'
    ? new ConflictException(violation.message)
    : new BadRequestException(violation.message);
}
