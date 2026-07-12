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

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DashboardSummary? get summary => _summary;
  WeddingPlan? get plan => _plan;

  Future<void> loadDashboard(
    String weddingPlanId, {
    SharedMember? sharedMember,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final nextSummary = await weddingPlansApi.getDashboardSummary(
        weddingPlanId,
      );
      _summary = nextSummary;
      _plan = nextSummary.toWeddingPlan();
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'تعذر تحميل بيانات اللوحة.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
