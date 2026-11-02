import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../providers/provider_dashboard_provider.dart';
import '../widgets/provider_profile_parts.dart';

/// p39 «أداؤك»: his last 30 days from the summary (F16): views of his page,
/// requests, offers customers accepted, and how quickly he usually answers
/// (the public median over 180 days, so it reads «عادة»). The drawn «+18%»
/// has no earlier period to compare with and «ليش ما اختاروك» has no stored
/// reason (F7, B-11, B-30), so neither is shown.
class ProviderPerformanceScreen extends StatefulWidget {
  const ProviderPerformanceScreen({super.key});

  @override
  State<ProviderPerformanceScreen> createState() =>
      _ProviderPerformanceScreenState();
}

class _ProviderPerformanceScreenState extends State<ProviderPerformanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProviderDashboardProvider>().loadResponsiveness();
    });
  }

  Future<void> _refresh() async {
    final dashboard = context.read<ProviderDashboardProvider>();
    await dashboard.loadDashboard();
    await dashboard.loadResponsiveness();
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<ProviderDashboardProvider>();
    final stats = dashboard.summary.stats;
    final hours = dashboard.responsiveness?.typicalResponseHours;
    final cards = stats == null
        ? const <_Metric>[]
        : [
            _Metric(
              key: const Key('provider-performance-views'),
              value: '${stats.profileViews}',
              label: 'مشاهدة لملفك',
            ),
            _Metric(
              key: const Key('provider-performance-requests'),
              value: '${stats.quoteRequests}',
              // «27 طلب», «5 طلبات».
              label:
                  stats.quoteRequests % 100 >= 3 &&
                      stats.quoteRequests % 100 <= 10
                  ? 'طلبات'
                  : 'طلب',
            ),
            if (hours != null)
              _Metric(
                key: const Key('provider-performance-reply'),
                value: providerHoursLabel(hours),
                label: 'عادة ترد خلالها',
              ),
            _Metric(
              key: const Key('provider-performance-accepted'),
              value: '${stats.offersAccepted}',
              label: 'قبلوا عرضك',
              note: stats.acceptanceRate == null
                  ? null
                  : '${stats.acceptanceRate}% من اللي قرروا',
            ),
          ];
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: AarastV3Color.primary,
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AarastV3Density.pageInsets,
          children: [
            JourneySubHeader(
              title: 'أداؤك',
              subtitle: 'آخر ${stats?.windowDays ?? 30} يوم',
            ),
            if (stats == null)
              dashboard.isLoading
                  ? const JourneyListState(
                      phase: JourneyListPhase.loading,
                      section: JourneySection.home,
                    )
                  : JourneyListState(
                      phase: JourneyListPhase.error,
                      section: JourneySection.home,
                      onRetry: _refresh,
                    )
            else ...[
              for (var i = 0; i < cards.length; i += 2) ...[
                if (i > 0) const SizedBox(height: AarastV3Space.x2),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: cards[i]),
                      const SizedBox(width: AarastV3Space.x2),
                      Expanded(
                        child: i + 1 < cards.length
                            ? cards[i + 1]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AarastV3Space.x3),
              JourneyBox(
                key: const Key('provider-performance-bookings'),
                padding: const EdgeInsets.all(AarastV3Space.x3),
                child: Text(
                  stats.upcomingBookings == 0
                      ? 'ما عندك حجز مؤكد جاي.'
                      : 'عندك ${arabicCount(stats.upcomingBookings, one: 'حجز مؤكد جاي', two: 'حجزين مؤكدين جاية', few: 'حجوزات مؤكدة جاية', many: 'حجز مؤكد جاي')}.',
                  style: JourneyType.of(
                    JourneyType.body,
                    weight: JourneyType.bold,
                  ),
                ),
              ),
              const SizedBox(height: AarastV3Space.x2),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AarastV3Space.x1,
                ),
                child: Text(
                  hours == null
                      ? 'الأرقام من طلباتك أنت بس. ما نقارنك بغيرك.'
                      : 'الأرقام من طلباتك أنت بس، ووقت ردك من آخر 6 شهور. ما نقارنك بغيرك.',
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One figure on a white card (prototype `m`): the number, what it counts,
/// and an optional green line under it.
class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.label,
    this.note,
    super.key,
  });

  final String value;
  final String label;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      radius: 18,
      padding: const EdgeInsets.all(AarastV3Space.x3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: JourneyType.of(
              JourneyType.display,
              weight: JourneyType.bold,
            ),
          ),
          Text(
            label,
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
          if (note case final note?)
            Text(
              note,
              style: JourneyType.of(
                JourneyType.caption,
                weight: JourneyType.bold,
                color: AarastV3Color.mint,
              ),
            ),
        ],
      ),
    );
  }
}
