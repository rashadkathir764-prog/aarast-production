import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../data/guests_api.dart';
import '../models/guest.dart';

class GuestsProvider extends ChangeNotifier {
  GuestsProvider(this._api);

  final GuestsApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<Guest> _guests = const [];

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  List<Guest> get guests => _guests;

  Future<void> loadGuests(String weddingPlanId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _guests = await _api.getGuests(weddingPlanId);
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
    required String side,
    required String status,
    required int seatsCount,
    String? notes,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final guest = await _api.createGuest(
        weddingPlanId: weddingPlanId,
        name: name,
        phone: phone,
        side: side,
        status: status,
        seatsCount: seatsCount,
        notes: notes,
      );
      _guests = [guest, ..._guests];
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
    String? side,
    String? status,
    int? seatsCount,
    String? notes,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _api.updateGuest(
        id: guest.id,
        name: name,
        phone: phone,
        side: side,
        status: status,
        seatsCount: seatsCount,
        notes: notes,
      );
      _replace(updated);
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
    notifyListeners();

    try {
      await _api.deleteGuest(guest.id);
      _guests = _guests.where((item) => item.id != guest.id).toList();
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
    notifyListeners();
  }

  void _replace(Guest updated) {
    _guests = [
      for (final item in _guests) item.id == updated.id ? updated : item,
    ];
  }
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
