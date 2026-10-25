import { ConflictException } from "@nestjs/common";
import { Prisma, QuoteOfferStatus } from "@prisma/client";

// B-06 (D41): before the customer accepts, every edit of an offer is a new
// version, and the customer sees «ايش تغيّر». A change names the field and
// its value before and after, as text the phone can show.

export type QuoteOfferField =
  | "title"
  | "message"
  | "amount"
  | "currency"
  | "validUntil";

export interface QuoteOfferChange {
  field: QuoteOfferField;
  from: string | null;
  to: string | null;
}

export interface QuoteOfferTerms {
  title: string | null;
  message: string | null;
  amount: Prisma.Decimal | string | null;
  currency: string;
  validUntil: Date | null;
}

/** What the money fields are: hidden together from a viewer without money access. */
const MONEY_FIELDS: ReadonlySet<QuoteOfferField> = new Set(["amount", "currency"]);

function amountText(value: Prisma.Decimal | string | null): string | null {
  if (value === null) return null;
  return new Prisma.Decimal(value).toString();
}

function dateText(value: Date | null): string | null {
  return value === null ? null : value.toISOString();
}

/** The fields that differ between two versions, in a fixed order. */
export function quoteOfferChanges(
  before: QuoteOfferTerms,
  after: QuoteOfferTerms,
): QuoteOfferChange[] {
  const pairs: Array<[QuoteOfferField, string | null, string | null]> = [
    ["amount", amountText(before.amount), amountText(after.amount)],
    ["currency", before.currency.toUpperCase(), after.currency.toUpperCase()],
    ["title", before.title, after.title],
    ["message", before.message, after.message],
    ["validUntil", dateText(before.validUntil), dateText(after.validUntil)],
  ];
  return pairs
    .filter(([, from, to]) => from !== to)
    .map(([field, from, to]) => ({ field, from, to }));
}

/** The stored changes of a version, read back defensively from JSON. */
export function readQuoteOfferChanges(value: Prisma.JsonValue | null | undefined): QuoteOfferChange[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((entry) => {
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) return [];
    const { field, from, to } = entry as Record<string, unknown>;
    if (
      typeof field !== "string" ||
      !["title", "message", "amount", "currency", "validUntil"].includes(field)
    ) {
      return [];
    }
    return [
      {
        field: field as QuoteOfferField,
        from: typeof from === "string" ? from : null,
        to: typeof to === "string" ? to : null,
      },
    ];
  });
}

/** The changes a viewer may read: without money access, no amounts. */
export function visibleQuoteOfferChanges(
  changes: readonly QuoteOfferChange[],
  showFinancials: boolean,
): QuoteOfferChange[] {
  return showFinancials
    ? [...changes]
    : changes.filter((change) => !MONEY_FIELDS.has(change.field));
}

/**
 * The version fields every offer response carries: its number, «ايش تغيّر»
 * against the version before (without amounts when the viewer sees no
 * money), and the withdrawal (B-03).
 */
export function quoteOfferVersionView(
  offer: {
    currentVersionNo: number;
    versionChanges: Prisma.JsonValue | null;
    revisedAt: Date | null;
    withdrawnAt: Date | null;
    withdrawnReason: string | null;
  },
  showFinancials: boolean,
) {
  return {
    versionNo: offer.currentVersionNo,
    changes: visibleQuoteOfferChanges(
      readQuoteOfferChanges(offer.versionChanges),
      showFinancials,
    ),
    revisedAt: offer.revisedAt,
    withdrawnAt: offer.withdrawnAt,
    withdrawnReason: offer.withdrawnReason,
  };
}

/**
 * An offer the customer has decided on, or one taken back, is never edited
 * (D41): the provider sends a new offer instead. One stable code for the phone.
 */
export function quoteOfferLocked(status: QuoteOfferStatus): ConflictException {
  const message =
    status === QuoteOfferStatus.ACCEPTED
      ? "العرض انقبل، فما يتعدّل. لو تغيّر شي، تكلّم معه في المحادثة."
      : status === QuoteOfferStatus.WITHDRAWN
        ? "سحبت هذا العرض. أرسل عرض جديد بدله."
        : "العرض انتهى أمره، فما يتعدّل. أرسل عرض جديد لو فتح طلب ثاني.";
  return new ConflictException({ code: "QUOTE_OFFER_LOCKED", message });
}

export function toQuoteOfferChangesJson(
  changes: readonly QuoteOfferChange[],
): Prisma.InputJsonValue {
  return changes.map((change) => ({
    field: change.field,
    from: change.from,
    to: change.to,
  }));
}
