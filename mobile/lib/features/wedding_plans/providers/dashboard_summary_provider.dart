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
