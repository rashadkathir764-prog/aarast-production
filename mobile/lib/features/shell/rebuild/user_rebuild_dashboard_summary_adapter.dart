import 'package:flutter/material.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../wedding_plans/models/plan_summary_readiness.dart';
import 'user_rebuild_placeholder_tab.dart';
import 'user_rebuild_tab.dart';

class UserRebuildDashboardSummaryAdapter extends StatelessWidget {
  const UserRebuildDashboardSummaryAdapter({
    super.key,
    this.featureFlags = AppFeatureFlags.defaults,
    this.readiness = const PlanSummaryReadiness.empty(),
  });

  final AppFeatureFlags featureFlags;
  final PlanSummaryReadiness readiness;

  static const noPlanMessage =
      'ملخص الخطة الداخلي يحتاج خطة حالية حقيقية قبل عرض البيانات';

  @override
  Widget build(BuildContext context) {
    if (!featureFlags.enableSingleDashboardSummary) {
      return UserRebuildPlaceholderTab.fromTab(UserRebuildTab.home);
    }

    if (!readiness.isReadyForDashboardAdapter) {
      return _SummaryStateNotice(message: _stateMessage);
    }

    final metrics = _metrics();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.dashboard_customize_outlined, size: 44),
                  const SizedBox(height: 12),
                  const Text(
                    'ملخص الخطة الداخلي',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    readiness.planTitle ?? readiness.currentPlanId ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (metrics.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: metrics
                          .map((metric) => _SummaryMetricChip(metric))
                          .toList(growable: false),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _stateMessage {
    if (readiness.isLoading) {
      return 'ملخص الخطة الداخلي قيد التحميل';
    }
    if (readiness.hasError) {
      return readiness.errorMessage!.trim();
    }
    return noPlanMessage;
  }

  List<String> _metrics() {
    final metrics = <String>[];
    final estimatedBudget = readiness.estimatedBudget?.trim();
    if (estimatedBudget != null && estimatedBudget.isNotEmpty) {
      metrics.add('$estimatedBudget ${readiness.currency ?? ''}'.trim());
    }

    final taskCount = readiness.taskCount;
    if (taskCount != null) {
      metrics.add('$taskCount مهام');
    }

    final dueInstallmentCount = readiness.dueInstallmentCount;
    if (dueInstallmentCount != null) {
      metrics.add('$dueInstallmentCount قسط');
    }

    final sharedMemberCount = readiness.sharedMemberCount;
    if (sharedMemberCount != null) {
      metrics.add('$sharedMemberCount مشارك');
    }

    final pendingSyncCount = readiness.pendingSyncCount;
    if (pendingSyncCount != null) {
      metrics.add('$pendingSyncCount تغييرات بانتظار المزامنة');
    }

    return metrics;
  }
}

class _SummaryStateNotice extends StatelessWidget {
  const _SummaryStateNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.dashboard_customize_outlined, size: 44),
                  const SizedBox(height: 12),
                  const Text(
                    'ملخص الخطة الداخلي',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryMetricChip extends StatelessWidget {
  const _SummaryMetricChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
