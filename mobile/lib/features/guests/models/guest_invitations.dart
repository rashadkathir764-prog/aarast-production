// D116: what a guest was told of each occasion and where they stand with it,
// and the WhatsApp text the server builds. The server's rules
// (backend/src/modules/guests/domain/guest-invitations.ts and
// buildRsvpMessage in guest-rsvp.service.ts) are the source; this is their
// twin, so the guests tab counts and the card's preview read the same
// without the server. test/features/guests/guest_invitation_parity_test.dart
// holds the two to the same answers (test/fixtures/
// guest_invitation_fixtures.json, written by the server's test).

/// Where a guest stands with one occasion.
enum OccasionStanding {
  /// Nothing sent names it, and the guest did not answer it.
  notTold('NOT_TOLD'),

  /// Told of an older day, time or place, and not answering since.
  toldOld('TOLD_OLD'),

  /// Told, no answer yet.
  waiting('WAITING'),

  /// Coming, to the occasion as it is now.
  confirmed('CONFIRMED'),

  /// Said they were coming before the day, time or place changed.
  confirmedOld('CONFIRMED_OLD'),
  declined('DECLINED');

  const OccasionStanding(this.wire);

  final String wire;

  bool get isConfirmed => this == confirmed || this == confirmedOld;
}

/// What a send is: the first invitation, one more occasion, a change, a
/// reminder.
enum InvitationSendKind {
  invitation('INVITATION'),
  addition('ADDITION'),
  change('CHANGE'),
  reminder('REMINDER');

  const InvitationSendKind(this.wire);

  final String wire;

  static InvitationSendKind? fromWire(Object? value) {
    for (final kind in values) {
      if (kind.wire == value) return kind;
    }
    return null;
  }
}

/// A guest's invitation to one occasion and what they answered to it.
class InviteAnswer {
  const InviteAnswer({
    required this.planEventId,
    this.attendanceStatus = 'PENDING',
    this.companionsCount = 0,
    this.answeredVersion,
  });

  final String planEventId;
  final String attendanceStatus;
  final int companionsCount;

  /// The version answered; null for an answer from before versions.
  final int? answeredVersion;
}

/// What the guest was told of one occasion.
class ToldVersion {
  const ToldVersion({required this.version, required this.at, this.remindedAt});

  final int version;
  final DateTime at;
  final DateTime? remindedAt;
}

/// A send the person said was sent: its kind, when, and what it named.
class SentInvitation {
  const SentInvitation({
    required this.kind,
    required this.sentAt,
    required this.events,
  });

  final InvitationSendKind kind;
  final DateTime sentAt;
  final List<({String planEventId, int version})> events;
}

DateTime? _latest(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) || a.isAtSameMomentAs(b) ? a : b;
}

/// Per occasion, the highest version a sent invitation named, when, and the
/// last reminder (the server reads the same from its record).
Map<String, ToldVersion> toldOccasions(Iterable<SentInvitation> sends) {
  final told = <String, ToldVersion>{};
  for (final send in sends) {
    for (final event in send.events) {
      final before = told[event.planEventId];
      final reminded = send.kind == InvitationSendKind.reminder
          ? _latest(before?.remindedAt, send.sentAt)
          : before?.remindedAt;
      if (before == null || event.version > before.version) {
        told[event.planEventId] = ToldVersion(
          version: event.version,
          at: send.sentAt,
          remindedAt: reminded,
        );
      } else {
        told[event.planEventId] = ToldVersion(
          version: before.version,
          at: event.version == before.version
              ? _latest(before.at, send.sentAt)!
              : before.at,
          remindedAt: reminded,
        );
      }
    }
  }
  return told;
}

OccasionStanding occasionStanding(
  InviteAnswer invite,
  int version,
  ToldVersion? told,
) {
  if (invite.attendanceStatus == 'CONFIRMED') {
    final answered = invite.answeredVersion ?? version;
    return answered < version
        ? OccasionStanding.confirmedOld
        : OccasionStanding.confirmed;
  }
  if (invite.attendanceStatus == 'DECLINED') return OccasionStanding.declined;
  if (told == null) return OccasionStanding.notTold;
  return told.version < version
      ? OccasionStanding.toldOld
      : OccasionStanding.waiting;
}

/// What one occasion's guests come to, said once and read everywhere.
class OccasionCounts {
  const OccasionCounts({
    this.invited = 0,
    this.confirmed = 0,
    this.confirmedOld = 0,
    this.declined = 0,
    this.waiting = 0,
    this.notTold = 0,
    this.toldOld = 0,
    this.companions = 0,
  });

  final int invited;
  final int confirmed;

  /// Of [confirmed]: those who confirmed before a change.
  final int confirmedOld;
  final int declined;
  final int waiting;
  final int notTold;
  final int toldOld;

  /// The companions the confirmed bring.
  final int companions;

