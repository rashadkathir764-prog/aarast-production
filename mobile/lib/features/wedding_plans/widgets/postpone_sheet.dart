import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/hijri_date.dart';
import '../../../core/utils/plan_day.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../tasks/tasks_api.dart' show TaskTimelineApi;
import '../data/plan_bookings_lookup.dart';
import '../models/wedding_plan.dart' show weddingDateShiftDays;
import '../providers/dashboard_summary_provider.dart';
import '../providers/wedding_plans_provider.dart';

/// g03 «تأجيل العرس»: pick the new day, see what moves, then move it. Two
/// calls, not one: the date, then the open tasks by the same days. The
/// payments keep their own dates (C3) and the bookings for the old day are
/// named so the groom can ask each provider for the new one. Returns true
/// once the date moved, or was cleared by «تأجل وما حددنا موعد» (Q-47).
/// After the wedding the same sheet puts its day right (RA-MO-351).
Future<bool> showPostponeSheet(
  BuildContext context, {
  required String planId,
  required DateTime weddingDate,
}) async {
  final moved = await showJourneySheet<bool>(
    context: context,
    builder: (_) => _PostponeSheet(planId: planId, oldDay: weddingDate),
  );
  return moved == true;
}

/// The action's name: «تأجيل العرس», and after the wedding day «تعديل تاريخ
/// العرس» (RA-MO-351), the day being put right, not postponed. The same
/// in «حسابي» and on the sheet it opens.
String postponeActionTitle(DateTime weddingDate) =>
    daysUntilPlanDay(weddingDate) < 0 ? 'تعديل تاريخ العرس' : 'تأجيل العرس';

class _PostponeSheet extends StatefulWidget {
  const _PostponeSheet({required this.planId, required this.oldDay});

  final String planId;
  final DateTime oldDay;

  @override
  State<_PostponeSheet> createState() => _PostponeSheetState();
}

class _PostponeSheetState extends State<_PostponeSheet> {
  DateTime? _newDay;

