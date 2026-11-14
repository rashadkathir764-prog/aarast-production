import '../../../core/experience_v3/aarast_journey_profile.dart';
import '../../../core/phone/phone_message_links.dart';
import '../../../core/utils/arabic_date_formatter.dart';

/// The card as e04 draws it before it meets a guest: what the plan and the
/// saved card say (D83). The WhatsApp text itself is the server's, built
/// from the same card and the guest's events, so the words live once.
class GuestInviteCard {
  const GuestInviteCard({
    required this.title,
    this.host,
    this.weddingDate,
    this.timeLabel,
    this.place,
    this.freeText,
    this.photoUrl,
    this.mapUrl,
    this.address,
    this.profile = JourneyProfile.groom,
  });

  /// Whose wedding invites: the bride's card is sent by a woman to her
  /// women guests («تتشرف … بدعوتكن», «أكّدي حضورك»).
  final JourneyProfile profile;

  /// The wedding's name, as the plan has it («زفاف محمد»).
  final String title;

  /// «يتشرف …»: whose invitation it is; card text only (C29).
  final String? host;
  final DateTime? weddingDate;

  /// «بعد العشاء», «الساعة 20:30»: the wedding event's time (b12).
  final String? timeLabel;
  final String? place;

  /// A verse or a word from the hosts, as the card keeps it.
  final String? freeText;
  final String? photoUrl;
  final String? mapUrl;
  final String? address;

  String? get dateLine {
    final date = weddingDate;
    if (date == null) return null;
    final day = formatArabicWeekdayDayMonth(date);
    return timeLabel == null ? day : '$day · $timeLabel';
  }

  // What follows mirrors the server's words (backend/src/guests/
  // guest-rsvp.service.ts: hostPhrase, invitationLine, whenLine,
  // buildRsvpMessage, invitationPreview). The guest receives the server's
  // text; the phone draws the same lines before any link exists, so the
  // preview is the message. A change there is a change here, and
  // test/features/guests/guest_invite_message_test.dart pins the order.

  String? get _hostText {
    final name = host?.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  /// «يتشرف … بدعوتكم لحضور», in the plan's form; null without a host.
  String? get hostPhrase => switch (_hostText) {
    null => null,
    final name => profile.plan(
      'يتشرف $name بدعوتكم لحضور',
      'تتشرف $name بدعوتكن لحضور',
    ),
  };

  /// The invitation's own sentence, in the message and the link's preview.
  String get invitationLine => switch (hostPhrase) {
    null => 'يسعدنا دعوتك لحضور $title',
    final phrase => '$phrase $title',
  };

  /// «18/2/2027 الساعة 20:30»: the day as the server writes it, and the time.
  String? get whenLine {
    final time = timeLabel?.trim() ?? '';
    final parts = [
      if (weddingDate case final date?) guestMessageDay(date),
      if (time.isNotEmpty) time,
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  String? get _placeText {
    final value = place?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String? get _whereLine {
    final map = mapUrl?.trim() ?? '';
    if (map.isNotEmpty) return 'الموقع على الخريطة: $map';
    final where = address?.trim() ?? '';
    return where.isEmpty ? null : 'العنوان: $where';
  }

  /// The WhatsApp text one guest receives, line by line; [link] stands
  /// where the guest's own link goes.
  List<String> messageLines({
    required String guestName,
    required String link,
    List<GuestInviteOccasion> occasions = const [],
  }) {
    final words = freeText?.trim() ?? '';
    return [
      'أهلًا ${guestName.trim()} 🌸',
      '$invitationLine.',
      if (words.isNotEmpty) words,
      'نرجو تأكيد حضورك من الرابط:',
      link,
      if (whenLine case final day?) 'الموعد: $day',
      if (_placeText case final place?) 'المكان: $place',
      if (occasions.isNotEmpty) ...[
        'والدعوة تشمل أيضًا:',
        for (final occasion in occasions) occasion.line,
      ],
      ?_whereLine,
    ];
  }

  /// e08: the reminder's text, with the guest's new link. A guest who
  /// [confirmed] is told the day and not asked to answer again.
  List<String> reminderLines({
    required String guestName,
    required String link,
    bool confirmed = false,
  }) {
    return [
      'أهلًا ${guestName.trim()}',
      switch (weddingDate) {
        null => 'نذكرك ب$title.',
        final date => 'نذكرك ب$title يوم ${guestMessageDay(date)}.',
      },
      confirmed
          ? 'ننتظرك. ولو تغيّر شي، هذا رابطك:'
          : 'هذا رابطك الجديد للرد بضغطة:',
      link,
    ];
  }

  /// The link preview's title, when WhatsApp draws one.
  String get linkTitle => invitationLine;

  /// The link preview's line under the title.
  String get linkDescription {
    final details = [
      if (whenLine case final day?) 'الموعد: $day',
      if (_placeText case final place?) 'المكان: $place',
    ].join(' · ');
    return details.isEmpty
        ? 'نرجو تأكيد حضورك من الرابط.'
        : '$details. نرجو تأكيد حضورك من الرابط.';
  }
}

/// One of the guest's occasions beyond the wedding, as the server lists it
/// under «والدعوة تشمل أيضًا».
class GuestInviteOccasion {
  const GuestInviteOccasion({required this.label, this.when, this.place});

  final String label;
  final String? when;
  final String? place;

  String get line {
    final time = when?.trim() ?? '';
    final where = place?.trim() ?? '';
    return '• $label${time.isEmpty ? '' : ': $time'}'
        '${where.isEmpty ? '' : ' · $where'}';
  }
}

/// The day as the server's message writes it: «18/2/2027».
String guestMessageDay(DateTime date) =>
    '${date.day}/${date.month}/${date.year}';

/// A WhatsApp chat with [phone], [text] ready to send. Without a number,
/// WhatsApp's own picker; with a number whose country cannot be told (the
/// normalisers keep it as bare digits), null: wa.me would open somebody
/// else's chat.
Uri? guestWhatsAppUri(String? phone, String text) {
  if (phone?.trim().isNotEmpty ?? false) {
    return whatsAppMessageUri(phone, text);
  }
  return Uri.https('wa.me', '/', {'text': text});
}

/// Whether a chat can be opened for [phone] at all. Asked before a guest's
/// link is made: making it replaces their old link and marks them invited,
/// which must not happen for a message that cannot be sent.
bool guestChatCanOpen(String? phone) => guestWhatsAppUri(phone, '') != null;

/// Why [guestName]'s chat cannot open: the saved number has no country.
///
/// Said without a verb to the reader or a pronoun for the guest, so it is
/// right for a groom or a bride reading, about a man or a woman.
String guestNumberWithoutCountry(String guestName) =>
    'رقم $guestName ما فيه مفتاح الدولة، فما نقدر نفتح المحادثة. '
    'الرقم ينكتب كامل من القائمة، مثل +966…';
