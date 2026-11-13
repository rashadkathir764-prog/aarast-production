import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_count.dart';
import '../models/guest.dart';

/// عرض الضيوف — مصدر حقيقة واحد للتسميات والألوان.

String guestSideLabel(String side) {
  return switch (side) {
    'GROOM' => 'أهل العريس',
    'BRIDE' => 'أهل العروسة',
    _ => 'غير محدد',
  };
}

/// The guest words of the open plan, each in one place: the groom's guests
/// are men and the bride's are women (JOURNEY_PROFILE.md: «ضيوف، مدعو،
/// أكدوا» become «ضيفات، مدعوة، أكدن»).
class GuestWords {
  const GuestWords(this.profile);

  factory GuestWords.of(BuildContext context) =>
      GuestWords(context.journeyProfile);

  final JourneyProfile profile;

  /// The plan's guest word: the bride's guests are women whoever reads.
  String _say(String groom, String bride) => profile.plan(groom, bride);

  /// «الضيوف» / «الضيفات».
  String get guests => _say('الضيوف', 'الضيفات');

  /// «ضيوفك» / «ضيفاتك».
  String get yourGuests => _say('ضيوفك', 'ضيفاتك');

  /// «كل الضيوف» / «كل الضيفات».
  String get allGuests => _say('كل الضيوف', 'كل الضيفات');

  /// «ضيف جديد» / «ضيفة جديدة».
  String get newGuest => _say('ضيف جديد', 'ضيفة جديدة');

  /// «مدعو» / «مدعوة» after a count.
  String get invited => _say('مدعو', 'مدعوة');

  /// «أكدوا» / «أكدن».
  String get confirmed => _say('أكدوا', 'أكدن');

  /// «ما ردّوا» / «ما ردّن».
  String get pending => _say('ما ردّوا', 'ما ردّن');

  /// «ما أكدوا بعد» / «ما أكدن بعد»: who has not confirmed, invited yet or
  /// not (RA-MO-219: «ما ردّوا» said it of guests never asked).
  String get notYetConfirmed => _say('ما أكدوا بعد', 'ما أكدن بعد');

  /// «بلا دعوة»: no invitation went to them yet.
  String get noInvitation => 'بلا دعوة';

  /// «اعتذروا» / «اعتذرن».
  String get declined => _say('اعتذروا', 'اعتذرن');

  /// «مع المرافقين» / «مع المرافقات» (the server's own words for her plan).
  String get withCompanions => _say('مع المرافقين', 'مع المرافقات');

  /// «ما أضفت أحد بعد» / «ما أضفتِ أحد بعد»: said to the reader.
  String get noneAdded => profile.say('ما أضفت أحد بعد', 'ما أضفتِ أحد بعد');

  /// «ضيف واحد», «ضيفين», «12 ضيف» or their feminine forms.
  String count(int count) => arabicCount(
    count,
    one: _say('ضيف واحد', 'ضيفة وحدة'),
    two: _say('ضيفين', 'ضيفتين'),
    few: _say('ضيوف', 'ضيفات'),
    many: _say('ضيف', 'ضيفة'),
  );
}

/// The guest's answer the way the family says it: «أكّد مع 2», «اعتذر»,
/// «ما ردّ», or «ما وصلته دعوة» before any was sent; a bride's guest in
/// the feminine («أكّدت»، «اعتذرت»).
String guestReplyLabel(Guest guest, JourneyProfile profile) {
  // The guest's own gender: the plan's guests.
  final say = profile.plan;
  if (guest.isConfirmed) {
    return guest.companionsCount > 0
        ? '${say('أكّد', 'أكّدت')} مع ${guest.companionsCount}'
        : say('أكّد', 'أكّدت');
  }
  if (guest.isDeclined) return say('اعتذر', 'اعتذرت');
  return guest.invitationStatus == 'NOT_SENT'
      ? say('ما وصلته دعوة', 'ما وصلتها دعوة')
      : say('ما ردّ', 'ما ردّت');
}

/// The tag colours for [guestReplyLabel]: (text, background).
(Color, Color) guestReplyColors(Guest guest) {
  if (guest.isConfirmed) return (AarastV3Color.mint, AarastV3Color.mintSoft);
  if (guest.isDeclined) return (AarastV3Color.danger, AarastV3Color.dangerSoft);
  return (AarastV3Color.textMuted, AarastV3Color.line);
}

/// The group's name, or «بدون مجموعة».
String guestGroupLabel(Guest guest, List<GuestGroup> groups) {
  final groupId = guest.groupId;
  if (groupId == null || groupId.trim().isEmpty) return 'بدون مجموعة';
  for (final group in groups) {
    if (group.id == groupId) return group.name;
  }
  return 'بدون مجموعة';
}

/// The attendance a manual answer saves alongside the status.
String guestAttendanceForStatus(String status) {
  return switch (status) {
    'CONFIRMED' => 'CONFIRMED',
    'DECLINED' => 'DECLINED',
    _ => 'PENDING',
  };
}
