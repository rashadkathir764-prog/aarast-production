import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../data/sharing_api.dart';
import '../models/contribution_history.dart';

class ContributionHistoryProvider extends ChangeNotifier
    with SessionScopedNotifier {
  ContributionHistoryProvider(this._api);

  static const pageSize = 50;

  final SharingApi _api;

  ContributionHistoryResponse? _response;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _requiresReload = false;
  String? _errorMessage;
  String? _loadMoreError;
  int _loadGeneration = 0;
  int _nextOffset = 0;
  String? _weddingPlanId;

  ContributionHistoryResponse? get response => _response;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get requiresReload => _requiresReload;
  String? get errorMessage => _errorMessage;
  String? get loadMoreError => _loadMoreError;

  Future<void> load(String weddingPlanId) async {
    final generation = ++_loadGeneration;
    _weddingPlanId = weddingPlanId;
    _response = null;
    _errorMessage = null;
    _loadMoreError = null;
    _nextOffset = 0;
    _hasMore = false;
    _requiresReload = false;
    // A new generation owns the pagination gate immediately. A stale
    // load-more future must not leave the new plan permanently blocked.
    _isLoadingMore = false;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.getContributionHistory(
        weddingPlanId,
        limit: pageSize,
        offset: 0,
      );
      if (!_isCurrent(generation, weddingPlanId)) return;
      _response = response;
      _nextOffset = response.events.length;
      _hasMore = _nextOffset < response.total;
    } on ApiException catch (error) {
      if (_isCurrent(generation, weddingPlanId)) {
        _errorMessage = error.message;
      }
    } on Object {
      if (_isCurrent(generation, weddingPlanId)) {
        _errorMessage = 'تعذر تحميل سجل مساهماتك. حاول مرة أخرى.';
      }
    } finally {
      if (_isCurrent(generation, weddingPlanId)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    final weddingPlanId = _weddingPlanId;
    final current = _response;
    if (weddingPlanId == null ||
        current == null ||
        !_hasMore ||
        _isLoading ||
        _isLoadingMore) {
      return;
    }
    final generation = _loadGeneration;
    final requestedOffset = _nextOffset;
    _isLoadingMore = true;
    _loadMoreError = null;
    notifyListeners();
    try {
      final page = await _api.getContributionHistory(
        weddingPlanId,
        limit: pageSize,
        offset: requestedOffset,
      );
      if (!_isCurrent(generation, weddingPlanId)) return;
      if (page.events.isEmpty && requestedOffset < page.total) {
        throw const FormatException(
          'Contribution history returned an empty non-terminal page',
        );
      }
      if (page.historyCoverageStartsAt != current.historyCoverageStartsAt ||
          page.total < current.events.length ||
          page.events.any(
            (event) => current.events.any((loaded) => loaded.id == event.id),
          )) {
        throw const FormatException(
          'Contribution history pagination snapshot changed',
        );
      }
      final byId = <String, ContributionHistoryEvent>{
        for (final event in current.events) event.id: event,
        for (final event in page.events) event.id: event,
      };
      _nextOffset = requestedOffset + page.events.length;
      _hasMore = _nextOffset < page.total;
      _response = ContributionHistoryResponse(
        historyCoverageStartsAt: current.historyCoverageStartsAt,
        events: List.unmodifiable(byId.values),
        total: page.total,
      );
    } on FormatException {
      if (_isCurrent(generation, weddingPlanId)) {
        _requiresReload = true;
        _hasMore = false;
        _loadMoreError =
            'تغيّر السجل أثناء تحميل الصفحات. حدّث السجل من البداية لضمان عدم فقد أي مساهمة.';
      }
    } on ApiException catch (error) {
      if (_isCurrent(generation, weddingPlanId)) {
        _loadMoreError = error.message;
      }
    } on Object {
      if (_isCurrent(generation, weddingPlanId)) {
        _loadMoreError = 'تعذر تحميل بقية سجل مساهماتك. حاول مرة أخرى.';
      }
    } finally {
      if (_isCurrent(generation, weddingPlanId)) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrent(int generation, String weddingPlanId) {
    return !isSessionDisposed &&
        generation == _loadGeneration &&
        weddingPlanId == _weddingPlanId;
  }
}
