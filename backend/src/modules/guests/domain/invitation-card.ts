import type { PlanEventTimeSlot, PlanEventType } from '@prisma/client';

// D83: the plan's one invitation card and the guests' events beyond the
// wedding. Pure rules, shared by the card writes, the public RSVP page and
// the WhatsApp text the server builds (one source for the words).

/**
 * D116: what the card's picture is: a photo drawn inside the card Aarast
 * lays out (PHOTO), or a card designed elsewhere, shown whole (CARD).
 */
export type InvitationCardPhotoKind = 'PHOTO' | 'CARD';

/**
 * What the owner writes on the card; everything else comes from the plan.
 * D116: the map link and the address are the wedding row's (each occasion
 * has its own place); the card still names them, read from that row, so an
 * app from before D116 keeps reading and writing them where it did.
 */
export interface InvitationCardFields {
  hostLine: string | null;
  freeText: string | null;
  photoUrl: string | null;
  photoKind: InvitationCardPhotoKind;
  mapUrl: string | null;
  address: string | null;
}

/** A write: a missing key keeps the stored value, null or blank clears it. */
export type InvitationCardInput = Partial<InvitationCardFields>;

export const INVITATION_CARD_LIMITS = {
  hostLine: 80,
  freeText: 300,
  address: 160,
  mapUrl: 500,
} as const;

/** The guests' word for each event when the owner gave it no title. */
export const PLAN_EVENT_LABELS: Record<PlanEventType, string> = {
  WEDDING: 'العرس',
  SAMRA: 'السمرة',
  MAQEEL: 'المقيل',
  HAFLA: 'الحفلة',
  // The bride's night, as the phone, the journey profile and the research
  // write it (it was spelt «النشمة» here alone, so one event had two names).
  NASHMA: 'النسمة',
  AQD: 'عقد القران',
  LUNCH: 'الغداء',
  DINNER: 'العشاء',
  CUSTOM: 'مناسبة',
};

export const PLAN_EVENT_TIME_SLOT_LABELS: Record<PlanEventTimeSlot, string> = {
  DUHA: 'الضحى',
  DHUHR: 'الظهر',
  AFTER_DHUHR: 'بعد الظهر',
  AFTER_ASR: 'بعد العصر',
  AFTER_MAGHRIB: 'بعد المغرب',
  AFTER_ISHA: 'بعد العشاء',
  // An exact time is spoken as the time itself (planEventTimeLabel).
  EXACT: '',
};

/**
 * D55: in a bride's plan the groom's night and afternoon are hers, named in
 * her words as the phone names them (`PlanEventType.label`).
 */
const BRIDE_EVENT_WORDS: Partial<Record<PlanEventType, string>> = {
  SAMRA: PLAN_EVENT_LABELS.HAFLA,
  MAQEEL: PLAN_EVENT_LABELS.NASHMA,
};

/** What an occasion's name depends on beyond itself: its plan. */
export interface PlanEventNaming {
  bride: boolean;
  /** The names the plan's other occasions are already called by. */
  taken: ReadonlySet<string>;
}

type NamedEvent = { type: PlanEventType; title: string | null };

function ownName(event: NamedEvent): string {
  return event.title?.trim() || PLAN_EVENT_LABELS[event.type];
}

/** The plan's naming, from its persona and all its occasions. */
export function planEventNaming(
  persona: string | null | undefined,
  events: readonly NamedEvent[],
): PlanEventNaming {
  return {
    bride: persona === 'BRIDE',
    taken: new Set(
      events
        .filter((event) => event.title?.trim() || !BRIDE_EVENT_WORDS[event.type])
        .map(ownName),
    ),
  };
}

/**
 * The guests' name for an occasion: the couple's title, else its kind's
 * word, in a bride's plan hers (D55). A word another occasion of her plan is
 * already called by (her own «الحفلة», or one titled so) is not given twice:
 * the groom's night keeps «السمرة» there, as its afternoon «المقيل» (a date
 * cannot tell them apart: an occasion may have none, or the same day).
 */
export function planEventLabel(event: NamedEvent, naming: PlanEventNaming): string {
  const title = event.title?.trim() ?? '';
  if (title) return title;
  const hers = naming.bride ? BRIDE_EVENT_WORDS[event.type] : undefined;
  return hers && !naming.taken.has(hers) ? hers : PLAN_EVENT_LABELS[event.type];
}

/** «الساعة 8:30» or the slot's name; nothing when neither was set. */
export function planEventTimeLabel(event: {
  timeSlot: PlanEventTimeSlot | null;
  exactTime: string | null;
}): string | null {
  const exact = event.exactTime?.trim() ?? '';
  if (exact) return `الساعة ${exact}`;
  const slot = event.timeSlot ? PLAN_EVENT_TIME_SLOT_LABELS[event.timeSlot] : '';
  return slot || null;
}

/**
 * The events a guest can be invited to on top of the wedding: every event of
 * the plan except the wedding row itself (every guest is invited to that).
 */
export function invitableEvents<T extends { type: PlanEventType }>(
  events: readonly T[],
): T[] {
  return events.filter((event) => event.type !== 'WEDDING');
}

function cleaned(value: string | null | undefined): string | null {
  const trimmed = value?.trim() ?? '';
  return trimmed ? trimmed : null;
}

/** The stored card after a write; untouched keys keep their value. */
export function mergeInvitationCard(
  current: InvitationCardFields | null,
  input: InvitationCardInput,
): InvitationCardFields {
  const base: InvitationCardFields = current ?? {
    hostLine: null,
    freeText: null,
    photoUrl: null,
    photoKind: 'PHOTO',
    mapUrl: null,
    address: null,
  };
  return {
    hostLine: input.hostLine === undefined ? base.hostLine : cleaned(input.hostLine),
    freeText: input.freeText === undefined ? base.freeText : cleaned(input.freeText),
    photoUrl: input.photoUrl === undefined ? base.photoUrl : cleaned(input.photoUrl),
    photoKind: input.photoKind ?? base.photoKind,
    mapUrl: input.mapUrl === undefined ? base.mapUrl : cleaned(input.mapUrl),
    address: input.address === undefined ? base.address : cleaned(input.address),
  };
}

/** A map link the page may open: HTTPS, and short enough to be a link. */
export function isAcceptableMapUrl(value: string): boolean {
  if (value.length > INVITATION_CARD_LIMITS.mapUrl) return false;
  try {
    return new URL(value).protocol === 'https:';
  } catch {
    return false;
  }
}

export function hasCardContent(card: InvitationCardFields | null): boolean {
  return (
    !!card &&
    Object.values(card).some((value) => typeof value === 'string' && value.length > 0)
  );
}
