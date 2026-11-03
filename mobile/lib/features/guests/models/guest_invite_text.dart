import '../../../core/experience_v3/aarast_journey_profile.dart';
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
}

/// A WhatsApp chat with [phone], [text] ready to send.
Uri guestWhatsAppUri(String? phone, String text) {
  final digits = phone?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
  return Uri.https('wa.me', digits.isEmpty ? '/' : '/$digits', {'text': text});
}
