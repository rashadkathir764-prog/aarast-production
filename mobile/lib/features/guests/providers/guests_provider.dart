import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../data/guests_api.dart';
import '../models/guest.dart';

class GuestsProvider extends ChangeNotifier {
  GuestsProvider(this._api);

  final GuestsApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _noticeMessage;
  List<Guest> _guests = const [];
  List<GuestGroup> _groups = const [];
  GuestSummary? _summary;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;
  List<Guest> get guests => _guests;
  List<GuestGroup> get groups => _groups;
  GuestSummary get summary =>
      _summary ??
      GuestSummary.fromGuests(
        weddingPlanId: _guests.isEmpty ? '' : _guests.first.weddingPlanId,
        guests: _guests,
        groups: _groups,
      );

  Future<void> loadGuests(String weddingPlanId) async {
    _isLoading = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      _guests = await _api.getGuests(weddingPlanId);
      _groups = await _api.getGroups(weddingPlanId);
      _summary = await _api.getSummary(
        weddingPlanId: weddingPlanId,
        localGuests: _guests,
        localGroups: _groups,
      );
    } on ApiException catch (error) {
      _errorMessage = _guestErrorMessage(error);
    } catch (_) {
      _errorMessage = 'تعذر تحميل قائمة الضيوف.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createGuest({
    required String weddingPlanId,
    required String name,
    String? phone,
    String? groupId,
    required String side,
    required String status,
    String? attendanceStatus,
    required int seatsCount,
    int? companionsCount,
    String? notes,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final guest = await _api.createGuest(
        weddingPlanId: weddingPlanId,
        name: name,
        phone: phone,
        groupId: groupId,
        side: side,
        status: status,
        attendanceStatus: attendanceStatus,
        seatsCount: seatsCount,
        companionsCount: companionsCount,
        notes: notes,
      );
      _guests = [guest, ..._guests];
      _refreshSummary(weddingPlanId);
      if (_isLocalGuestPlanId(weddingPlanId)) {
        _noticeMessage = CachePolicy.localPlanningSaveMessage;
      }
      return true;
    } on ApiException catch (error) {
      _errorMessage = _guestErrorMessage(error);
      return false;
    } catch (_) {
      _errorMessage = 'تعذر إضافة الضيف.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateGuest({
    required Guest guest,
    String? name,
    String? phone,
    String? groupId,
    String? side,
    String? status,
    String? attendanceStatus,
    int? seatsCount,
    int? companionsCount,
    String? notes,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final updated = await _api.updateGuest(
        id: guest.id,
        name: name,
        phone: phone,
        groupId: groupId,
        side: side,
        status: status,
        attendanceStatus: attendanceStatus,
        seatsCount: seatsCount,
        companionsCount: companionsCount,
        notes: notes,
      );
      _replace(updated);
      _refreshSummary(updated.weddingPlanId);
      if (updated.id.startsWith('local-guest-')) {
        _noticeMessage = CachePolicy.localPlanningSaveMessage;
      }
      return true;
    } on ApiException catch (error) {
      _errorMessage = _guestErrorMessage(error);
      return false;
    } catch (_) {
      _errorMessage = 'تعذر تحديث الضيف.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> deleteGuest(Guest guest) async {
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      await _api.deleteGuest(guest.id);
      _guests = _guests.where((item) => item.id != guest.id).toList();
      _refreshSummary(guest.weddingPlanId);
      if (guest.id.startsWith('local-guest-')) {
        _noticeMessage = CachePolicy.localPlanningSaveMessage;
      }
      return true;
    } on ApiException catch (error) {
      _errorMessage = _guestErrorMessage(error);
      return false;
    } catch (_) {
      _errorMessage = 'تعذر حذف الضيف.';
      return false;
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

  void _replace(Guest updated) {
    _guests = [
      for (final item in _guests) item.id == updated.id ? updated : item,
    ];
  }

  void _refreshSummary(String weddingPlanId) {
    _summary = GuestSummary.fromGuests(
      weddingPlanId: weddingPlanId,
      guests: _guests,
      groups: _groups,
    );
  }
}

bool _isLocalGuestPlanId(String? planId) {
  final value = planId?.trim() ?? '';
  return value.isEmpty ||
      value == 'local-guest-plan' ||
      value.startsWith('guest-plan-') ||
      value.startsWith('local-guest-');
}

String _guestErrorMessage(ApiException error) {
  final normalized = error.message.trim();
  if (error.statusCode == 409 ||
      normalized.contains('هذا الضيف مضاف') ||
      normalized.contains('Guest already exists') ||
      normalized.contains('duplicate')) {
    return 'هذا الضيف مضاف مسبقًا';
  }
  if (normalized.contains('valid Yemeni phone') ||
      normalized.contains('phone must')) {
    return 'رقم الهاتف غير صحيح';
  }
  return normalized.isEmpty ? 'تعذر تنفيذ طلب الضيوف.' : normalized;
}
