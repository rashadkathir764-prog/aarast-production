import { BadRequestException } from '@nestjs/common';

export class PhoneNormalizer {
  static normalizeRequired(value: string, field = 'phone'): string {
    const normalized = this.normalizeOptional(value, field);
    if (!normalized) {
      throw this.invalidPhone(field);
    }
    return normalized;
  }

  static normalizeOptional(
    value: string | null | undefined,
    field = 'phone',
  ): string | null {
    const raw = value?.trim() ?? '';
    if (!raw) return null;

    const compact = this.toAsciiDigits(raw).replace(/[\s\-()]/g, '');
    if (!/^(?:\+|00)?[0-9]+$/.test(compact)) {
      throw this.invalidPhone(field);
    }

    const digits = compact.replace(/^(?:\+|00)/, '');
    const yemeniLocal = this.yemeniLocalDigits(compact, digits);
    if (yemeniLocal) {
      return `+967${yemeniLocal}`;
    }

    if (this.looksLikeMalformedYemeniNumber(compact, digits)) {
      throw this.invalidPhone(field);
    }

    if (digits.length < 7 || digits.length > 15) {
      throw this.invalidPhone(field);
    }

    if (compact.startsWith('+') || compact.startsWith('00')) {
      return `+${digits}`;
    }

    return digits;
  }

  static areEquivalent(
    first: string | null | undefined,
    second: string | null | undefined,
  ): boolean {
    try {
      const firstNormalized = this.normalizeOptional(first);
      const secondNormalized = this.normalizeOptional(second);
      return Boolean(
        firstNormalized &&
          secondNormalized &&
          firstNormalized === secondNormalized,
      );
    } catch {
      return false;
    }
  }

  static lookupVariants(value: string): string[] {
    const normalized = this.normalizeRequired(value);
    const variants = new Set<string>([normalized]);

    if (normalized.startsWith('+967')) {
      const local = normalized.slice(4);
      variants.add(`00967${local}`);
      variants.add(`967${local}`);
      variants.add(`0${local}`);
      variants.add(local);
    } else if (normalized.startsWith('+')) {
      const digits = normalized.slice(1);
      variants.add(`00${digits}`);
      variants.add(digits);
    }

    return [...variants];
  }

  static toAsciiDigits(value: string): string {
    let result = '';
    for (const char of value) {
      const codePoint = char.codePointAt(0);
      if (codePoint !== undefined && codePoint >= 0x0660 && codePoint <= 0x0669) {
        result += String.fromCharCode(0x30 + codePoint - 0x0660);
      } else if (
        codePoint !== undefined &&
        codePoint >= 0x06f0 &&
        codePoint <= 0x06f9
      ) {
        result += String.fromCharCode(0x30 + codePoint - 0x06f0);
      } else {
        result += char;
      }
    }
    return result;
  }

  private static yemeniLocalDigits(
    compact: string,
    digits: string,
  ): string | null {
    let local: string | null = null;

    if (compact.startsWith('+967') || compact.startsWith('00967')) {
      local = digits.slice(3);
    } else if (digits.startsWith('967')) {
      local = digits.slice(3);
    } else if (digits.length === 10 && digits.startsWith('0')) {
      local = digits.slice(1);
    } else if (digits.length === 9) {
      local = digits;
    }

    return local?.length === 8 || local?.length === 9 ? local : null;
  }

  private static looksLikeMalformedYemeniNumber(
    compact: string,
    digits: string,
  ): boolean {
    return (
      compact.startsWith('+967') ||
      compact.startsWith('00967') ||
      digits.startsWith('967')
    );
  }

  private static invalidPhone(field: string): BadRequestException {
    return new BadRequestException(`${field} must be a valid phone number`);
  }
}
