import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cached_first_load.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../../../core/utils/app_clock.dart';
import '../data/notifications_api.dart';
import '../models/aarast_notification.dart';

/// What a push tap's notice turned out to be when looked up by its id.
enum NoticeLookupOutcome {
  /// The notice, from the server or the phone's copy.
  found,

  /// The server no longer has it for this account (404 or 403).
  gone,

  /// The server is out of reach and the phone holds no copy of it.
  unreachable,
}

typedef NoticeLookup = ({
  NoticeLookupOutcome outcome,
  AarastNotification? notice,
});

final RegExp _noticeId = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

class NotificationsProvider extends ChangeNotifier with SessionScopedNotifier {
  /// [arrivals]: the app learned a new notice reached the account (a push
  /// in front, the live socket, the server back after a gap): the count is
  /// read again, and an inbox on the screen reads its first page again.
  NotificationsProvider(this._api, {Stream<void>? arrivals}) {
    _arrivals = arrivals?.listen((_) => _noticeArrived());
  }

  final NotificationsApi _api;
  StreamSubscription<void>? _arrivals;
  Timer? _arrivalSettle;

  /// The inboxes on the screen ([inboxOpened]); the plan of the last list
  /// read, so a refresh reads the same one.
  int _openInboxes = 0;
  String? _listedPlanId;

  void inboxOpened() => _openInboxes++;

  void inboxClosed() {
    if (_openInboxes > 0) _openInboxes--;
  }

  /// A burst of arrivals (the push and the socket for the same notice) is
  /// read once.
  void _noticeArrived() {
    _arrivalSettle?.cancel();
    _arrivalSettle = Timer(const Duration(milliseconds: 300), () {
      if (isSessionDisposed) return;
      if (_openInboxes > 0 && !_isLoading) {
        unawaited(loadNotifications(weddingPlanId: _listedPlanId));
      } else {
        unawaited(loadUnreadCount());
      }
    });
  }

  /// A push tap's notice, by its id (item 5 of the notifications work: the
  /// inbox looked for it in its first page alone, so an older one opened
  /// nothing). Offline, the phone's copy of it or of the list stands in.
  Future<NoticeLookup> lookUpNotice(String id) async {
    // A route's `open=` is any text: only a plain id becomes a request path.
    if (!_noticeId.hasMatch(id)) {
      return (outcome: NoticeLookupOutcome.gone, notice: null);
    }
    try {
      final notice = await _api.getNotification(id);
      return (outcome: NoticeLookupOutcome.found, notice: notice);
    } on ApiException catch (error) {
      final status = error.statusCode;
      if (status == 404 || status == 403) {
        return (outcome: NoticeLookupOutcome.gone, notice: null);
      }
    } on Object {
      // An answer the phone could not read: the copies below may hold it.
    }
    final listed = await listedNotice(id);
    return listed == null
        ? (outcome: NoticeLookupOutcome.unreachable, notice: null)
        : (outcome: NoticeLookupOutcome.found, notice: listed);
  }

  /// The notice in the list read, or in the phone's copy of the first page;
  /// null when neither holds it. An inbox that asked for the notice beside
  /// its list asks this again once the list is read.
  Future<AarastNotification?> listedNotice(String id) async {
    final inList = _notifications.where((item) => item.id == id).firstOrNull;
    if (inList != null) return inList;
    try {
      final cached = await _api.cachedNotifications();
      return cached?.items.where((item) => item.id == id).firstOrNull;
    } on Object {
      return null;
    }
  }

  /// Tells the server the notice was opened from its push. Never waited
  /// on and never an error: the open goes on whatever the answer.
  void markOpened(String id) {
    if (!_noticeId.hasMatch(id)) return;
    unawaited(
      _api.markOpened(id).then<void>((_) {}, onError: (Object _) {}),
    );
  }

  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  List<AarastNotification> _notifications = const [];
  int _unreadCount = 0;
  int _page = 0;
  bool _hasMore = false;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  List<AarastNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get hasMore => _hasMore;

  /// D85: the copy stays because the server did not answer.
  bool _isStale = false;
  bool get isStale => _isStale;

  /// D85: the phone's copy of the first page shows at once; the server's
  /// answer replaces it.
  Future<void> loadNotifications({String? weddingPlanId}) async {
    _listedPlanId = weddingPlanId;
    await readCachedFirst<NotificationsPage>(
      cached: () => _api.cachedNotifications(weddingPlanId: weddingPlanId),
      remote: () async {
        final result = await _api.getNotifications(
          weddingPlanId: weddingPlanId,
        );
        // The count is derived; a page that arrived is never lost to it.
        try {
          _unreadCount = await _api.getUnreadCount();
        } on Object {
          _unreadCount = result.items
              .where((item) => item.readAt == null)
              .length;
        }
        return result;
      },
      apply: (result) {
        _notifications = result.items;
        _page = result.page;
        _hasMore = result.hasMore;
      },
      state: ({required loading, required stale, error}) {
        _isLoading = loading;
        _isStale = stale;
        _errorMessage = error;
        notifyListeners();
      },
      describe: (error) =>
          error is ApiException ? error.message : 'ما قدرنا نجيب التنبيهات.',
    );
  }

  Future<void> loadMore({String? weddingPlanId}) async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.getNotifications(
        weddingPlanId: weddingPlanId,
        page: _page + 1,
      );
      final existingIds = _notifications.map((item) => item.id).toSet();
      _notifications = [
        ..._notifications,
        ...result.items.where((item) => existingIds.add(item.id)),
      ];
      _page = result.page;
      _hasMore = result.hasMore;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'ما قدرنا نجيب تنبيهات أكثر.';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadUnreadCount() async {
    try {
      _unreadCount = await _api.getUnreadCount();
      notifyListeners();
    } catch (_) {
      // Badge loading should not interrupt the current screen.
    }
  }

  /// The unread count after an action: a read, not part of the action. A
  /// failure here kept the count as it was and reported the action, which
  /// had happened, as failed («تعذر أرشفة التنبيه»).
  Future<void> _refreshUnreadCount() async {
    try {
      _unreadCount = await _api.getUnreadCount();
    } on Object {
      // The count is read again with the next list.
    }
  }

  Future<bool> markRead(AarastNotification notification) async {
    if (!notification.isUnread) return true;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _api.markRead(notification.id);
      _replace(updated);
      await _refreshUnreadCount();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'ما قدرنا نحدّث التنبيه.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> markAllRead({String? weddingPlanId}) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.markAllRead(weddingPlanId: weddingPlanId);
      final now = appNow();
      _notifications = [
        for (final item in _notifications)
          item.isUnread ? item.copyWith(readAt: now) : item,
      ];
      await _refreshUnreadCount();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'ما قدرنا نعلّم كل التنبيهات مقروءة.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> deleteNotification(AarastNotification notification) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.deleteNotification(notification.id);
      _notifications = _notifications
          .where((item) => item.id != notification.id)
          .toList();
      await _refreshUnreadCount();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'ما قدرنا نحذف التنبيه.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> archiveNotification(AarastNotification notification) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.archiveNotification(notification.id);
      _notifications = _notifications
          .where((item) => item.id != notification.id)
          .toList();
      await _refreshUnreadCount();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'ما قدرنا نأرشف التنبيه.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _arrivalSettle?.cancel();
    unawaited(_arrivals?.cancel());
    super.dispose();
  }

  void _replace(AarastNotification updated) {
    _notifications = [
      for (final item in _notifications) item.id == updated.id ? updated : item,
    ];
  }
}
