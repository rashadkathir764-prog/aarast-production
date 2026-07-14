import { BadRequestException } from '@nestjs/common';

/**
 * Bounds match the DB column type `numeric(14,2)`: up to 12 integer digits
 * and 2 decimal places. Anything larger used to overflow Postgres and
 * surface as an unhandled 500; anything with more decimals used to be
 * silently rounded by the database.
 */
const MONEY_PATTERN = /^\d{1,12}(\.\d{1,2})?$/;

export function requiredMoneyAmount(
  value: unknown,
  field: string,
): string {
  if (typeof value !== 'string' && typeof value !== 'number') {
    throw new BadRequestException(
      `${field} must be a non-negative amount with at most 12 digits and 2 decimal places`,
    );
  }
  const normalized = String(value).trim();
  if (!normalized || !MONEY_PATTERN.test(normalized)) {
    throw new BadRequestException(
      `${field} must be a non-negative amount with at most 12 digits and 2 decimal places`,
    );
  }
  return normalized;
}

export function optionalMoneyAmount(
  value: unknown,
  field: string,
): string | null {
  if (value === undefined) return null;
  return requiredMoneyAmount(value, field);
}
