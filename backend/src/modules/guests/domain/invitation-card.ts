import type { PlanEventTimeSlot, PlanEventType } from '@prisma/client';

// D83: the plan's one invitation card and the guests' events beyond the
// wedding. Pure rules, shared by the card writes, the public RSVP page and
// the WhatsApp text the server builds (one source for the words).

/** What the owner writes on the card; everything else comes from the plan. */
export interface InvitationCardFields {
  hostLine: string | null;
  freeText: string | null;
  photoUrl: string | null;
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
  NASHMA: 'النشمة',
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

export function planEventLabel(event: {
  type: PlanEventType;
  title: string | null;
}): string {
  const title = event.title?.trim() ?? '';
  return title || PLAN_EVENT_LABELS[event.type];
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
    mapUrl: null,
    address: null,
  };
  return {
    hostLine: input.hostLine === undefined ? base.hostLine : cleaned(input.hostLine),
    freeText: input.freeText === undefined ? base.freeText : cleaned(input.freeText),
    photoUrl: input.photoUrl === undefined ? base.photoUrl : cleaned(input.photoUrl),
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
