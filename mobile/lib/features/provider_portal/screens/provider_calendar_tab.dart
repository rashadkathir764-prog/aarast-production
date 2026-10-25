import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_calendar_parts.dart';
import '../widgets/provider_day_sheet.dart';

/// p28 «التقويم»: his month at day level. A day is booked, waiting for his
/// confirmation, closed or free (F9, F11); the drawn «باقي N», the teams
/// and the freshness note need a capacity the server does not hold (D-2,
/// B-20, B-25), and «حجز من برا» has no endpoint. A day opens p29; «أقفل
/// أيام» picks free days and closes them together.
class ProviderCalendarTab extends StatefulWidget {
  const ProviderCalendarTab({super.key});

  @override
  State<ProviderCalendarTab> createState() => _ProviderCalendarTabState();
}

class _ProviderCalendarTabState extends State<ProviderCalendarTab> {
  late DateTime _month = DateTime(providerToday().year, providerToday().month);

  /// Null outside the picking; the days picked to close inside it.
  Set<DateTime>? _picking;
  bool _closing = false;

  /// He looks from this month on: the server keeps no past booking in the
  /// list (F10) and a past day cannot be closed.
  static const _monthsAhead = 36;

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final showHijri = context.watch<DevicePreferences?>()?.showHijri ?? true;
    final today = providerToday();
    final first = DateTime(today.year, today.month);
    final last = DateTime(today.year, today.month + _monthsAhead);
    final hijri = showHijri ? providerHijriMonthsLabel(_month) : null;
    final picking = _picking;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AarastV3Color.primary,
            onRefresh: dashboard.loadDashboard,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                JourneyTabHeader(
                  title: 'التقويم',
                  status: picking != null
                      ? 'اختر الأيام اللي تقفلها'
                      : [providerMonthLabel(_month), ?hijri].join(' · '),
                  actions: [
                    JourneyRoundButton(
                      key: const Key('provider-calendar-previous'),
                      icon: LucideIcons.chevronRight,
                      tooltip: 'الشهر اللي قبل',
                      onPressed: _month.isAfter(first) ? () => _move(-1) : null,
                    ),
                    JourneyRoundButton(
                      key: const Key('provider-calendar-next'),
                      icon: LucideIcons.chevronLeft,
                      tooltip: 'الشهر الجاي',
                      onPressed: _month.isBefore(last) ? () => _move(1) : null,
                    ),
                  ],
                ),
                if (picking != null) ...[
                  Text(
                    providerMonthLabel(_month),
                    style: JourneyType.of(
                      JourneyType.bodySmall,
                      weight: JourneyType.bold,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                ProviderMonthGrid(
                  month: _month,
                  today: today,
                  dayOf: (day) => providerDayOf(day, dashboard),
                  selected: picking ?? const {},
                  onDay: (day) => _onDay(day, dashboard),
                ),
                const SizedBox(height: 10),
                ProviderCalendarLegend(
                  capacity: dashboard.profile?.dailyBookingCapacity ?? 1,
                ),
                if (dashboard.errorMessage case final error?) ...[
                  const SizedBox(height: 12),
                  JourneyNote(
                    key: const Key('provider-calendar-error'),
                    text: error,
                    icon: LucideIcons.alertCircle,
                    color: AarastV3Color.danger,
                    soft: AarastV3Color.dangerSoft,
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          // The bottom bar floats over the tab; its height is in the
          // bottom padding the frame gives the body.
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          child: picking == null
              ? JourneyButton(
                  key: const Key('provider-calendar-close-days'),
                  label: 'أقفل أيام',
                  background: AarastV3Color.paper,
                  foreground: AarastV3Color.primary,
                  expand: true,
                  onPressed: () => setState(() => _picking = {}),
                )
              : Row(
                  children: [
                    Expanded(
                      child: JourneyButton(
                        key: const Key('provider-calendar-close-picked'),
                        label: picking.isEmpty
                            ? 'أقفل'
                            : 'أقفل ${arabicCount(picking.length, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم')}',
                        icon: LucideIcons.calendarX,
                        expand: true,
                        loading: _closing,
                        onPressed: picking.isEmpty
                            ? null
                            : () => _closePicked(dashboard),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: JourneyButton(
                        key: const Key('provider-calendar-cancel-pick'),
                        label: 'إلغاء',
                        background: AarastV3Color.paper,
                        foreground: AarastV3Color.textMuted,
                        expand: true,
                        onPressed: _closing
                            ? null
                            : () => setState(() => _picking = null),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  void _move(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  void _onDay(DateTime day, ProviderDashboardProvider dashboard) {
    final picking = _picking;
    if (picking == null) {
      showProviderDaySheet(context, day);
      return;
    }
    // Only a day he can close: not closed already, no confirmed booking.
    final info = providerDayOf(day, dashboard);
    if (info.closed || info.confirmed.isNotEmpty) return;
    setState(() {
      final picked = picking.where((d) => providerSameDay(d, day));
      if (picked.isEmpty) {
        picking.add(day);
      } else {
        picking.remove(picked.first);
      }
    });
  }

  Future<void> _closePicked(ProviderDashboardProvider dashboard) async {
    final days = [...?_picking]..sort();
    setState(() => _closing = true);
    var closed = 0;
    for (final day in days) {
      if (!await dashboard.blockDate(day)) break;
      closed++;
    }
    if (!mounted) return;
    setState(() {
      _closing = false;
      _picking = closed == days.length ? null : {...days.skip(closed)};
    });
    if (closed == days.length) {
      AarastToast.showSuccess(
        context,
        'قفلت ${arabicCount(closed, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم')}.',
      );
    } else {
      AarastToast.showError(
        context,
        dashboard.errorMessage ?? 'ما قدرنا نقفل كل الأيام.',
      );
    }
  }
}