  /// Who has not answered: told and silent, or told an older version.
  int get unanswered => waiting + toldOld;

  /// The people expected: the confirmed and their companions.
  int get people => confirmed + companions;

  Map<String, int> toJson() => {
    'invited': invited,
    'confirmed': confirmed,
    'confirmedOld': confirmedOld,
    'declined': declined,
    'waiting': waiting,
    'notTold': notTold,
    'toldOld': toldOld,
    'companions': companions,
  };
}

OccasionCounts occasionCounts(
  Iterable<({OccasionStanding standing, int companionsCount})> standings,
) {
  var invited = 0;
  var confirmed = 0;
  var confirmedOld = 0;
  var declined = 0;
  var waiting = 0;
  var notTold = 0;
  var toldOld = 0;
  var companions = 0;
  for (final (:standing, :companionsCount) in standings) {
    invited += 1;
    switch (standing) {
      case OccasionStanding.confirmed:
      case OccasionStanding.confirmedOld:
        confirmed += 1;
        companions += companionsCount;
        if (standing == OccasionStanding.confirmedOld) confirmedOld += 1;
      case OccasionStanding.declined:
        declined += 1;
      case OccasionStanding.waiting:
        waiting += 1;
      case OccasionStanding.toldOld:
        toldOld += 1;
      case OccasionStanding.notTold:
        notTold += 1;
    }
  }
  return OccasionCounts(
    invited: invited,
    confirmed: confirmed,
    confirmedOld: confirmedOld,
    declined: declined,
    waiting: waiting,
    notTold: notTold,
    toldOld: toldOld,
    companions: companions,
  );
}

/// What a send of [kind] names among the occasions in [scope]; empty when
/// there is nothing to send of that kind.
List<String> occasionsToName(
  InvitationSendKind kind,
  Iterable<({String planEventId, OccasionStanding standing})> scope,
) {
  List<String> pick(Set<OccasionStanding> wanted) => [
    for (final entry in scope)
      if (wanted.contains(entry.standing)) entry.planEventId,
  ];
  return switch (kind) {
    InvitationSendKind.invitation => [
      for (final entry in scope) entry.planEventId,
    ],
    InvitationSendKind.addition => pick({OccasionStanding.notTold}),
    InvitationSendKind.change => pick({
      OccasionStanding.toldOld,
      OccasionStanding.confirmedOld,
    }),
    InvitationSendKind.reminder => pick({OccasionStanding.waiting}),
  };
}

/// The send a guest is due for the occasions in [scope], or null when told
/// and answering.
InvitationSendKind? dueSend(
  Iterable<({String planEventId, OccasionStanding standing})> scope, {
  required bool everTold,
}) {
  bool has(OccasionStanding standing) =>
      scope.any((entry) => entry.standing == standing);
  if (has(OccasionStanding.notTold)) {
    return everTold
        ? InvitationSendKind.addition
        : InvitationSendKind.invitation;
  }
  if (has(OccasionStanding.toldOld) || has(OccasionStanding.confirmedOld)) {
    return InvitationSendKind.change;
  }
  if (has(OccasionStanding.waiting)) return InvitationSendKind.reminder;
  return null;
}

// --------------------------------------------------------------- the text

/// One occasion as the text names it.
class InvitationOccasionText {
  const InvitationOccasionText({
    required this.label,
    required this.isWedding,
    this.date,
    this.timeSlot,
    this.exactTime,
    this.placeLabel,
    this.address,
    this.mapUrl,
  });

  final String label;
  final bool isWedding;
  final DateTime? date;

  /// The server's wire value (`AFTER_ISHA`), so the words are the server's.
  final String? timeSlot;
  final String? exactTime;
  final String? placeLabel;
  final String? address;
  final String? mapUrl;
}

/// A text past this many characters drops its map links (the server's
/// RSVP_MESSAGE_SOFT_LIMIT).
const invitationMessageSoftLimit = 1500;

/// The server's words for each time of day (PLAN_EVENT_TIME_SLOT_LABELS).
const _slotWords = {
  'DUHA': 'الضحى',
  'DHUHR': 'الظهر',
  'AFTER_DHUHR': 'بعد الظهر',
  'AFTER_ASR': 'بعد العصر',
  'AFTER_MAGHRIB': 'بعد المغرب',
  'AFTER_ISHA': 'بعد العشاء',
};

/// «الساعة 20:30» or the slot's name; null when neither was set.
String? invitationTimeLabel(String? timeSlot, String? exactTime) {
  final exact = exactTime?.trim() ?? '';
  if (exact.isNotEmpty) return 'الساعة $exact';
  final slot = _slotWords[timeSlot] ?? '';
  return slot.isEmpty ? null : slot;
}

/// The day as the server writes it: «18/2/2027».
String invitationDay(DateTime date) => '${date.day}/${date.month}/${date.year}';

