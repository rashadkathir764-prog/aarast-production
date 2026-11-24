import { BadRequestException } from '@nestjs/common';

export interface AdminPagination {
  page: number;
  limit: number;
  skip: number;
}

/** A back-office list's page and its size (20 by default, at most 100). */
export function parseAdminPagination(pageValue?: string, limitValue?: string): AdminPagination {
  const page = parsePositiveInteger(pageValue ?? '1', 'page');
  const limit = Math.min(parsePositiveInteger(limitValue ?? '20', 'limit'), 100);
  return { page, limit, skip: (page - 1) * limit };
}

function parsePositiveInteger(value: string, field: string): number {
  if (!/^\d+$/.test(value)) {
    throw new BadRequestException(`${field} must be a positive integer`);
  }
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 1) {
    throw new BadRequestException(`${field} must be a positive integer`);
  }
  return parsed;
}
