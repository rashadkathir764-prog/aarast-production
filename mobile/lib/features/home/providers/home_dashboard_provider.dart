import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../../sharing/sharing_api.dart' show SharedWeddingPlan, SharingApi;
import '../../wedding_plans/wedding_plans_api.dart'
    show WeddingPlan, WeddingPlansApi;

class HomeDashboardProvider extends ChangeNotifier with SessionScopedNotifier {
  HomeDashboardProvider({
    required this.weddingPlansApi,
    required this.sharingApi,
  });

  final WeddingPlansApi weddingPlansApi;
  final SharingApi sharingApi;

  bool _isLoading = false;
  String? _errorMessage;
  List<WeddingPlan> _myPlans = [];
  List<SharedWeddingPlan> _sharedPlans = [];
  WeddingPlan? _primaryPlan;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<WeddingPlan> get myPlans => _myPlans;
  List<SharedWeddingPlan> get sharedPlans => _sharedPlans;
  WeddingPlan? get primaryPlan => _primaryPlan;

  Future<void> loadDashboard() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final plansResult = await Future.wait([
        weddingPlansApi.getMyWeddingPlans(),
        sharingApi.getSharedWeddingPlans(),
      ]);
      if (isSessionDisposed) return;
      _myPlans = plansResult[0] as List<WeddingPlan>;
      _sharedPlans = plansResult[1] as List<SharedWeddingPlan>;
      _primaryPlan = _myPlans.isEmpty ? null : _myPlans.first;
    } on ApiException catch (error) {
      if (!isSessionDisposed) _errorMessage = error.message;
    } catch (_) {
      if (!isSessionDisposed) _errorMessage = 'تعذر تحميل لوحة التحكم.';
    } finally {
      if (!isSessionDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
