import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../data/wedding_plans_api.dart';
import '../models/wedding_plan.dart';

class WeddingPlansProvider extends ChangeNotifier {
  WeddingPlansProvider(this._api);

  final WeddingPlansApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<WeddingPlan> _plans = const [];
  WeddingPlan? _selectedPlan;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  List<WeddingPlan> get plans => _plans;
  WeddingPlan? get selectedPlan => _selectedPlan;

  Future<void> loadMyWeddingPlans() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _plans = await _api.getMyWeddingPlans();
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'تعذر تحميل خطط الزفاف.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadWeddingPlan(String id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedPlan = await _api.getWeddingPlan(id);
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'تعذر تحميل خطة الزفاف.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<WeddingPlan?> createWeddingPlan({
    required String title,
    String? city,
    DateTime? weddingDate,
    String? estimatedBudget,
    String currency = 'YER',
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final plan = await _api.createWeddingPlan(
        title: title,
        city: city,
        weddingDate: weddingDate,
        estimatedBudget: estimatedBudget,
        currency: currency,
      );
      _selectedPlan = plan;
      _plans = [plan, ..._plans.where((item) => item.id != plan.id)];
      return plan;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } catch (_) {
      _errorMessage = 'تعذر إنشاء خطة الزفاف.';
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
