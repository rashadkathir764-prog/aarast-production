import { Injectable } from '@nestjs/common';
import type { ArgumentMetadata, PipeTransform } from '@nestjs/common';

/**
 * RA-BE-13: PostgreSQL cannot store U+0000 in text, so a NUL anywhere in a
 * request (a pasted name, a phone contact, `%00` in a path) reached the
 * database as an unclassified Prisma error: a 500, which the phone's queue
 * retries five times before parking the change under a false «check your
 * connection». The character means nothing in any Aarast text, so it is
 * removed from every string of the body, the query and the path before
 * validation. Uploaded files and other custom arguments are left alone.
 */
export function stripNul(value: unknown): unknown {
  if (typeof value === 'string') {
    return value.includes('\u0000') ? value.replaceAll('\u0000', '') : value;
  }
  if (Array.isArray(value)) return value.map(stripNul);
  if (value !== null && typeof value === 'object') {
    const prototype = Object.getPrototypeOf(value);
    if (prototype !== Object.prototype && prototype !== null) return value;
    const cleaned: Record<string, unknown> = {};
    for (const [key, entry] of Object.entries(value)) cleaned[key] = stripNul(entry);
    return cleaned;
  }
  return value;
}

@Injectable()
export class StripNulPipe implements PipeTransform {
  transform(value: unknown, metadata: Pick<ArgumentMetadata, 'type'>): unknown {
    return metadata.type === 'custom' ? value : stripNul(value);
  }
}
