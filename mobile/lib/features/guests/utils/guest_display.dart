import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../models/guest.dart';

/// عرض الضيوف — مصدر حقيقة واحد للتسميات والألوان.

String guestSideLabel(String side) {
  return switch (side) {
    'GROOM' => 'أهل العريس',
    'BRIDE' => 'أهل العروسة',
    _ => 'غير محدد',
  };
}

/// The guest's answer the way the family says it: «أكّد مع 2», «اعتذر»,
/// «ما ردّ», or «ما وصلته دعوة» before any was sent.
String guestReplyLabel(Guest guest) {
  if (guest.isConfirmed) {
    return guest.companionsCount > 0
        ? 'أكّد مع ${guest.companionsCount}'
        : 'أكّد';
  }
  if (guest.isDeclined) return 'اعتذر';
  return guest.invitationStatus == 'NOT_SENT' ? 'ما وصلته دعوة' : 'ما ردّ';
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
