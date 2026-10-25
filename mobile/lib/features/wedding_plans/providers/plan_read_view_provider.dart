import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../data/wedding_plans_api.dart';
import '../models/plan_read_view.dart';

/// D52: the plan as every member reads it, for the participant's read-only
/// pages (the home, the tasks, the guests and the providers).
class PlanReadViewProvider extends ChangeNotifier with SessionScopedNotifier {
  PlanReadViewProvider({required this.weddingPlansApi});

  final WeddingPlansApi weddingPlansApi;

  bool _isLoading = false;
  String? _errorMessage;
  PlanReadView? _view;
  int _loadGeneration = 0;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// The plan's view, or null when [weddingPlanId] is not the one loaded.
  PlanReadView? viewOf(String weddingPlanId) =>
      _view?.weddingPlanId == weddingPlanId ? _view : null;

  Future<void> load(String weddingPlanId) async {
    final generation = ++_loadGeneration;
    _isLoading = true;
    _errorMessage = null;
    if (_view?.weddingPlanId != weddingPlanId) _view = null;
    notifyListeners();
    try {
      final next = await weddingPlansApi.getPlanReadView(weddingPlanId);
      if (generation != _loadGeneration || isSessionDisposed) return;
      _view = next;
    } on ApiException catch (error) {
      if (generation == _loadGeneration && !isSessionDisposed) {
        _errorMessage = error.message;
      }
    } catch (_) {
      if (generation == _loadGeneration && !isSessionDisposed) {
        _errorMessage = 'ما قدرنا نجيب الخطة.';
      }
    } finally {
      if (generation == _loadGeneration && !isSessionDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
