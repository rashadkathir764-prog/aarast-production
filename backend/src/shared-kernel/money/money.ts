import { BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

/**
 * Bounds match the DB column type `numeric(14,2)`: up to 12 integer digits
 * and 2 decimal places. Anything larger used to overflow Postgres and
 * surface as an unhandled 500; anything with more decimals used to be
 * silently rounded by the database.
 */
const MONEY_PATTERN = /^\d{1,12}(\.\d{1,2})?$/;

function normalizeMoneyAmount(value: unknown, field: string): string {
  if (typeof value !== 'string' && typeof value !== 'number') {
    throw invalidMoneyAmount(field);
  }
  const normalized = String(value).trim();
  if (!normalized || !MONEY_PATTERN.test(normalized)) {
    throw invalidMoneyAmount(field);
  }
  return normalized;
}

function invalidMoneyAmount(field: string): BadRequestException {
  return new BadRequestException(
    `${field} must be a non-negative amount with at most 12 digits and 2 decimal places`,
  );
}

export class Money {
  private constructor(
    private readonly decimal: Prisma.Decimal,
    private readonly serialized: string,
  ) {}

  static required(value: unknown, field: string): Money {
    const serialized = normalizeMoneyAmount(value, field);
    return new Money(new Prisma.Decimal(serialized), serialized);
  }

  static optional(value: unknown, field: string): Money | null {
    if (
      value === undefined ||
      value === null ||
      (typeof value === 'string' && value.trim() === '')
    ) {
      return null;
    }
    return Money.required(value, field);
  }

  compare(other: Money): -1 | 0 | 1 {
    const comparison = this.decimal.comparedTo(other.decimal);
    return comparison < 0 ? -1 : comparison > 0 ? 1 : 0;
  }

  equals(other: Money): boolean {
    return this.decimal.equals(other.decimal);
  }

  add(other: Money, field: string): Money {
    return Money.required(this.decimal.plus(other.decimal).toString(), field);
  }

  subtract(other: Money, field: string): Money {
    return Money.required(this.decimal.minus(other.decimal).toString(), field);
  }

  toDecimal(): Prisma.Decimal {
    return this.decimal;
  }

  toString(): string {
    return this.serialized;
  }
}

/**
 * D112 (Q-25), the owner's word: whole riyals everywhere. An amount a
 * person sends (an agreement, a payment, a budget, a provider's price, an
 * offer) is whole; a fraction is refused with its own code and an Arabic
 * sentence, where it used to be accepted from any caller but the phone,
 * whose fields take whole amounts. `Money` itself still holds what a column
 * holds: a row saved with a fraction before this is read and summed as it
 * is.
 */
function wholeAmount(money: Money, field: string): string {
  if (!money.toDecimal().isInteger()) {
    throw new BadRequestException({
      statusCode: 400,
      code: 'MONEY_AMOUNT_NOT_WHOLE',
      message: 'المبلغ رقم صحيح، بدون كسور.',
      field,
    });
  }
  return money.toString();
}

/** An amount a request carries: bounded, and whole (Q-25). */
export function requiredMoneyAmount(
  value: unknown,
  field: string,
): string {
  return wholeAmount(Money.required(value, field), field);
}

/** [requiredMoneyAmount], or null for an absent or blank value. */
export function optionalMoneyAmount(
  value: unknown,
  field: string,
): string | null {
  const money = Money.optional(value, field);
  return money ? wholeAmount(money, field) : null;
}
