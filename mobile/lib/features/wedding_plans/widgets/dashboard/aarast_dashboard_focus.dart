import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/experience_v3/aarast_journey_profile.dart';
import '../../../../core/experience_v3/aarast_v3_content.dart';
import '../../../../core/utils/arabic_count.dart';
import '../../models/dashboard_summary.dart';

enum AarastDashboardFocusTarget {
  item,
  plan,
  money,
  tasks,
  guests,

  /// The first guests, from the phone's contacts.
  firstGuests,
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
          'شوف التفاصيل قبل لا تقرر.',
          'شوفي التفاصيل قبل لا تقررين.',
        ),
      ),
      actionLabel: _safeText(
        backendItem.actionLabel,
        fallback: say('افتح التفاصيل', 'افتحي التفاصيل'),
      ),
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
      reason:
          'عندك ${arabicCount(count, one: 'موعد دفع واحد', two: 'موعدين دفع', few: 'مواعيد دفع', many: 'موعد دفع')}، '
          '${say('شوفها قبل لا يجي وقتها.', 'شوفيها قبل لا يجي وقتها.')}',
      actionLabel: say('افتح المال', 'افتحي المال'),
      icon: LucideIcons.calendarClock,
      tone: AarastDashboardFocusTone.urgent,
      target: AarastDashboardFocusTarget.money,
    );
  }

  if (summary.overdueTasks > 0) {
    return AarastDashboardFocus(
      eyebrow: 'يحتاج انتباهك',
      title:
          '${arabicCount(summary.overdueTasks, one: 'مهمة وحدة', two: 'مهمتين', few: 'مهام', many: 'مهمة')} متأخرة',
      reason: say(
        'رتّب المتأخر أول، وبعدها الباقي يمشي.',
        'رتّبي المتأخر أول، وبعدها الباقي يمشي.',
      ),
      actionLabel: say('رتّب المهام', 'رتّبي المهام'),
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
          : 'وصلتك ${arabicCount(summary.receivedQuotes, one: 'عرض', two: 'عرضين', few: 'عروض', many: 'عرض')}',
      reason: say(
        'قارن بهدوء قبل لا تختار المزود.',
        'قارني بهدوء قبل لا تختارين المزود.',
      ),
      actionLabel: say('شوف العروض', 'شوفي العروض'),
      icon: LucideIcons.inbox,
      tone: AarastDashboardFocusTone.positive,
      target: AarastDashboardFocusTarget.providers,
    );
  }

  // D78 (RA-MO-147): the chain of basics is the server's, and an account
  // plan's summary (a kept copy too) carries it in `importantItems`. When
  // that list is empty the server found nothing missing for this reader, so
  // the phone asks nothing more: it used to add «أضف أول بند» and «أضف أول
  // مهمة», steps the server had not set, in an order of its own. Only a plan
  // kept on the phone, which no server orders, walks the chain here, in
  // D78's order: budget, first agreement, guests (its place is set when it
  // is made; the mahr and a quote need an account).
  final phoneChain = !summary.accountBacked;

  if (phoneChain &&
      dashboardBudgetMissing(summary) &&
      summary.permissions.canManageMoney) {
    return AarastDashboardFocus(
      eyebrow: say('ابدأ من الأساس', 'ابدئي من الأساس'),
      title: say('حدّد ميزانية تقريبية', 'حدّدي ميزانية تقريبية'),
      reason: say(
        'ابدأ برقم تقريبي، وتقدر تعدّله بعدين.',
        'ابدئي برقم تقريبي، وتقدرين تعدّلينه بعدين.',
      ),
      actionLabel: say('حدّد الميزانية', 'حدّدي الميزانية'),
      icon: LucideIcons.wallet,
      tone: AarastDashboardFocusTone.calm,
      target: AarastDashboardFocusTarget.money,
    );
  }

  // The server's words for the same step (ADD_FIRST_COST): an agreement,
  // not a budget item.
  final agreed = _amount(
    summary.confirmedCostTotal ?? summary.moneySummary.confirmedCost,
  );
  if (phoneChain &&
      (agreed == null || agreed <= 0) &&
      summary.permissions.canManageMoney) {
    return AarastDashboardFocus(
      eyebrow: 'خطوتك الجاية',
      title: say('سجّل أول اتفاق', 'سجّلي أول اتفاق'),
      reason: 'القاعة أو الذهب أو الكسوة: أول رقم يخلي الباقي يبان',
      actionLabel: say('أضف اتفاق', 'أضيفي اتفاق'),
      icon: LucideIcons.wallet,
      tone: AarastDashboardFocusTone.calm,
      target: AarastDashboardFocusTarget.money,
    );
  }

  if (phoneChain &&
      summary.guestCount == 0 &&
      summary.permissions.canManageGuests) {
    return AarastDashboardFocus(
      eyebrow: 'خطوتك الجاية',
      title: say('أضف أول ضيف', 'أضيفي أول ضيفة'),
      reason: say(
        'من جهات الاتصال بضغطة، وعددهم يوضّح احتياج القاعة والضيافة.',
        'من جهات الاتصال بضغطة، وعددهن يوضّح احتياج الصالة والضيافة.',
      ),
      actionLabel: say('اختر من جهات الاتصال', 'اختاري من جهات الاتصال'),
      icon: LucideIcons.users,
      tone: AarastDashboardFocusTone.calm,
      target: AarastDashboardFocusTarget.firstGuests,
    );
  }

  if (summary.incompleteGuestsCount > 0 &&
      summary.permissions.canManageGuests) {
    return AarastDashboardFocus(
      eyebrow: 'بيانات تحتاج إكمالاً',
      title: summary.incompleteGuestsCount == 1
          ? say('ضيف واحد ناقص البيانات', 'ضيفة وحدة ناقصة البيانات')
          : say(
              '${arabicCount(summary.incompleteGuestsCount, one: 'ضيف', two: 'ضيفين', few: 'ضيوف', many: 'ضيف')} ناقصة بياناتهم',
              '${arabicCount(summary.incompleteGuestsCount, one: 'ضيفة', two: 'ضيفتين', few: 'ضيفات', many: 'ضيفة')} ناقصة بياناتهن',
            ),
      reason: say(
        'كمّل الأسماء والأرقام قبل لا تعتمد القائمة.',
        'كمّلي الأسماء والأرقام قبل لا تعتمدين القائمة.',
      ),
      actionLabel: say('كمّل البيانات', 'كمّلي البيانات'),
      icon: LucideIcons.userCog,
      tone: AarastDashboardFocusTone.attention,
      target: AarastDashboardFocusTarget.guests,
    );
  }

  if (summary.pendingGuests > 0 && summary.permissions.canManageGuests) {
    return AarastDashboardFocus(
      eyebrow: 'بانتظار الرد',
      title: summary.pendingGuests == 1
          ? say('ضيف واحد ما ردّ', 'ضيفة وحدة ما ردّت')
          : say(
              '${arabicCount(summary.pendingGuests, one: 'ضيف', two: 'ضيفين', few: 'ضيوف', many: 'ضيف')} ما ردّوا',
              '${arabicCount(summary.pendingGuests, one: 'ضيفة', two: 'ضيفتين', few: 'ضيفات', many: 'ضيفة')} ما ردّن',
            ),
      reason: say(
        'حدّث ردودهم أول بأول عشان يبقى العدد صح.',
        'حدّثي ردودهن أول بأول عشان يبقى العدد صح.',
      ),
      actionLabel: say('شوف الضيوف', 'شوفي الضيفات'),
      icon: LucideIcons.userCheck,
      tone: AarastDashboardFocusTone.attention,
      target: AarastDashboardFocusTarget.guests,
    );
  }

  if (summary.todayTasks > 0) {
    return AarastDashboardFocus(
      eyebrow: 'خطوة اليوم',
      title:
          'عندك ${arabicCount(summary.todayTasks, one: 'مهمة وحدة', two: 'مهمتين', few: 'مهام', many: 'مهمة')} اليوم',
      reason: say(
        'ابدأ بالأقرب، وكمّل يومك على راحتك.',
        'ابدئي بالأقرب، وكمّلي يومك على راحتك.',
      ),
      actionLabel: say('افتح مهام اليوم', 'افتحي مهام اليوم'),
      icon: LucideIcons.listChecks,
      tone: AarastDashboardFocusTone.attention,
      target: AarastDashboardFocusTarget.tasks,
    );
  }

  if ((summary.permissions.isOwner || summary.permissions.canManageMembers) &&
      summary.pendingInvites > 0) {
    return AarastDashboardFocus(
      eyebrow: 'بانتظار رد',
      title:
          '${arabicCount(summary.pendingInvites, one: 'دعوة', two: 'دعوتين', few: 'دعوات', many: 'دعوة')} مشاركة ما انردّت',
      reason: say(
        'شوف الدعوات والصلاحيات قبل لا توزع شغل زيادة.',
        'شوفي الدعوات والصلاحيات قبل لا توزعين شغل زيادة.',
      ),
      actionLabel: say('شوف المشاركة', 'شوفي المشاركة'),
      icon: LucideIcons.userPlus,
      tone: AarastDashboardFocusTone.attention,
      target: AarastDashboardFocusTarget.sharing,
    );
  }

  // The end of every check above, so the one thing this may claim is that
  // none of them matched. «خطتك تحت السيطرة» claimed more than that: the
  // server works out no such state, and the line could show while the
  // moment's path still read «البداية».
  return AarastDashboardFocus(
    eyebrow: AarastV3Copy.calmEyebrow,
    title: 'ما فيه شي مستعجل',
    reason: say(
      'لا متأخر ولا موعد دفع قريب. تقدر تراجع خطتك أو تكمّل اللي يناسبك.',
      'لا متأخر ولا موعد دفع قريب. تقدرين تراجعين خطتك أو تكمّلين اللي يناسبك.',
    ),
    actionLabel: say('شوف الخطة', 'شوفي الخطة'),
    icon: LucideIcons.checkCircle2,
    tone: AarastDashboardFocusTone.calm,
    target: AarastDashboardFocusTarget.plan,
  );
}

double? dashboardAmount(String? raw) => _amount(raw);

/// Whether the plan still has no budget worth the name: none recorded, or a
/// zero. b01's first step and the moment's «البداية» must read this the same
/// way. They did not: the step asked only whether the field parsed, so a
/// budget of 0 was treated as set and the step never appeared, while the
/// moment still said «البداية» — and the two parsed the field differently,
/// so «3,000,000 ر.ي» read as no budget on one side and 3000000 on the other.
bool dashboardBudgetMissing(DashboardSummary summary) {
  final budget = _amount(summary.totalBudgetForDisplay);
  return budget == null || budget <= 0;
}

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
