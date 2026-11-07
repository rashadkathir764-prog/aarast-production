import { registerDecorator, type ValidationArguments, type ValidationOptions } from 'class-validator';

/**
 * RA-BE-16: one count of a text's length for the phone and the server. The
 * phone's `maxLength` counts a character as the reader sees it (Flutter's
 * `characters.length`, an extended grapheme cluster); class-validator's
 * `@MaxLength` counts code points, so «مُحَمَّد» was 4 on the phone and 8 here,
 * and a joined emoji up to 7. With the same number on both sides the server
 * refused text the phone had accepted, and a queued change stuck as
 * «السيرفر رفضه». Human text a person types on the phone is limited with
 * `@MaxCharacters`, by the same number as its field there.
 */
// `Intl.Segmenter` is in Node 24, its type in TypeScript's ES2022 library;
// the build targets ES2021 (a newer target changes how class fields are
// emitted, which the decorators depend on), so the one call is typed here.
type GraphemeSegmenter = { segment(input: string): Iterable<unknown> };
const { Segmenter } = Intl as unknown as {
  Segmenter: new (locale: undefined, options: { granularity: 'grapheme' }) => GraphemeSegmenter;
};
const graphemes = new Segmenter(undefined, { granularity: 'grapheme' });

export function characterCount(value: string): number {
  let count = 0;
  for (const _segment of graphemes.segment(value)) count++;
  return count;
}

/**
 * No real character needs more bytes (the longest joined emoji is about 35);
 * a letter padded with a thousand marks is one character to the phone, so
 * the bytes stop it.
 */
export const MAX_BYTES_PER_CHARACTER = 64;

export function withinCharacters(value: string, maximum: number): boolean {
  return (
    characterCount(value) <= maximum &&
    Buffer.byteLength(value, 'utf8') <= maximum * MAX_BYTES_PER_CHARACTER
  );
}

export function MaxCharacters(
  maximum: number,
  validationOptions?: ValidationOptions,
): PropertyDecorator {
  return (target: object, propertyName: string | symbol) => {
    registerDecorator({
      name: 'maxCharacters',
      target: target.constructor,
      propertyName: propertyName.toString(),
      constraints: [maximum],
      options: validationOptions,
      validator: {
        validate(value: unknown): boolean {
          // The type is @IsString's to say; this rule reads text only.
          return typeof value !== 'string' || withinCharacters(value, maximum);
        },
        defaultMessage(args: ValidationArguments): string {
          return `${args.property} must be at most ${maximum} characters`;
        },
      },
    });
  };
}