/// «يتشرف فلان بدعوتكم لحضور», in the plan's form; null without a host.
String? invitationHostPhrase(String? hostLine, {required bool bride}) {
  final host = hostLine?.trim() ?? '';
  if (host.isEmpty) return null;
  return bride ? 'تتشرف $host بدعوتكن لحضور' : 'يتشرف $host بدعوتكم لحضور';
}

String? _whenLine(InvitationOccasionText occasion) {
  final time = invitationTimeLabel(occasion.timeSlot, occasion.exactTime);
  final parts = [
    if (occasion.date case final date?) invitationDay(date),
    ?time,
  ];
  return parts.isEmpty ? null : parts.join(' ');
}

List<String> _occasionLines(
  InvitationOccasionText occasion, {
  required bool heading,
  required bool withMap,
}) {
  final when = _whenLine(occasion);
  final place = occasion.placeLabel?.trim() ?? '';
  final address = occasion.address?.trim() ?? '';
  final map = occasion.mapUrl;
  return [
    if (heading) '*${occasion.label}*',
    if (when != null) 'الموعد: $when',
    if (place.isNotEmpty) 'المكان: $place',
    if (address.isNotEmpty) 'العنوان: $address',
    if (withMap && map != null && map.isNotEmpty) 'الموقع على الخريطة: $map',
  ];
}

String _composeMessage({
  required String guestName,
  required String planTitle,
  required String url,
  required List<InvitationOccasionText> occasions,
  required InvitationSendKind kind,
  required bool bride,
  required String? hostLine,
  required String? freeText,
  required bool confirmed,
  required bool withMaps,
}) {
  final name = guestName.trim();
  final many = occasions.length > 1;
  final labels = occasions.map((occasion) => occasion.label).join(' و');
  final only = occasions.length == 1 ? occasions.first : null;
  final of = only != null && !only.isWedding
      ? '${only.label} في $planTitle'
      : planTitle;
  final blocks = [
    for (final occasion in occasions)
      _occasionLines(occasion, heading: many, withMap: withMaps),
  ].where((lines) => lines.isNotEmpty).toList();
  final details = [
    for (var index = 0; index < blocks.length; index++) ...[
      if (index > 0) '',
      ...blocks[index],
    ],
  ];
  final mapsMoved =
      !withMaps &&
      occasions.any((occasion) => occasion.mapUrl?.isNotEmpty == true);
  final List<String> opening;
  final String ask;
  switch (kind) {
    case InvitationSendKind.reminder:
      opening = ['أهلًا $name', 'نذكرك ب$of.'];
      ask = confirmed
          ? 'ننتظرك. ولو تغيّر شي، هذا رابطك:'
          : 'هذا رابطك للرد بضغطة:';
    case InvitationSendKind.addition:
      opening = [
        'أهلًا $name 🌸',
        'ويسعدنا حضورك أيضًا في $labels، ضمن $planTitle.',
      ];
      ask = 'نرجو تأكيد حضورك من الرابط:';
    case InvitationSendKind.change:
      opening = [
        'أهلًا $name 🌸',
        'تغيّر موعد أو مكان $labels في $planTitle، وهذا الجديد.',
      ];
      ask = 'نرجو تأكيد حضورك من جديد من الرابط:';
    case InvitationSendKind.invitation:
      final host = invitationHostPhrase(hostLine, bride: bride);
      final words = freeText?.trim() ?? '';
      opening = [
        'أهلًا $name 🌸',
        '${host == null ? 'يسعدنا دعوتك لحضور $of' : '$host $of'}.',
        if (freeText != null && words.isNotEmpty) freeText,
      ];
      ask = many
          ? 'نرجو تأكيد حضورك لكل مناسبة من الرابط:'
          : 'نرجو تأكيد حضورك من الرابط:';
  }
  return [
    ...opening,
    ask,
    url,
    if (mapsMoved) 'ومواقع الخريطة في الرابط.',
    if (details.isNotEmpty) ...['', ...details],
  ].join('\n');
}

/// The WhatsApp text the server builds for one guest (buildRsvpMessage): the
/// guest's link first (WhatsApp previews the first link), then each
/// occasion's day, time, place, address and map link.
String invitationMessage({
  required String guestName,
  required String planTitle,
  required String url,
  required List<InvitationOccasionText> occasions,
  InvitationSendKind kind = InvitationSendKind.invitation,
  bool bride = false,
  String? hostLine,
  String? freeText,
  bool confirmed = false,
}) {
  String compose(bool withMaps) => _composeMessage(
    guestName: guestName,
    planTitle: planTitle,
    url: url,
    occasions: occasions,
    kind: kind,
    bride: bride,
    hostLine: hostLine,
    freeText: freeText,
    confirmed: confirmed,
    withMaps: withMaps,
  );
  final full = compose(true);
  return full.length > invitationMessageSoftLimit ? compose(false) : full;
}
