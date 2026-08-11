import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/experience_v3/aarast_v3_content.dart';
import '../../models/dashboard_summary.dart';

enum AarastDashboardFocusTarget {
  item,
  plan,
  money,
  tasks,
  guests,
  providers,
  sharing,
}

enum AarastDashboardFocusTone { urgent, attention, positive, calm }

class AarastDashboardFocus {
  const AarastDashboardFocus({
    required this.eyebrow,
    required this.title,
    required this.reason,
    required this.actionLabel,
    required this.icon,
    required this.tone,
    required this.target,
    this.item,
  });

  final String eyebrow;
  final String title;
  final String reason;
  final String actionLabel;
  final IconData icon;
  final AarastDashboardFocusTone tone;
  final AarastDashboardFocusTarget target;
  final DashboardImportantItem? item;
}

/// Resolves one honest next step from server-backed summary values.
///
/// The dashboard never invents urgency. Backend-provided actions win, then
/// deterministic local rules use counts that already belong to the summary.
AarastDashboardFocus resolveDashboardFocus(DashboardSummary summary) {
  final backendItem = summary.importantItems.firstOrNull;
  if (backendItem != null) {
    return AarastDashboardFocus(
      eyebrow: _isUrgent(backendItem) ? 'يحتاج انتباهك' : 'الأولوية الآن',
      title: _safeText(backendItem.title, fallback: 'راجع الخطوة التالية'),
      reason: _safeText(
        backendItem.subtitle,
        fallback: 'افتح التفاصيل قبل اتخاذ القرار.',
      ),
      actionLabel: _safeText(backendItem.actionLabel, fallback: 'عرض التفاصيل'),
      icon: _iconForType(backendItem.type),
      tone: _toneFor(backendItem),
      target: AarastDashboardFocusTarget.item,
      item: backendItem,
    );
  }

  if (summary.canViewMoney && (summary.duePaymentSchedulesCount ?? 0) > 0) {
    final count = summary.duePaymentSchedulesCount!;
    return AarastDashboardFocus(
      eyebrow: 'يحتاج انتباهك',
      title: count == 1 ? 'موعد دفع قريب' : 'مواعيد دفع قريبة',
      reason: count == 1
          ? 'لديك موعد دفع واحد يحتاج مراجعة قبل استحقاقه.'
          : 'لديك $count مواعيد دفع تحتاج مراجعة قبل استحقاقها.',
      actionLabel: 'فتح المال',
      icon: LucideIcons.calendarClock,
      tone: AarastDashboardFocusTone.urgent,
      target: AarastDashboardFocusTarget.money,
    );
  }

  if (summary.overdueTasks > 0) {
    return AarastDashboardFocus(
      eyebrow: 'يحتاج انتباهك',
      title: summary.overdueTasks == 1
          ? 'مهمة واحدة متأخرة'
          : '${summary.overdueTasks} مهام متأخرة',
      reason: 'رتّب المتأخر أولًا حتى تبقى الخطة تحت السيطرة.',
      actionLabel: 'مراجعة المهام',
      icon: LucideIcons.alarmClock,
      tone: AarastDashboardFocusTone.urgent,
      target: AarastDashboardFocusTarget.tasks,
    );
  }

  if (summary.receivedQuotes > 0) {
    return AarastDashboardFocus(
      eyebrow: 'قرار ينتظرك',
      title: summary.receivedQuotes == 1
          ? 'وصلك عرض سعر جديد'
          : 'وصلتك ${summary.receivedQuotes} عروض أسعار',
      reason: 'قارن التفاصيل بهدوء قبل اختيار المورد الأنسب لخطة زفافك.',
      actionLabel: 'مراجعة العروض',
      icon: LucideIcons.inbox,
      tone: AarastDashboardFocusTone.positive,
      target: AarastDashboardFocusTarget.providers,
    );
  }

  if (summary.incompleteGuestsCount > 0 &&
      summary.permissions.canManageGuests) {
    return AarastDashboardFocus(
      eyebrow: 'بيانات تحتاج إكمالاً',
      title: summary.incompleteGuestsCount == 1
          ? 'ضيف واحد ناقص البيانات'
          : '${summary.incompleteGuestsCount} ضيوف ناقصو البيانات',
      reason: 'أكمل الأسماء أو أرقام التواصل قبل اعتماد القائمة.',
      actionLabel: 'إكمال البيانات',
      icon: LucideIcons.userCog,
      tone: AarastDashboardFocusTone.attention,
      target: AarastDashboardFocusTarget.guests,
    );
  }

  if (summary.pendingGuests > 0 && summary.permissions.canManageGuests) {
    return AarastDashboardFocus(
      eyebrow: 'بانتظار الرد',
      title: summary.pendingGuests == 1
          ? 'ضيف واحد ينتظر تحديث الرد'
          : '${summary.pendingGuests} ضيوف بانتظار الرد',
      reason: 'حدّث حالة الحضور عندما يصلك الرد لتبقى الأعداد دقيقة.',
      actionLabel: 'مراجعة الضيوف',
      icon: LucideIcons.userCheck,
      tone: AarastDashboardFocusTone.attention,
      target: AarastDashboardFocusTarget.guests,
    );
  }

  if (summary.todayTasks > 0) {
    return AarastDashboardFocus(
      eyebrow: 'خطوة اليوم',
      title: summary.todayTasks == 1
          ? 'لديك مهمة واحدة اليوم'
          : 'لديك ${summary.todayTasks} مهام اليوم',
      reason: 'ابدأ بالأقرب، ثم أكمل بقية يومك دون تشتيت.',
      actionLabel: 'فتح مهام اليوم',
      icon: LucideIcons.listChecks,
      tone: AarastDashboardFocusTone.attention,
      target: AarastDashboardFocusTarget.tasks,
    );
  }

  if ((summary.permissions.isOwner || summary.permissions.canManageMembers) &&
      summary.pendingInvites > 0) {
    return AarastDashboardFocus(
      eyebrow: 'بانتظار رد',
      title: summary.pendingInvites == 1
          ? 'دعوة مشاركة معلقة'
          : '${summary.pendingInvites} دعوات مشاركة معلقة',
      reason: 'راجع الدعوات والصلاحيات قبل توزيع المزيد من العمل.',
      actionLabel: 'إدارة المشاركة',
      icon: LucideIcons.userPlus,
      tone: AarastDashboardFocusTone.attention,
      target: AarastDashboardFocusTarget.sharing,
    );
  }

  if (_amount(summary.totalBudgetForDisplay) == null &&
      summary.permissions.canManageMoney) {
    return const AarastDashboardFocus(
      eyebrow: 'ابدأ من الأساس',
      title: 'حدّد ميزانية تقريبية',
      reason: 'ابدأ برقم أولي، ويمكنك تعديله لاحقًا.',
      actionLabel: 'إعداد الميزانية',
      icon: LucideIcons.wallet,
      tone: AarastDashboardFocusTone.calm,
      target: AarastDashboardFocusTarget.money,
    );
  }

  if (summary.providerCount == 0 && summary.permissions.canManageProviders) {
    return const AarastDashboardFocus(
      eyebrow: 'خطوتك التالية',
      title: 'استكشف أول مزوّد',
      reason: 'قارن الخدمات واطلب عرضًا حقيقيًا قبل إدخاله ضمن الخطة.',
      actionLabel: 'فتح المزوّدين',
      icon: LucideIcons.store,
      tone: AarastDashboardFocusTone.calm,
      target: AarastDashboardFocusTarget.providers,
    );
  }

  if (summary.totalTasks == 0 && summary.permissions.canManageTasks) {
    return const AarastDashboardFocus(
      eyebrow: 'خطوتك التالية',
      title: 'أضف أول مهمة',
      reason: 'حوّل أول قرار إلى مهمة واضحة بموعد ومسؤول.',
      actionLabel: 'فتح المهام',
      icon: LucideIcons.listChecks,
      tone: AarastDashboardFocusTone.calm,
      target: AarastDashboardFocusTarget.tasks,
    );
  }

  if (summary.guestCount == 0 && summary.permissions.canManageGuests) {
    return const AarastDashboardFocus(
      eyebrow: 'خطوتك التالية',
      title: 'ابدأ قائمة الضيوف',
      reason: 'عدد الضيوف يوضّح احتياج القاعة والضيافة والميزانية.',
      actionLabel: 'فتح الضيوف',
      icon: LucideIcons.users,
      tone: AarastDashboardFocusTone.calm,
      target: AarastDashboardFocusTarget.guests,
    );
  }

  return const AarastDashboardFocus(
    eyebrow: AarastV3Copy.calmEyebrow,
    title: AarastV3Copy.calmPlanTitle,
    reason: AarastV3Copy.calmPlanMessage,
    actionLabel: 'مراجعة الخطة',
    icon: LucideIcons.checkCircle2,
    tone: AarastDashboardFocusTone.calm,
    target: AarastDashboardFocusTarget.plan,
  );
}

