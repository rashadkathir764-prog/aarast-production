import { BadRequestException, ConflictException } from '@nestjs/common';
import { conflict, type FinanceViolation } from '../domain/finance-violation';

/**
 * Raises a Finance domain violation as the HTTP error the money endpoints
 * return for it: invalid input is 400, a ledger conflict is 409. The body
 * carries the violation's stable code and its Arabic reason (G22), so the
 * app says what happened instead of a generic status message.
 */
export function raiseFinanceViolation(violation: FinanceViolation | null): void {
  if (!violation) return;
  const conflict = violation.kind === 'conflict';
  const body = {
    statusCode: conflict ? 409 : 400,
    code: violation.code,
    message: violation.userMessage,
    detail: violation.message,
  };
  throw conflict ? new ConflictException(body) : new BadRequestException(body);
}

/** A ledger-state refusal outside the pure policies, worded like one (G22). */
export function financeConflict(message: string): ConflictException {
  try {
    raiseFinanceViolation(conflict(message));
  } catch (error) {
    return error as ConflictException;
  }
  return new ConflictException(message);
}
