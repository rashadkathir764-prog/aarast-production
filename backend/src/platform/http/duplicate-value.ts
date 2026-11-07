import { ConflictException } from '@nestjs/common';

/**
 * RA-AD-13: a value that must be unique is taken (a city's name, a
 * category's slug, a catalog item's key). A bare 409 reads as «the data
 * changed, refresh», which never fixes a duplicate; the code lets a client
 * say «it exists already». It adds a field, and breaks no client (D93).
 */
export const DUPLICATE_VALUE = 'DUPLICATE_VALUE';

export function duplicateValueConflict(message: string): ConflictException {
  return new ConflictException({ statusCode: 409, code: DUPLICATE_VALUE, message });
}