  /// Open tasks that carry a date; null until loaded or when they could not
  /// be read.
  int? _openDatedTasks;
  List<PlanBookingDay> _oldDayBookings = const [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadImpact());
  }

  Future<void> _loadImpact() async {
    final tasksApi = context.read<TaskTimelineApi>();
    final bookings = PlanBookingsLookup(context.read<ApiClient>());
    try {
      final tasks = await tasksApi.getTasks(widget.planId);
      if (!mounted) return;
      setState(() {
        _openDatedTasks = tasks
            // What the server moves: open and dated (RA-MO-58: it counted
            // the cancelled ones).
            .where((task) => task.isOpen && task.dueDate != null)
            .length;
      });
    } on Object {
      // Offline: the move still works; the count is just not shown.
    }
    try {
      final list = await bookings.list(widget.planId);
      if (!mounted) return;
      setState(() => _oldDayBookings = bookingsOnDay(list, widget.oldDay));
    } on Object {
      // Same: the bookings row waits for the network.
    }
  }

  int? get _days => weddingDateShiftDays(widget.oldDay, _newDay);

  /// The wedding day has passed: the day is put right, not postponed.
  bool get _afterWedding => daysUntilPlanDay(widget.oldDay) < 0;

  Future<void> _pick() async {
    // RA-MO-354: today in Sana'a, as the server counts the plan's days.
    final today = sanaaToday();
    final last = DateTime(today.year + 5);
    // RA-MO-351: the old day plus a month, but never before today (a month
    // after the wedding it was, and the picker failed its own assertion)
    // nor after the last day allowed.
    final proposed = _newDay ?? addPlanDays(widget.oldDay, 30);
    final initial = proposed.isBefore(today)
        ? today
        : proposed.isAfter(last)
        ? last
        : proposed;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: last,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _newDay = picked;
      _error = null;
    });
  }

  Future<void> _apply() async {
    final next = _newDay;
    final days = _days;
    if (next == null || days == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final plans = context.read<WeddingPlansProvider>();
    final dashboard = context.read<DashboardSummaryProvider>();
    // RA-BE-116: the day and its open tasks in one save: the server moves
    // them by the day's own difference, so a retry after a lost answer finds
    // the day already moved and moves nothing twice.
    final updated = await plans.updateWeddingPlan(widget.planId, {
      'weddingDate': planDayToJson(next),
      'moveOpenTasks': true,
    });
    if (!mounted) return;
    if (updated == null) {
      setState(() {
        _saving = false;
        _error =
            plans.errorMessage ??
            'ما قدرنا نغيّر الموعد. '
                '${context.say('جرّب', 'جرّبي')} مرة ثانية.';
      });
      return;
    }
    await dashboard.loadDashboard(widget.planId);
    if (!mounted) return;
    AarastToast.showSuccess(context, 'صار عرسك ${formatArabicDayMonth(next)}.');
    Navigator.of(context).pop(true);
  }

  /// RA-BE-183 (Q-47): the wedding is put off with no new day yet (money,
  /// the war): the day is cleared, so the countdown and the reminders of
  /// its day stop and the home is back to «no day yet». Nothing moves: the
  /// events and the tasks keep their days until a new one is set.
  Future<void> _clearDay() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final plans = context.read<WeddingPlansProvider>();
    final dashboard = context.read<DashboardSummaryProvider>();
    final updated = await plans.updateWeddingPlan(widget.planId, {
      'weddingDate': null,
    });
    if (!mounted) return;
    if (updated == null) {
      setState(() {
        _saving = false;
        _error =
            plans.errorMessage ??
            'ما قدرنا نشيل الموعد. '
                '${context.say('جرّب', 'جرّبي')} مرة ثانية.';
      });
      return;
    }
    await dashboard.loadDashboard(widget.planId);
    if (!mounted) return;
    AarastToast.showSuccess(
      context,
      'شلنا موعد العرس. لما يتحدد ${context.say('حطه', 'حطيه')} من «عرسي».',
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final next = _newDay;
    final days = _days;
    final showHijri = context.read<DevicePreferences?>()?.showHijri ?? true;
    final hint = next == null || !showHijri ? null : _seasonLine(next);
    final afterWedding = _afterWedding;
    return JourneySheetBody(
      title: postponeActionTitle(widget.oldDay),
      subtitle: 'نرتب كل شيء على الموعد الجديد',
      children: [
        Row(
          children: [
            Expanded(
              child: _DayCard(
                label: 'كان',
                icon: LucideIcons.calendarX,
                value: formatArabicDayMonth(widget.oldDay),
              ),
            ),
            const SizedBox(width: AarastV3Space.x2),
            Expanded(
              child: _DayCard(
                key: const ValueKey('postpone-new-day'),
                label: 'صار',
                icon: LucideIcons.calendarCheck,
                value: next == null
                    ? context.say('اختر اليوم', 'اختاري اليوم')
                    : formatArabicDayMonth(next),
                selected: true,
                onTap: _pick,
              ),
            ),
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: AarastV3Space.x3),
          Text(
            hint,
            style: JourneyType.of(
              JourneyType.small,
              weight: JourneyType.bold,
              color: context.accent.primary,
            ),
          ),
        ],
        if (days != null) ...[
          const SizedBox(height: AarastV3Space.x4),
          JourneyBox(
            radius: 26,
            padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x2),
            child: Column(
              children: [
                if (_openDatedTasks != null)
                  _ImpactRow(
                    icon: LucideIcons.listChecks,
                    color: AarastV3Color.amber,
                    title: _openDatedTasks == 0
                        ? 'ما فيه مهام تنتقل'
                        : '${arabicCount(_openDatedTasks!, one: 'مهمة واحدة', two: 'مهمتين', few: 'مهام', many: 'مهمة')} '
                              'تنتقل '
                              '${arabicDays(days.abs())}',
                    subtitle: 'المنجز ما يتغير',
                  ),
                if (_oldDayBookings.isNotEmpty)
                  _ImpactRow(
                    key: const ValueKey('postpone-old-bookings'),
                    icon: LucideIcons.building2,
                    color: context.accent.primary,
                    title:
                        '${arabicCount(_oldDayBookings.length, one: 'حجز واحد', two: 'حجزين', few: 'حجوزات', many: 'حجز')} '
                        'على اليوم القديم',
                    subtitle: context.say(
                      'كلّم المزودين على اليوم الجديد',
                      'كلّمي المزودين على اليوم الجديد',
                    ),
                    onTap: () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).pop(false);
                      router.push(AppRouter.planBookings(widget.planId));
                    },
                  ),
                _ImpactRow(
                  icon: LucideIcons.wallet,
                  color: context.accent.primary,
                  title: 'الدفعات تبقى على مواعيدها',
                  subtitle: 'لأنها اتفاق مع المزود',
                ),
              ],
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AarastV3Space.x3),
          JourneyNote(
            key: const ValueKey('postpone-error'),
            icon: LucideIcons.alertCircle,
            color: AarastV3Color.danger,
            soft: AarastV3Color.dangerSoft,
            text: _error!,
          ),
        ],
        const SizedBox(height: AarastV3Space.x4),
        JourneyButton(
          key: const ValueKey('postpone-apply'),
          label: afterWedding
              ? context.say('غيّر التاريخ', 'غيّري التاريخ')
              : context.say('أجّل العرس', 'أجّلي العرس'),
          large: true,
          expand: true,
          loading: _saving,
          onPressed: days == null || _saving ? null : _apply,
        ),
        if (!afterWedding) ...[
          const SizedBox(height: AarastV3Space.x2),
          Center(
            child: JourneyTextAction(
              key: const ValueKey('postpone-no-date'),
              label: 'تأجل وما حددنا موعد',
              color: AarastV3Color.textMuted,
              onPressed: _saving ? null : _clearDay,
            ),
          ),
        ],
      ],
    );
  }
}

