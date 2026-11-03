import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cached_first_load.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../../sharing/sharing_api.dart' show SharedMember;
import '../data/wedding_plans_api.dart';
import '../models/dashboard_summary.dart';
import '../models/wedding_plan.dart';

class DashboardSummaryProvider extends ChangeNotifier
    with SessionScopedNotifier {
  DashboardSummaryProvider({
    required this.weddingPlansApi,
    Stream<String>? acceptedWrites,
    Duration writeSettle = const Duration(milliseconds: 400),
  }) : _writeSettle = writeSettle {
    _writes = acceptedWrites?.listen(_onAcceptedWrite);
  }

  final WeddingPlansApi weddingPlansApi;
  final Duration _writeSettle;
  StreamSubscription<String>? _writes;
  Timer? _readAgain;

  bool _isLoading = false;
  String? _errorMessage;
  DashboardSummary? _summary;
  WeddingPlan? _plan;
  int _loadGeneration = 0;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DashboardSummary? get summary => _summary;
  WeddingPlan? get plan => _plan;

  /// The home is a projection of the plan: a write anywhere reads it again,
  /// once for a burst of writes.
  void _onAcceptedWrite(String path) {
    final planId = _summary?.planId;
    if (planId == null || !_summary!.accountBacked) return;
    const outsideThePlan = [
      '/auth/',
      '/notifications',
      '/push',
      '/conversations',
      '/media',
    ];
    if (outsideThePlan.any(path.contains)) return;
    _readAgain?.cancel();
    _readAgain = Timer(_writeSettle, () => loadDashboard(planId));
  }

  @override
  void dispose() {
    _readAgain?.cancel();
    _writes?.cancel();
    super.dispose();
  }

  /// Publishes the already-persisted local guest summary to the shared plan
  /// chrome. This keeps plan identity and stage stable while local planning
  /// moves between routed tabs, without treating local data as server-backed.
  void publishLocalSummary(DashboardSummary summary) {
    if (summary.accountBacked || summary.dataScope != 'LOCAL') {
      throw ArgumentError.value(
        summary.dataScope,
        'summary',
        'Only a LOCAL non-account-backed summary can be published locally.',
      );
    }
    _loadGeneration++;
    _isLoading = false;
    _errorMessage = null;
    _summary = summary;
    _plan = summary.toWeddingPlan();
    notifyListeners();
  }

  /// Reconciles the dashboard immediately from the already-confirmed task
  /// mutation. This avoids stale counts while the user returns between tabs.
  void reconcileTaskCounts({
    required String weddingPlanId,
    required int total,
    required int completed,
    required int overdue,
    required int dueToday,
  }) {
    final current = _summary;
    if (current == null || current.planId != weddingPlanId) return;
    final safeTotal = total.clamp(0, 1000000);
    final safeCompleted = completed.clamp(0, safeTotal);
    _summary = current.copyWithPulse(
      totalTasks: safeTotal,
      completedTasks: safeCompleted,
      overdueTasks: overdue.clamp(0, safeTotal - safeCompleted),
      todayTasks: dueToday.clamp(0, safeTotal - safeCompleted),
    );
    notifyListeners();
  }

  /// Same immediate reconciliation for guest mutations. All values come from
  /// [GuestsProvider]'s real post-mutation summary, never from invented UI data.
  void reconcileGuestCounts({
    required String weddingPlanId,
    required int total,
    required int confirmed,
    required int pending,
    required int declined,
    required int incomplete,
  }) {
    final current = _summary;
    if (current == null || current.planId != weddingPlanId) return;
    final safeTotal = total.clamp(0, 1000000);
    _summary = current.copyWithPulse(
      guestCount: safeTotal,
      confirmedGuests: confirmed.clamp(0, safeTotal),
      pendingGuests: pending.clamp(0, safeTotal),
      declinedGuests: declined.clamp(0, safeTotal),
      incompleteGuestsCount: incomplete.clamp(0, safeTotal),
    );
    notifyListeners();
  }

  /// D85: the copy stays because the server did not answer.
  bool _isStale = false;
  bool get isStale => _isStale;

  /// D85: the phone's copy of the home shows at once; the server's answer
  /// replaces it, and a server out of reach keeps it (stale) instead of a
  /// spinner or an error.
  Future<void> loadDashboard(
    String weddingPlanId, {
    SharedMember? sharedMember,
  }) async {
    final generation = ++_loadGeneration;
    bool current() => generation == _loadGeneration && !isSessionDisposed;
    await readCachedFirst<DashboardSummary>(
      cached: () => weddingPlansApi.cachedDashboardSummary(weddingPlanId),
      remote: () => weddingPlansApi.getDashboardSummary(weddingPlanId),
      apply: (summary) {
        if (!current()) return;
        _summary = summary;
        _plan = summary.toWeddingPlan();
      },
      state: ({required loading, required stale, error}) {
        if (!current()) return;
        _isLoading = loading;
        _isStale = stale;
        _errorMessage = error;
        notifyListeners();
      },
      describe: (error) =>
          error is ApiException ? error.message : 'ما قدرنا نجيب خطتك الحين.',
    );
  }
}
