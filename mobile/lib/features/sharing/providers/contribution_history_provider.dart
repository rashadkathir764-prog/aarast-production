import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../data/sharing_api.dart';
import '../models/contribution_history.dart';

/// A participant whose history the owner reads (x20). The server never sends
/// a name with an event, so the owner asks for each participant by id.
@immutable
class ContributionActor {
  const ContributionActor({required this.userId, required this.name});

  final String userId;
  final String name;
}

/// One history row and who did it; [actor] is null in a participant's own
/// history.
@immutable
class ContributionActivity {
  const ContributionActivity({required this.event, this.actor});

  final ContributionHistoryEvent event;
  final ContributionActor? actor;
}

/// The frozen contribution history of one plan.
///
/// A participant reads one list: their own. The plan owner reads one list per
/// participant (the documented `contributorUserId` filter) and sees them
/// merged newest first. While a list still has older pages, rows older than
/// its oldest loaded row wait for the next page, so the merged order never
/// skips a row.
class ContributionHistoryProvider extends ChangeNotifier
    with SessionScopedNotifier {
  ContributionHistoryProvider(this._api);

  static const pageSize = 50;

  final SharingApi _api;

  List<_HistoryStream> _streams = const [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _requiresReload = false;
  bool _hasLoaded = false;
  String? _errorMessage;
  String? _loadMoreError;
  int _loadGeneration = 0;
  String? _weddingPlanId;
  String? _section;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get requiresReload => _requiresReload;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;
  String? get loadMoreError => _loadMoreError;
  String? get section => _section;

  bool get hasMore =>
      !_requiresReload && _streams.any((stream) => stream.hasMore);

  /// Where the history begins; older plan data is not attributed.
  DateTime? get coverageStartsAt {
    for (final stream in _streams) {
      final coverage = stream.coverage;
      if (coverage != null) return coverage;
    }
    return null;
  }

  /// The rows to show, newest first.
  List<ContributionActivity> get activities {
    if (_streams.length == 1) {
      // One list keeps the server's order as it is.
      final stream = _streams.single;
      return [
        for (final event in stream.events)
          ContributionActivity(event: event, actor: stream.actor),
      ];
    }
    final rows = [
      for (final stream in _streams)
        for (final event in stream.events)
          ContributionActivity(event: event, actor: stream.actor),
    ]..sort((a, b) => _compareNewestFirst(a.event, b.event));
    if (_requiresReload) return rows;
    _HistoryKey? threshold;
    for (final stream in _streams.where((stream) => stream.hasMore)) {
      final oldest = stream.oldestKey;
      if (oldest == null) continue;
      if (threshold == null || oldest.compareTo(threshold) > 0) {
        threshold = oldest;
      }
    }
    if (threshold == null) return rows;
    final limit = threshold;
    return [
      for (final row in rows)
        if (_HistoryKey.of(row.event).compareTo(limit) >= 0) row,
    ];
  }

  /// Loads the first page. [actors] null reads the caller's own history; a
  /// list reads each participant's (the owner's view), and an empty list
  /// means there is nobody to read.
  Future<void> load(
    String weddingPlanId, {
    String? section,
    List<ContributionActor>? actors,
  }) async {
    final generation = ++_loadGeneration;
    _weddingPlanId = weddingPlanId;
    _section = section;
    _streams = [
      if (actors == null)
        _HistoryStream(null)
      else
        for (final actor in actors) _HistoryStream(actor),
    ];
    _errorMessage = null;
    _loadMoreError = null;
    _requiresReload = false;
    _hasLoaded = false;
    // A new generation owns the pagination gate immediately. A stale
    // load-more future must not leave the new plan permanently blocked.
    _isLoadingMore = false;
    _isLoading = true;
    notifyListeners();
    final streams = _streams;
    try {
      final pages = await Future.wait([
        for (final stream in streams)
          _api.getContributionHistory(
            weddingPlanId,
            limit: pageSize,
            offset: 0,
            section: section,
            contributorUserId: stream.actor?.userId,
          ),
      ]);
      if (!_isCurrent(generation, weddingPlanId)) return;
      for (var index = 0; index < streams.length; index += 1) {
        streams[index].accept(pages[index]);
      }
      _hasLoaded = true;
    } on ApiException catch (error) {
      if (_isCurrent(generation, weddingPlanId)) {
        _errorMessage = error.message;
      }
    } on Object {
      if (_isCurrent(generation, weddingPlanId)) {
        _errorMessage = 'ما قدرنا نجيب السجل. جرّب مرة ثانية.';
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
    if (weddingPlanId == null ||
        !_hasLoaded ||
        !hasMore ||
        _isLoading ||
        _isLoadingMore) {
      return;
    }
    final generation = _loadGeneration;
    final section = _section;
    final pending = _streams.where((stream) => stream.hasMore).toList();
    _isLoadingMore = true;
    _loadMoreError = null;
    notifyListeners();
    try {
      final pages = await Future.wait([
        for (final stream in pending)
          _api.getContributionHistory(
            weddingPlanId,
            limit: pageSize,
            offset: stream.events.length,
            section: section,
            contributorUserId: stream.actor?.userId,
          ),
      ]);
      if (!_isCurrent(generation, weddingPlanId)) return;
      // Check every page before keeping any, so a changed history never
      // leaves half a page behind.
      for (var index = 0; index < pending.length; index += 1) {
        pending[index].check(pages[index]);
      }
      for (var index = 0; index < pending.length; index += 1) {
        pending[index].append(pages[index]);
      }
    } on FormatException {
      if (_isCurrent(generation, weddingPlanId)) {
        _requiresReload = true;
        _loadMoreError =
            'تغيّر السجل وأنت تقلّب فيه. حدّث السجل من البداية عشان ما يفوتك شي.';
      }
    } on ApiException catch (error) {
      if (_isCurrent(generation, weddingPlanId)) {
        _loadMoreError = error.message;
      }
    } on Object {
      if (_isCurrent(generation, weddingPlanId)) {
        _loadMoreError = 'ما قدرنا نجيب الباقي. جرّب مرة ثانية.';
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

class _HistoryStream {
  _HistoryStream(this.actor);

  final ContributionActor? actor;
  final List<ContributionHistoryEvent> events = [];
  DateTime? coverage;
  int total = 0;

  bool get hasMore => events.length < total;

  _HistoryKey? get oldestKey {
    _HistoryKey? oldest;
    for (final event in events) {
      final key = _HistoryKey.of(event);
      if (oldest == null || key.compareTo(oldest) < 0) oldest = key;
    }
    return oldest;
  }

  void accept(ContributionHistoryResponse page) {
    events
      ..clear()
      ..addAll(page.events);
    coverage = page.historyCoverageStartsAt;
    total = page.total;
  }

  /// Throws [FormatException] when the history moved under the pages.
  void check(ContributionHistoryResponse page) {
    if (page.events.isEmpty && events.length < page.total) {
      throw const FormatException(
        'Contribution history returned an empty non-terminal page',
      );
    }
    final loaded = {for (final event in events) event.id};
    if (page.historyCoverageStartsAt != coverage ||
        page.total < events.length ||
        page.events.any((event) => loaded.contains(event.id))) {
      throw const FormatException(
        'Contribution history pagination snapshot changed',
      );
    }
  }

  void append(ContributionHistoryResponse page) {
    events.addAll(page.events);
    total = page.total;
  }
}

/// The server's order: newest capture first, then the larger id.
@immutable
class _HistoryKey implements Comparable<_HistoryKey> {
  const _HistoryKey(this.capturedAt, this.id);

  factory _HistoryKey.of(ContributionHistoryEvent event) =>
      _HistoryKey(event.capturedAt, event.id);

  final DateTime capturedAt;
  final String id;

  @override
  int compareTo(_HistoryKey other) {
    final byTime = capturedAt.compareTo(other.capturedAt);
    return byTime != 0 ? byTime : id.compareTo(other.id);
  }
}

int _compareNewestFirst(
  ContributionHistoryEvent a,
  ContributionHistoryEvent b,
) => _HistoryKey.of(b).compareTo(_HistoryKey.of(a));