/// «بعد عيد الفطر · 8 ذو القعدة»: where the new day falls in the Hijri year,
/// with the seasons a Yemeni wedding plans around. The Eid's own day is
/// named as itself (RA-MO-356: «بعد عيد الأضحى» was said on the day).
String? _seasonLine(DateTime day) {
  final hijri = HijriDate.fromGregorian(day);
  if (hijri == null) return null;
  final season = switch (hijri.month) {
    9 => 'في رمضان',
    10 when hijri.day == 1 => 'يوم عيد الفطر',
    10 || 11 => 'بعد عيد الفطر',
    12 when hijri.day < 10 => 'قبل عيد الأضحى',
    12 when hijri.day == 10 => 'يوم عيد الأضحى',
    12 => 'بعد عيد الأضحى',
    _ => null,
  };
  return season == null ? hijri.dayAndMonth : '$season · ${hijri.dayAndMonth}';
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.label,
    required this.icon,
    required this.value,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final String value;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.fromLTRB(
        AarastV3Space.x4,
        AarastV3Space.x3,
        AarastV3Space.x4,
        AarastV3Space.x3,
      ),
      decoration: BoxDecoration(
        color: AarastV3Color.paper,
        borderRadius: BorderRadius.circular(AarastV3Radius.card),
        border: Border.all(
          color: selected ? context.accent.primary : AarastV3Color.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: AarastV3Icon.lg, color: AarastV3Color.ink),
          const SizedBox(width: AarastV3Space.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
                Text(
                  value,
                  style: JourneyType.of(
                    JourneyType.lead,
                    weight: JourneyType.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return AarastPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AarastV3Radius.card),
      semanticLabel: '$label، $value',
      child: card,
    );
  }
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AarastV3Space.x4,
        vertical: AarastV3Space.x2,
      ),
      child: Row(
        children: [
          Icon(icon, size: AarastV3Icon.lg, color: color),
          const SizedBox(width: AarastV3Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: JourneyType.of(
                    JourneyType.lead,
                    weight: JourneyType.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              LucideIcons.chevronLeft,
              size: AarastV3Icon.md,
              color: AarastV3Color.textFaint,
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return AarastPressable(onTap: onTap, semanticLabel: title, child: row);
  }
}
