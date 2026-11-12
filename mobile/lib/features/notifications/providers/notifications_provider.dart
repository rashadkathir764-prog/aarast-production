import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cached_first_load.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../data/notifications_api.dart';
import '../models/aarast_notification.dart';

class NotificationsProvider extends ChangeNotifier with SessionScopedNotifier {
  NotificationsProvider(this._api);

  final NotificationsApi _api;

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
      final now = DateTime.now();
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

  void _replace(AarastNotification updated) {
    _notifications = [
      for (final item in _notifications) item.id == updated.id ? updated : item,
    ];
  }
}
