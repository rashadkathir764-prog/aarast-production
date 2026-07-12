import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../models/dashboard_summary.dart';

/// يحوّل نصًا ماليًا قادمًا من الخادم ("10,000,000") إلى رقم.
double? parseAmount(String? raw) {
  if (raw == null) return null;
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (cleaned.isEmpty || cleaned == '-') return null;
  return double.tryParse(cleaned);
}

String formatAmount(num value) {
  final negative = value < 0;
  final text = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final remaining = text.length - i;
    buffer.write(text[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return negative ? '-$buffer' : buffer.toString();
}

// ---------------------------------------------------------------------------
// الخطوة الذكية — إجابة واحدة دائمًا على سؤال: "ماذا أفعل الآن؟"
// ---------------------------------------------------------------------------

enum SmartActionTone { urgent, attention, celebrate, calm }

class SmartAction {
  const SmartAction({
    required this.title,
    required this.reason,
    required this.icon,
    required this.tone,
    this.item,
  });

  final String title;
  final String reason;
  final IconData icon;
  final SmartActionTone tone;
  final DashboardImportantItem? item;
}

/// يحسب أهم خطوة الآن بأولوية: مال مستحق ← مهام متأخرة ← عروض وصلت ← مهام اليوم.
SmartAction? resolveSmartAction(DashboardSummary summary) {
  final backendItem = summary.importantItems.isNotEmpty
      ? summary.importantItems.first
      : null;
  if (backendItem != null) {
    return SmartAction(
      title: backendItem.title,
      reason: backendItem.subtitle,
      icon: _iconForType(backendItem.type),
      tone: _toneForPriority(backendItem.priority, backendItem.tone),
      item: backendItem,
    );
  }

  if ((summary.dueInstallmentsCount ?? 0) > 0) {
    return SmartAction(
      title: 'قسط مستحق ينتظرك',
      reason:
          'لديك ${summary.dueInstallmentsCount} قسط حان موعده — سدّده قبل ما يتراكم.',
      icon: LucideIcons.calendarClock,
      tone: SmartActionTone.urgent,
    );
  }
  if (summary.overdueTasks > 0) {
    return SmartAction(
      title: 'مهام متأخرة تحتاجك',
      reason:
          '${summary.overdueTasks} مهمة تجاوزت موعدها — رتبها اليوم يرتاح بالك.',
      icon: LucideIcons.alarmClock,
      tone: SmartActionTone.urgent,
    );
  }
  if (summary.receivedQuotes > 0) {
    return SmartAction(
      title: 'وصلك عرض سعر جديد',
      reason:
          '${summary.receivedQuotes} عرض بانتظار قرارك — قارن واختر براحتك.',
      icon: LucideIcons.mailOpen,
      tone: SmartActionTone.celebrate,
    );
  }
  if (summary.todayTasks > 0) {
    return SmartAction(
      title: 'مهام اليوم جاهزة',
      reason: '${summary.todayTasks} مهمة مجدولة لليوم — خطوة خطوة نوصل.',
      icon: LucideIcons.listChecks,
      tone: SmartActionTone.attention,
    );
  }
  if (summary.pendingInvites > 0) {
    return SmartAction(
      title: 'دعوة مشاركة معلقة',
      reason:
          '${summary.pendingInvites} دعوة لم يُرد عليها بعد — تابعها من المشاركة.',
      icon: LucideIcons.userPlus,
      tone: SmartActionTone.attention,
    );
  }
  return null;
}

IconData _iconForType(String type) {
  final upper = type.toUpperCase();
  if (upper.contains('INSTALLMENT') ||
      upper.contains('MONEY') ||
      upper.contains('BUDGET') ||
      upper.contains('EXPENSE')) {
    return LucideIcons.wallet;
  }
  if (upper.contains('TASK')) return LucideIcons.listChecks;
  if (upper.contains('QUOTE') || upper.contains('PROVIDER')) {
    return LucideIcons.store;
  }
  if (upper.contains('GUEST')) return LucideIcons.users;
  if (upper.contains('INVITE') || upper.contains('MEMBER')) {
    return LucideIcons.userPlus;
  }
  return LucideIcons.sparkles;
}

SmartActionTone _toneForPriority(String priority, String tone) {
  final p = priority.toUpperCase();
  final t = tone.toUpperCase();
  if (p.contains('HIGH') || p.contains('URGENT') || t.contains('DANGER')) {
    return SmartActionTone.urgent;
  }
  if (t.contains('SUCCESS') || t.contains('CELEBRAT')) {
    return SmartActionTone.celebrate;
  }
  return SmartActionTone.attention;
}

class SetupStep {
  const SetupStep({
    required this.label,
    required this.hint,
    required this.icon,
    required this.done,
    required this.onTap,
  });

  final String label;
  final String hint;
  final IconData icon;
  final bool done;
  final VoidCallback onTap;
}

class PulseTileData {
  const PulseTileData({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final VoidCallback onTap;
}
