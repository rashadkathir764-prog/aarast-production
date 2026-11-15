// D116: what a guest was told of each occasion and where they stand with it.
// Pure rules, shared by the guest list the phone reads, the send that the
// phone prepares and the counts; the phone keeps a twin of them
// (guest_invitations.dart), both held by guest_invitation_fixtures.json.

export type GuestAnswer = 'PENDING' | 'CONFIRMED' | 'DECLINED';

export type InvitationSendKind = 'INVITATION' | 'ADDITION' | 'CHANGE' | 'REMINDER';

/** One occasion as its row says it: the wedding row among them. */
export interface OccasionVersion {
  planEventId: string;
  version: number;
}

/** A guest's invitation to one occasion and what they answered to it. */
export interface InviteAnswer {
  planEventId: string;
  attendanceStatus: GuestAnswer;
  companionsCount: number;
  respondedAt: Date | null;
  /** The version answered; null for an answer from before versions. */
  answeredVersion: number | null;
}

/** A send the person said they sent: its kind, when, and what it named. */
export interface SentInvitation {
  kind: InvitationSendKind;
  sentAt: Date;
  events: ReadonlyArray<{ planEventId: string; version: number }>;
}

/** What the guest was told of one occasion: the last version and when. */
export interface ToldOccasion {
  version: number;
  at: Date;
  /** The last reminder of it, if any. */
  remindedAt: Date | null;
}

/**
 * Per occasion, the highest version a sent invitation named, when it was
 * told, and the last reminder. Only sends the person said were sent count.
 */
export function toldOccasions(
  sends: ReadonlyArray<SentInvitation>,
): Map<string, ToldOccasion> {
  const told = new Map<string, ToldOccasion>();
  for (const send of sends) {
    for (const event of send.events) {
      const before = told.get(event.planEventId);
      const reminded =
        send.kind === 'REMINDER'
          ? latest(before?.remindedAt ?? null, send.sentAt)
          : (before?.remindedAt ?? null);
      if (!before || event.version > before.version) {
        told.set(event.planEventId, {
          version: event.version,
          at: send.sentAt,
          remindedAt: reminded,
        });
      } else {
        told.set(event.planEventId, {
          version: before.version,
          at: event.version === before.version ? latest(before.at, send.sentAt)! : before.at,
          remindedAt: reminded,
        });
      }
    }
  }
  return told;
}

function latest(a: Date | null, b: Date | null): Date | null {
  if (!a) return b;
  if (!b) return a;
  return a.getTime() >= b.getTime() ? a : b;
}

/** Where a guest stands with one occasion, as the guest list says it. */
export type OccasionStanding =
  /** Nothing sent names it, and the guest did not answer it. */
  | 'NOT_TOLD'
  /** Told of an older day, time or place, and not answering since. */
  | 'TOLD_OLD'
  /** Told, no answer yet. */
  | 'WAITING'
  /** Coming, to the occasion as it is now. */
  | 'CONFIRMED'
  /** Said they were coming before the day, time or place changed. */
  | 'CONFIRMED_OLD'
  | 'DECLINED';

export function occasionStanding(
  invite: InviteAnswer,
  occasion: OccasionVersion,
  told: ToldOccasion | undefined,
): OccasionStanding {
  if (invite.attendanceStatus === 'CONFIRMED') {
    const answered = invite.answeredVersion ?? occasion.version;
    return answered < occasion.version ? 'CONFIRMED_OLD' : 'CONFIRMED';
  }
  if (invite.attendanceStatus === 'DECLINED') return 'DECLINED';
  if (!told) return 'NOT_TOLD';
  return told.version < occasion.version ? 'TOLD_OLD' : 'WAITING';
}

/** What one occasion's guests come to, said once and read everywhere. */
export interface OccasionCounts {
  invited: number;
  confirmed: number;
  /** Of [confirmed]: those who confirmed before a change. */
  confirmedOld: number;
  declined: number;
  waiting: number;
  notTold: number;
  /** Told of an older version and not answering since. */
  toldOld: number;
  /** The companions the confirmed bring. */
  companions: number;
}

export function occasionCounts(
  standings: ReadonlyArray<{ standing: OccasionStanding; companionsCount: number }>,
): OccasionCounts {
  const counts: OccasionCounts = {
    invited: 0,
    confirmed: 0,
    confirmedOld: 0,
    declined: 0,
    waiting: 0,
    notTold: 0,
    toldOld: 0,
    companions: 0,
  };
  for (const { standing, companionsCount } of standings) {
    counts.invited += 1;
    switch (standing) {
      case 'CONFIRMED':
      case 'CONFIRMED_OLD':
        counts.confirmed += 1;
        counts.companions += companionsCount;
        if (standing === 'CONFIRMED_OLD') counts.confirmedOld += 1;
        break;
      case 'DECLINED':
        counts.declined += 1;
        break;
      case 'WAITING':
        counts.waiting += 1;
        break;
      case 'TOLD_OLD':
        counts.toldOld += 1;
        break;
      case 'NOT_TOLD':
        counts.notTold += 1;
        break;
    }
  }
  return counts;
}

/**
 * What a send of [kind] names, among the guest's occasions in scope (all of
 * them, or the one the send is about). Empty: nothing to send of that kind.
 *
 * - INVITATION: the occasions in scope, all of them.
 * - ADDITION: those never told and not answered.
 * - CHANGE: those told of an older version, or confirmed before a change.
 * - REMINDER: those told as they are now and not answered.
 */
export function occasionsToName(
  kind: InvitationSendKind,
  scope: ReadonlyArray<{ standing: OccasionStanding; planEventId: string }>,
): string[] {
  const pick = (wanted: readonly OccasionStanding[]) =>
    scope.filter((entry) => wanted.includes(entry.standing)).map((entry) => entry.planEventId);
  switch (kind) {
    case 'INVITATION':
      return scope.map((entry) => entry.planEventId);
    case 'ADDITION':
      return pick(['NOT_TOLD']);
    case 'CHANGE':
      return pick(['TOLD_OLD', 'CONFIRMED_OLD']);
    case 'REMINDER':
      return pick(['WAITING']);
  }
}

/**
 * The send a guest is due, for the occasions in scope, or null when they
 * are told and answering. A guest never told anything is invited; one told
 * of something but not of all is told of the rest; one holding an older day
 * is told of the change; one told and silent is reminded.
 */
export function dueSend(
  scope: ReadonlyArray<{ standing: OccasionStanding; planEventId: string }>,
  everTold: boolean,
): InvitationSendKind | null {
  const has = (standing: OccasionStanding) =>
    scope.some((entry) => entry.standing === standing);
  if (has('NOT_TOLD')) return everTold ? 'ADDITION' : 'INVITATION';
  if (has('TOLD_OLD') || has('CONFIRMED_OLD')) return 'CHANGE';
  if (has('WAITING')) return 'REMINDER';
  return null;
}
