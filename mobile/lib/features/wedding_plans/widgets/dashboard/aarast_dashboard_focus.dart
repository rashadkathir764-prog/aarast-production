import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/experience_v3/aarast_journey_profile.dart';
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

/// Resolves one honest next step from server-backed summary values, in the
/// plan's [profile] (the groom's words or the bride's).
///
/// The dashboard never invents urgency. Backend-provided actions win, then
/// deterministic local rules use counts that already belong to the summary.
AarastDashboardFocus resolveDashboardFocus(
  DashboardSummary summary, {
  JourneyProfile profile = JourneyProfile.groom,
}) {
  final say = profile.say;
  final backendItem = summary.importantItems.firstOrNull;
  if (backendItem != null) {
    return AarastDashboardFocus(
      eyebrow: _isUrgent(backendItem) ? 'يحتاج انتباهك' : 'الأولوية الآن',
      title: _safeText(
        backendItem.title,
        fallback: say('راجع الخطوة التالية', 'راجعي الخطوة التالية'),
      ),
      reason: _safeText(
        backendItem.subtitle,
        fallback: say(
          'افتح التفاصيل قبل اتخاذ القرار.',
          'افتحي التفاصيل قبل اتخاذ القرار.',
        ),
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
      reason: say(
        'رتّب المتأخر أولًا حتى تبقى الخطة تحت السيطرة.',
        'رتّبي المتأخر أولًا حتى تبقى الخطة تحت السيطرة.',
      ),
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
      reason: say(
        'قارن التفاصيل بهدوء قبل اختيار المزود الأنسب لخطة زفافك.',
        'قارني التفاصيل بهدوء قبل اختيار المزود الأنسب لخطة زفافك.',
      ),
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
          ? say('ضيف واحد ناقص البيانات', 'ضيفة وحدة ناقصة البيانات')
          : say(
              '${summary.incompleteGuestsCount} ضيوف ناقصو البيانات',
              '${summary.incompleteGuestsCount} ضيفات ناقصات البيانات',
            ),
      reason: say(
        'أكمل الأسماء أو أرقام التواصل قبل اعتماد القائمة.',
        'أكملي الأسماء أو أرقام التواصل قبل اعتماد القائمة.',
      ),
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
          ? say('ضيف واحد ينتظر تحديث الرد', 'ضيفة وحدة تنتظر تحديث الرد')
          : say(
              '${summary.pendingGuests} ضيوف بانتظار الرد',
              '${summary.pendingGuests} ضيفات بانتظار الرد',
            ),
      reason: say(
        'حدّث حالة الحضور عندما يصلك الرد لتبقى الأعداد دقيقة.',
        'حدّثي حالة الحضور عندما يصلك الرد لتبقى الأعداد دقيقة.',
      ),
      actionLabel: say('مراجعة الضيوف', 'مراجعة الضيفات'),
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
      reason: say(
        'ابدأ بالأقرب، ثم أكمل بقية يومك دون تشتيت.',
        'ابدئي بالأقرب، ثم أكملي بقية يومك دون تشتيت.',
      ),
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
      reason: say(
        'راجع الدعوات والصلاحيات قبل توزيع المزيد من العمل.',
        'راجعي الدعوات والصلاحيات قبل توزيع المزيد من العمل.',
      ),
      actionLabel: 'إدارة المشاركة',
      icon: LucideIcons.userPlus,
      tone: AarastDashboardFocusTone.attention,
      target: AarastDashboardFocusTarget.sharing,
    );
  }

  if (_amount(summary.totalBudgetForDisplay) == null &&
      summary.permissions.canManageMoney) {
    return AarastDashboardFocus(
      eyebrow: say('ابدأ من الأساس', 'ابدئي من الأساس'),
      title: say('حدّد ميزانية تقريبية', 'حدّدي ميزانية تقريبية'),
      reason: say(
        'ابدأ برقم أولي، ويمكنك تعديله لاحقًا.',
        'ابدئي برقم أولي، ويمكنك تعديله لاحقًا.',
      ),
      actionLabel: 'إعداد الميزانية',
      icon: LucideIcons.wallet,
      tone: AarastDashboardFocusTone.calm,
      target: AarastDashboardFocusTarget.money,
    );
  }

  if (summary.providerCount == 0 && summary.permissions.canManageProviders) {
    return AarastDashboardFocus(
      eyebrow: 'خطوتك التالية',
      title: say('استكشف أول مزوّد', 'استكشفي أول مزوّد'),
      reason: say(
        'قارن الخدمات واطلب عرضًا حقيقيًا قبل إدخاله ضمن الخطة.',
        'قارني الخدمات واطلبي عرضًا حقيقيًا قبل إدخاله ضمن الخطة.',
      ),
      actionLabel: 'فتح المزوّدين',
      icon: LucideIcons.store,
      tone: AarastDashboardFocusTone.calm,
      target: AarastDashboardFocusTarget.providers,
    );
  }

  if (summary.totalTasks == 0 && summary.permissions.canManageTasks) {
    return AarastDashboardFocus(
      eyebrow: 'خطوتك التالية',
      title: say('أضف أول مهمة', 'أضيفي أول مهمة'),
      reason: say(
        'حوّل أول قرار إلى مهمة واضحة بموعد ومسؤول.',
        'حوّلي أول قرار إلى مهمة واضحة بموعد ومسؤول.',
      ),
      actionLabel: 'فتح المهام',
      icon: LucideIcons.listChecks,
      tone: AarastDashboardFocusTone.calm,
      target: AarastDashboardFocusTarget.tasks,
    );
  }

  if (summary.guestCount == 0 && summary.permissions.canManageGuests) {
    return AarastDashboardFocus(
      eyebrow: 'خطوتك التالية',
      title: say('ابدأ قائمة الضيوف', 'ابدئي قائمة الضيفات'),
      reason: say(
        'عدد الضيوف يوضّح احتياج القاعة والضيافة والميزانية.',
        'عدد الضيفات يوضّح احتياج الصالة والضيافة والميزانية.',
      ),
      actionLabel: say('فتح الضيوف', 'فتح الضيفات'),
      icon: LucideIcons.users,
      tone: AarastDashboardFocusTone.calm,
      target: AarastDashboardFocusTarget.guests,
    );
  }

  return AarastDashboardFocus(
    eyebrow: AarastV3Copy.calmEyebrow,
    title: AarastV3Copy.calmPlanTitle,
    reason: say(
      AarastV3Copy.calmPlanMessage,
      'لا توجد أولوية عاجلة الآن. راجعي الخطة أو أكملي ما يناسبك.',
    ),
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
