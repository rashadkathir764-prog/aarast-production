import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../data/wedding_plans_api.dart';
import '../models/active_wedding_plan.dart';
import '../models/onboarding_complete.dart';
import '../models/wedding_plan.dart';

class WeddingPlansProvider extends ChangeNotifier with SessionScopedNotifier {
  WeddingPlansProvider(this._api);

  final WeddingPlansApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _noticeMessage;
  List<WeddingPlan> _plans = const [];
  WeddingPlan? _selectedPlan;
  ActiveWeddingPlan? _activePlan;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;
  List<WeddingPlan> get plans => _plans;
  WeddingPlan? get selectedPlan => _selectedPlan;
  ActiveWeddingPlan? get activePlan => _activePlan;
  bool get hasActivePlan => _activePlan != null;
  bool get shouldOpenOnboarding =>
      !_isLoading && _errorMessage == null && _activePlan == null;

  Future<void> loadActiveWeddingPlan() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _activePlan = await _api.getActiveWeddingPlan();
      _selectedPlan = _activePlan?.toWeddingPlan();
      if (_selectedPlan != null) {
        _plans = [
          _selectedPlan!,
          ..._plans.where((item) => item.id != _selectedPlan!.id),
        ];
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'تعذر تحميل الخطة الحالية.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
    Map<String, dynamic>? location,
    DateTime? weddingDate,
    String? estimatedBudget,
    String currency = 'YER',
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final plan = await _api.createWeddingPlan(
        title: title,
        city: city,
        location: location,
        weddingDate: weddingDate,
        estimatedBudget: estimatedBudget,
        currency: currency,
      );
      _selectedPlan = plan;
      _activePlan = ActiveWeddingPlan.fromWeddingPlan(plan);
      _plans = [plan, ..._plans.where((item) => item.id != plan.id)];
      if (plan.id.startsWith('local-')) {
        _noticeMessage = CachePolicy.offlineWriteMessage;
      }
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

  Future<ActiveWeddingPlan?> setActiveWeddingPlan(String id) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final active = await _api.setActiveWeddingPlan(id);
      _activePlan = active;
      final plan = active.toWeddingPlan();
      _selectedPlan = plan;
      _plans = [plan, ..._plans.where((item) => item.id != plan.id)];
      return active;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } catch (_) {
      _errorMessage = 'تعذر فتح الخطة المختارة.';
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<OnboardingCompleteResponse?> completeOnboarding(
    OnboardingCompleteRequest request,
  ) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final response = await _api.completeOnboarding(request);
      _activePlan = response.activeWeddingPlan;
      final plan = response.activeWeddingPlan.toWeddingPlan();
      _selectedPlan = plan;
      _plans = [plan, ..._plans.where((item) => item.id != plan.id)];
      return response;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } catch (_) {
      _errorMessage = 'تعذر إنشاء خطتك. تأكد من الاتصال وحاول مرة أخرى.';
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<WeddingPlan?> updateWeddingPlan(
    String id,
    Map<String, dynamic> data,
  ) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final plan = await _api.updateWeddingPlan(id, data);
      _selectedPlan = plan;
      _plans = [for (final item in _plans) item.id == id ? plan : item];
      if (_activePlan?.id == id) {
        _activePlan = ActiveWeddingPlan.fromWeddingPlan(plan);
      }
      if (plan.id.startsWith('local-')) {
        _noticeMessage = CachePolicy.offlineWriteMessage;
      }
      return plan;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } catch (_) {
      _errorMessage = 'تعذر تحديث خطة الزفاف.';
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<WeddingPlan?> archiveWeddingPlan(String id) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final plan = await _api.archiveWeddingPlan(id);
      _selectedPlan = plan;
      _plans = [for (final item in _plans) item.id == id ? plan : item];
      if (_activePlan?.id == id) {
        _activePlan = null;
      }
      return plan;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } catch (_) {
      _errorMessage = 'تعذر أرشفة خطة الزفاف.';
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
  }
}
