import { BadRequestException, ConflictException } from "@nestjs/common";
import { Prisma, QuoteOfferStatus } from "@prisma/client";
import { withinCharacters } from "../../../shared-kernel/text/text-length";

// B-06 (D41): before the customer accepts, every edit of an offer is a new
// version, and the customer sees «ايش تغيّر». A change names the field and
// its value before and after, as text the phone can show.

export type QuoteOfferField =
  | "title"
  | "message"
  | "amount"
  | "currency"
  | "validUntil"
  | "lines"
  | "deliveryDays";

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
  lines?: Prisma.JsonValue | null;
  deliveryDays?: number | null;
}

/** B-07: one line of what the price covers. */
export interface QuoteOfferLine {
  label: string;
  kind: "INCLUDED" | "EXCLUDED" | "EXTRA";
  /** An EXTRA's price; never on the other kinds. */
  amount: string | null;
}

const LINE_KINDS = ["INCLUDED", "EXCLUDED", "EXTRA"] as const;
const MAX_LINES = 30;

/**
 * B-07: the lines a provider sent, checked and normalized (trimmed labels,
 * a positive amount only on EXTRA). Undefined leaves the lines unchanged;
 * null or an empty list clears them.
 */
export function parseQuoteOfferLines(input: unknown): QuoteOfferLine[] | null | undefined {
  if (input === undefined) return undefined;
  if (input === null) return null;
  const invalid = (message: string) =>
    new BadRequestException({ code: "QUOTE_OFFER_LINES_INVALID", message });
  if (!Array.isArray(input) || input.length > MAX_LINES) {
    throw invalid(`محتوى العرض قائمة، وأقصاها ${MAX_LINES} سطر.`);
  }
  const lines = input.map((entry) => {
    if (!entry || typeof entry !== "object") throw invalid("سطر غير صحيح في محتوى العرض.");
    const { label, kind, amount } = entry as Record<string, unknown>;
    const text = typeof label === "string" ? label.trim().replace(/\s+/g, " ") : "";
    // RA-BE-16: counted as the phone counts the field (text-length.ts).
    if (!text || !withinCharacters(text, 120)) {
      throw invalid("كل سطر يحتاج نص قصير (120 حرف أو أقل).");
    }
    if (!LINE_KINDS.includes(kind as QuoteOfferLine["kind"])) {
      throw invalid("نوع السطر: يشمل أو ما يشمل أو إضافة.");
    }
    let price: string | null = null;
    if (amount !== undefined && amount !== null && amount !== "") {
      if (kind !== "EXTRA") throw invalid("السعر يكون على «إضافة» بس.");
      const raw = String(amount).trim();
      if (!/^\d{1,12}(\.\d{1,2})?$/.test(raw) || Number(raw) <= 0) {
        throw invalid("سعر الإضافة رقم أكبر من صفر.");
      }
      price = new Prisma.Decimal(raw).toString();
    }
    return { label: text, kind: kind as QuoteOfferLine["kind"], amount: price };
  });
  return lines.length === 0 ? null : lines;
}

/** The stored lines, read back defensively; amounts only for a money viewer. */
export function readQuoteOfferLines(
  value: Prisma.JsonValue | null | undefined,
  showFinancials = true,
): QuoteOfferLine[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((entry) => {
    if (!entry || typeof entry !== "object" || Array.isArray(entry)) return [];
    const { label, kind, amount } = entry as Record<string, unknown>;
    if (typeof label !== "string" || !LINE_KINDS.includes(kind as QuoteOfferLine["kind"])) {
      return [];
    }
    return [
      {
        label,
        kind: kind as QuoteOfferLine["kind"],
        amount: showFinancials && typeof amount === "string" ? amount : null,
      },
    ];
  });
}

function linesText(value: Prisma.JsonValue | null | undefined): string | null {
  const lines = readQuoteOfferLines(value);
  if (lines.length === 0) return null;
  const word = { INCLUDED: "يشمل", EXCLUDED: "ما يشمل", EXTRA: "إضافة" } as const;
  return lines
    .map((line) => `${word[line.kind]}: ${line.label}${line.amount ? ` (${line.amount})` : ""}`)
    .join(" · ");
}

/** B-11: why a customer turned an offer down. */
export const QUOTE_REJECT_REASONS = ["PRICE", "CHOSE_OTHER", "DATE", "NONE"] as const;

/** What the money fields are: hidden together from a viewer without money access. */
const MONEY_FIELDS: ReadonlySet<QuoteOfferField> = new Set(["amount", "currency", "lines"]);

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
    ["lines", linesText(before.lines), linesText(after.lines)],
    [
      "deliveryDays",
      before.deliveryDays == null ? null : String(before.deliveryDays),
      after.deliveryDays == null ? null : String(after.deliveryDays),
    ],
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
      ![
        "title",
        "message",
        "amount",
        "currency",
        "validUntil",
        "lines",
        "deliveryDays",
      ].includes(field)
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
    lines?: Prisma.JsonValue | null;
    deliveryDays?: number | null;
    rejectReason?: string | null;
    rejectMessage?: string | null;
  },
  showFinancials: boolean,
) {
  return {
    // B-07: what the price covers (an extra's price only with money access).
    lines: readQuoteOfferLines(offer.lines, showFinancials),
    deliveryDays: offer.deliveryDays ?? null,
    // B-11: why the customer turned it down.
    rejectReason: offer.rejectReason ?? null,
    rejectMessage: offer.rejectMessage ?? null,
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
