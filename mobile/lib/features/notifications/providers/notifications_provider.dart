import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../data/notifications_api.dart';
import '../models/aarast_notification.dart';

class NotificationsProvider extends ChangeNotifier with SessionScopedNotifier {
  NotificationsProvider(this._api);

  final NotificationsApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<AarastNotification> _notifications = const [];
  int _unreadCount = 0;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  List<AarastNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  Future<void> loadNotifications({String? weddingPlanId}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _notifications = await _api.getNotifications(
        weddingPlanId: weddingPlanId,
      );
      _unreadCount = await _api.getUnreadCount();
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'تعذر تحميل التنبيهات.';
    } finally {
      _isLoading = false;
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

  Future<bool> markRead(AarastNotification notification) async {
    if (!notification.isUnread) return true;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _api.markRead(notification.id);
      _replace(updated);
      _unreadCount = await _api.getUnreadCount();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر تحديث التنبيه.';
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
      _unreadCount = await _api.getUnreadCount();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر قراءة كل التنبيهات.';
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
      _unreadCount = await _api.getUnreadCount();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر حذف التنبيه.';
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
      _unreadCount = await _api.getUnreadCount();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر أرشفة التنبيه.';
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
