import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../../sharing/models/shared_member.dart';
import '../data/wedding_plans_api.dart';
import '../models/dashboard_summary.dart';
import '../models/wedding_plan.dart';

class DashboardSummaryProvider extends ChangeNotifier
    with SessionScopedNotifier {
  DashboardSummaryProvider({required this.weddingPlansApi});

  final WeddingPlansApi weddingPlansApi;

  bool _isLoading = false;
  String? _errorMessage;
  DashboardSummary? _summary;
  WeddingPlan? _plan;
  int _loadGeneration = 0;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DashboardSummary? get summary => _summary;
  WeddingPlan? get plan => _plan;

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

  Future<void> loadDashboard(
    String weddingPlanId, {
    SharedMember? sharedMember,
  }) async {
    final generation = ++_loadGeneration;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nextSummary = await weddingPlansApi.getDashboardSummary(
        weddingPlanId,
      );
      if (generation != _loadGeneration || isSessionDisposed) return;
      _summary = nextSummary;
      _plan = nextSummary.toWeddingPlan();
    } on ApiException catch (error) {
      if (generation == _loadGeneration && !isSessionDisposed) {
        _errorMessage = error.message;
      }
    } catch (_) {
      if (generation == _loadGeneration && !isSessionDisposed) {
        _errorMessage = 'تعذر تحميل بيانات اللوحة.';
      }
    } finally {
      if (generation == _loadGeneration && !isSessionDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
