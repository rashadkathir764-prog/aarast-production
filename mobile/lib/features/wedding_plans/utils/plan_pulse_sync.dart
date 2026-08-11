import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../guests/models/guest.dart';
import '../../tasks/models/task_summary.dart';
import '../providers/dashboard_summary_provider.dart';

/// Publishes already-confirmed domain summaries to the visible plan pulse.
///
/// The dashboard remains a projection, not a second source of truth. Missing
/// dashboard scope is valid in isolated routes and preview tests.
void publishTaskPlanPulse(
  BuildContext context, {
  required String weddingPlanId,
  required TaskSummary summary,
}) {
  context.read<DashboardSummaryProvider?>()?.reconcileTaskCounts(
    weddingPlanId: weddingPlanId,
    total: summary.total,
    completed: summary.completed,
    overdue: summary.overdue,
    dueToday: summary.dueToday,
  );
}

void publishGuestPlanPulse(
  BuildContext context, {
  required String weddingPlanId,
  required GuestSummary summary,
}) {
  context.read<DashboardSummaryProvider?>()?.reconcileGuestCounts(
    weddingPlanId: weddingPlanId,
    total: summary.totalGuests,
    confirmed: summary.confirmed,
    pending: summary.pending,
    declined: summary.declined,
    incomplete: summary.incompleteGuestsCount,
  );
}