double? dashboardAmount(String? raw) => _amount(raw);

String formatDashboardAmount(num value) {
  final rounded = value.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index += 1) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return '${negative ? '-' : ''}$buffer';
}

double? _amount(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final normalized = raw.replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (normalized.isEmpty || normalized == '-') return null;
  return double.tryParse(normalized);
}

bool _isUrgent(DashboardImportantItem item) {
  final priority = item.priority.toUpperCase();
  final tone = item.tone.toUpperCase();
  return priority.contains('URGENT') ||
      priority.contains('HIGH') ||
      tone.contains('DANGER');
}

AarastDashboardFocusTone _toneFor(DashboardImportantItem item) {
  if (_isUrgent(item)) return AarastDashboardFocusTone.urgent;
  final tone = item.tone.toUpperCase();
  if (tone.contains('SUCCESS') || tone.contains('CELEBRAT')) {
    return AarastDashboardFocusTone.positive;
  }
  return AarastDashboardFocusTone.attention;
}

IconData _iconForType(String type) {
  final normalized = type.toUpperCase();
  if (normalized.contains('PAYMENT') ||
      normalized.contains('MONEY') ||
      normalized.contains('BUDGET') ||
      normalized.contains('COST')) {
    return LucideIcons.wallet;
  }
  if (normalized.contains('TASK')) return LucideIcons.listChecks;
  if (normalized.contains('QUOTE') || normalized.contains('PROVIDER')) {
    return LucideIcons.store;
  }
  if (normalized.contains('GUEST')) return LucideIcons.users;
  if (normalized.contains('INVITE') || normalized.contains('MEMBER')) {
    return LucideIcons.userPlus;
  }
  return LucideIcons.sparkles;
}

String _safeText(String value, {required String fallback}) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
