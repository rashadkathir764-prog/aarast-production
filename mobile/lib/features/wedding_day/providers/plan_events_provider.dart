import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../data/plan_events_api.dart';
import '../models/plan_event.dart';

/// D65: the open plan's events, read by b12, the wedding week (b04) and
/// day (b05) on the home, and the moments y06 and y07.
class PlanEventsProvider extends ChangeNotifier with SessionScopedNotifier {
  PlanEventsProvider({required this.api});

  final PlanEventsApi api;

  bool _isLoading = false;
  String? _errorMessage;
  PlanEventsView? _view;
  int _loadGeneration = 0;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// The plan's events, or null when [weddingPlanId] is not the one loaded.
  PlanEventsView? viewOf(String weddingPlanId) =>
      _view?.weddingPlanId == weddingPlanId ? _view : null;

  Future<void> load(String weddingPlanId) async {
    final generation = ++_loadGeneration;
    _isLoading = true;
    _errorMessage = null;
    if (_view?.weddingPlanId != weddingPlanId) _view = null;
    notifyListeners();
    try {
      final next = await api.list(weddingPlanId);
      if (generation != _loadGeneration || isSessionDisposed) return;
      _view = next;
    } on ApiException catch (error) {
      if (generation == _loadGeneration && !isSessionDisposed) {
        _errorMessage = error.message;
      }
    } catch (_) {
      if (generation == _loadGeneration && !isSessionDisposed) {
        _errorMessage = 'ما قدرنا نجيب مناسباتك.';
      }
    } finally {
      if (generation == _loadGeneration && !isSessionDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Saves b13: a new event from a suggestion, the wedding's first details,
  /// or an edit. Throws [ApiException] for the sheet to show; reloads after.
  Future<void> save(
    String weddingPlanId, {
    PlanEvent? event,
    PlanEventType? type,
    required PlanEventDraft draft,
  }) async {
    if (event?.id != null) {
      await api.update(weddingPlanId, event!, draft);
    } else {
      await api.create(weddingPlanId, event?.type ?? type!, draft);
    }
    await load(weddingPlanId);
  }

  Future<void> remove(String weddingPlanId, PlanEvent event) async {
    final id = event.id;
    if (id == null) return;
    await api.remove(weddingPlanId, id);
    await load(weddingPlanId);
  }
}
