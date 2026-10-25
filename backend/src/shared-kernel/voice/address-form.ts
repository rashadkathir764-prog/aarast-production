/**
 * How the app speaks to a reader (B5, JOURNEY_PROFILE.md §2): the groom in
 * the masculine, the bride in the feminine. The form follows who reads, not
 * whose plan it is: a groom who joined the bride's plan is still spoken to
 * as a man (q09, q17).
 */
export type AddressForm = 'MASCULINE' | 'FEMININE';

/** One sentence in its two forms. */
export interface GenderedText {
  masculine: string;
  feminine: string;
}

export function gendered(masculine: string, feminine: string): GenderedText {
  return { masculine, feminine };
}

/** A sentence that is the same for both, or one in its two forms. */
export type AddressedText = string | GenderedText;

export function textFor(form: AddressForm, text: AddressedText): string {
  if (typeof text === 'string') return text;
  return form === 'FEMININE' ? text.feminine : text.masculine;
}

export function isGendered(text: AddressedText): text is GenderedText {
  return typeof text !== 'string';
}

function formOfPersona(value: string | null | undefined): AddressForm | null {
  if (value === 'GROOM') return 'MASCULINE';
  if (value === 'BRIDE') return 'FEMININE';
  return null;
}

/**
 * The reader's form, from what is known of them, best first: the account's
 * own persona (the person chose «عريس» or «عروسة»), then the partner role
 * they hold in this plan (GROOM or BRIDE). Someone the app knows nothing
 * about (a helper, a parent) is spoken to as the plan's own party is: the
 * bride's plan is the women's wedding, so the feminine; any other the
 * masculine, Arabic's general form.
 */
export function addressFormOf(reader: {
  accountPersona?: string | null;
  memberRole?: string | null;
  planPersona?: string | null;
}): AddressForm {
  return (
    formOfPersona(reader.accountPersona) ??
    formOfPersona(reader.memberRole) ??
    (reader.planPersona === 'BRIDE' ? 'FEMININE' : 'MASCULINE')
  );
}
