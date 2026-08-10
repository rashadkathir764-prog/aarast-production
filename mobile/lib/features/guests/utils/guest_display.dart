import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

/// عرض الضيوف — مصدر حقيقة واحد للألوان والتسميات والأيقونات.

String guestSideLabel(String side) {
  return switch (side) {
    'GROOM' => 'طرف العريس',
    'BRIDE' => 'طرف العروسة',
    _ => 'غير محدد',
  };
}

String guestStatusLabel(String status) {
  return switch (status) {
    'CONFIRMED' => 'مؤكد',
    'DECLINED' => 'لن يحضر',
    'PENDING' => 'بانتظار الرد',
    _ => 'مدعو',
  };
}

Color guestStatusColor(String status, String attendanceStatus) {
  if (attendanceStatus == 'CONFIRMED' || status == 'CONFIRMED') {
    return AppTheme.success;
  }
  if (attendanceStatus == 'DECLINED' || status == 'DECLINED') {
    return AppTheme.danger;
  }
  if (status == 'PENDING') return AppTheme.focus;
  return AppTheme.brand;
}

IconData guestStatusIcon(String status, String attendanceStatus) {
  if (attendanceStatus == 'CONFIRMED' || status == 'CONFIRMED') {
    return LucideIcons.checkCircle;
  }
  if (attendanceStatus == 'DECLINED' || status == 'DECLINED') {
    return LucideIcons.xCircle;
  }
  if (status == 'PENDING') return LucideIcons.clock;
  return LucideIcons.mailQuestion;
}
