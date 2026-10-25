import '../../../core/experience_v3/aarast_journey_profile.dart';
import '../../../core/utils/arabic_date_formatter.dart';

/// What an invitation says, before it meets a guest and their own link.
class GuestInviteCard {
  const GuestInviteCard({
    required this.title,
    this.host,
    this.weddingDate,
    this.place,
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
  final String? place;

  String? get dateLine {
    final date = weddingDate;
    return date == null ? null : formatArabicWeekdayDayMonth(date);
  }
}

/// e04: the first invitation. Every guest gets their own link, so the text
/// is built for each one.
String guestInviteMessage(
  GuestInviteCard card, {
  required String guestName,
  required String url,
}) {
  final host = card.host?.trim();
  // The plan's words: its host and its guests, whoever sends it.
  final say = card.profile.plan;
  return [
    'أهلًا ${guestName.trim()} 🌸',
    host == null || host.isEmpty
        ? 'يسعدنا دعوتك لحضور ${card.title}.'
        : say(
            'يتشرف $host بدعوتكم لحضور ${card.title}.',
            'تتشرف $host بدعوتكن لحضور ${card.title}.',
          ),
    if (card.dateLine case final date?) 'الموعد: $date',
    if (card.place?.trim() case final place? when place.isNotEmpty)
      'المكان: $place',
    say('أكّد حضورك بضغطة من رابطك:', 'أكّدي حضورك بضغطة من رابطك:'),
    url,
  ].join('\n');
}

/// e08: a reminder for who has not answered. Sending it makes a new link,
/// and the old one stops working, so it says so (C31).
String guestReminderMessage(
  GuestInviteCard card, {
  required String guestName,
  required String url,
}) {
  return [
    'أهلًا ${guestName.trim()}',
    card.dateLine == null
        ? 'نذكرك بـ${card.title}.'
        : 'نذكرك بـ${card.title} يوم ${card.dateLine}.',
    'هذا رابطك الجديد للرد بضغطة:',
    url,
  ].join('\n');
}

/// A WhatsApp chat with [phone], [text] ready to send.
Uri guestWhatsAppUri(String? phone, String text) {
  final digits = phone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
  return Uri.https('wa.me', digits.isEmpty ? '/' : '/$digits', {'text': text});
}
