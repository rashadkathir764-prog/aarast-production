import { BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { optionalMoneyAmount, requiredMoneyAmount } from '../../../shared-kernel/money/money';
import type { MahrAgreementInput, MahrAgreementRequest } from './finance.port';

/**
 * Reads a06's answer: the mahr and the handed-over part as money, the rest's
 * day as a date. The amounts' rules (above zero, within the mahr) are the
 * finance policy's, checked when it is recorded.
 */
export function parseMahrAgreement(request: MahrAgreementRequest): MahrAgreementInput {
  const total = new Prisma.Decimal(requiredMoneyAmount(request.total, 'mahr.total'));
  const settledRaw = optionalMoneyAmount(request.settled, 'mahr.settled');
  const settled = new Prisma.Decimal(settledRaw ?? 0);
  let remainingDueAt: Date | null = null;
  if (request.remainingDueDate) {
    remainingDueAt = new Date(request.remainingDueDate);
    if (Number.isNaN(remainingDueAt.getTime())) {
      throw new BadRequestException('mahr.remainingDueDate must be a date');
    }
  }
  return { total, settled, remainingDueAt };
}
