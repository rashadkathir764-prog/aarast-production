import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/cached_first_load.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../data/guests_api.dart';
import '../models/guest.dart';

class GuestsProvider extends ChangeNotifier with SessionScopedNotifier {
  GuestsProvider(this._api);

  final GuestsApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;

  /// The last action that failed (add, save, remove...). Read right after
  /// the action.
  String? _errorMessage;

  /// The list could not be read, so what shows may be old. Only a load sets
  /// it, and the next good read clears it.
  String? _loadErrorMessage;
  String? _noticeMessage;
  List<Guest> _guests = const [];
  List<GuestGroup> _groups = const [];
  GuestSummary? _summary;
  bool _isSavingGroups = false;
  String? _groupsErrorMessage;

  bool get isSavingGroups => _isSavingGroups;
  String? get groupsErrorMessage => _groupsErrorMessage;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get loadErrorMessage => _loadErrorMessage;
  String? get noticeMessage => _noticeMessage;
  List<Guest> get guests => _guests;
  List<GuestGroup> get groups => _groups;

  /// The groups the reader may rename, remove and put guests in (D80).
  List<GuestGroup> get editableGroups =>
      _groups.where((group) => group.editable).toList();
  GuestSummary get summary =>
      _summary ??
      GuestSummary.fromGuests(
        weddingPlanId: _guests.isEmpty ? '' : _guests.first.weddingPlanId,
        guests: _guests,
        groups: _groups,
      );

  /// D85: the phone's copy stays on screen because the server did not
  /// answer; what is shown may be old.
  bool _isStale = false;
  bool get isStale => _isStale;

  /// D85: the phone's copy shows at once; the server's answer replaces it.
  Future<void> loadGuests(String weddingPlanId) async {
    _noticeMessage = null;
    await readCachedFirst<_GuestsBundle>(
      cached: () async {
        final guests = await _api.cachedGuests(weddingPlanId);
        if (guests.isEmpty) return null;
        return _GuestsBundle(guests, await _api.cachedGroups(weddingPlanId));
      },
      remote: () async {
        final guests = await _api.getGuests(weddingPlanId);
        final groups = await _api.getGroups(weddingPlanId);
        // The summary is derived; a list that arrived is never lost to it.
        GuestSummary? summary;
        try {
          summary = await _api.getSummary(
            weddingPlanId: weddingPlanId,
            localGuests: guests,
            localGroups: groups,
          );
        } on Object {
          summary = null;
        }
        return _GuestsBundle(guests, groups, summary);
      },
      apply: (bundle) {
        _guests = bundle.guests;
        _groups = bundle.groups;
        _summary =
            bundle.summary ??
            GuestSummary.fromGuests(
              weddingPlanId: weddingPlanId,
              guests: _guests,
              groups: _groups,
            );
      },
      state: ({required loading, required stale, error}) {
        _isLoading = loading;
        _isStale = stale;
        _loadErrorMessage = error;
        notifyListeners();
      },
      describe: (error) => error is ApiException
          ? _guestErrorMessage(error)
          : 'ما قدرنا نجيب قائمة الضيوف.',
    );
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
    List<String>? eventIds,
  }) async {
    if (_refusePastLimit(weddingPlanId, 1)) return false;
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
        eventIds: eventIds,
      );
      _guests = [guest, ..._guests];
      _refreshSummary(weddingPlanId);
      if (_isLocalGuestPlanId(weddingPlanId)) {
        _noticeMessage = CachePolicy.localPlanningSaveMessage;
      }
      return true;
    } on ApiException catch (error) {
      _errorMessage = _guestErrorMessage(error, savingGuest: true);
      return false;
    } catch (_) {
      _errorMessage = 'ما قدرنا نضيف الضيف.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// e03 / w28: adds [people] to the plan, in [groupId] when given.
  /// Returns how many were added; none on a failure, which says why.
  /// The guests the last [addGuests] could not add (each with the server's
  /// reason in [errorMessage]); empty when all went.
  List<({String name, String? phone})> get lastRefusedGuests =>
      _lastRefusedGuests;
  List<({String name, String? phone})> _lastRefusedGuests = const [];

  Future<int> addGuests({
    required String weddingPlanId,
    required List<({String name, String? phone})> people,
    String? groupId,
  }) async {
    if (people.isEmpty) return 0;
    if (_refusePastLimit(weddingPlanId, people.length)) return 0;
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
    try {
      final result = await _api.createGuestsBulk(
        weddingPlanId: weddingPlanId,
        people: people,
        groupId: groupId,
      );
      final created = result.created;
      // What was added is on the list, whatever was refused after it.
      _guests = [...created, ..._guests];
      _refreshSummary(weddingPlanId);
      _lastRefusedGuests = result.refused;
      if (result.refused.isNotEmpty) {
        _errorMessage = created.isEmpty
            ? result.reason
            : 'انضاف ${created.length}، وما انضاف ${result.refused.length}: '
                  '${result.reason ?? 'جرّب مرة ثانية'}';
      } else if (_isLocalGuestPlanId(weddingPlanId)) {
        _noticeMessage = CachePolicy.localPlanningSaveMessage;
      }
      return created.length;
    } on ApiException catch (error) {
      _errorMessage = _guestErrorMessage(error, savingGuest: true);
      return 0;
    } catch (_) {
      _errorMessage = 'ما قدرنا نضيف الضيوف';
      return 0;
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
    List<String>? eventIds,
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
        eventIds: eventIds,
      );
      _replace(updated);
      _refreshSummary(updated.weddingPlanId);
      if (updated.id.startsWith('local-guest-')) {
        _noticeMessage = CachePolicy.localPlanningSaveMessage;
      }
      return true;
    } on ApiException catch (error) {
      _errorMessage = _guestErrorMessage(error, savingGuest: true);
      return false;
    } catch (_) {
      _errorMessage = 'ما قدرنا نحدّث الضيف.';
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
      _errorMessage = 'ما قدرنا نحذف الضيف.';
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

  Future<bool> createGroup(String weddingPlanId, String name) {
    return _changeGroups(() async {
      final group = await _api.createGroup(
        weddingPlanId: weddingPlanId,
        name: name,
      );
      _groups = [..._groups, group];
    });
  }

  Future<bool> renameGroup(GuestGroup group, String name) {
    return _changeGroups(() async {
      final renamed = await _api.renameGroup(group, name);
      _groups = [
        for (final item in _groups) item.id == renamed.id ? renamed : item,
      ];
    });
  }

  /// Deleting a group keeps its guests; they become ungrouped, here as on
  /// the server.
  Future<bool> deleteGroup(GuestGroup group) {
    return _changeGroups(() async {
      await _api.deleteGroup(group);
      _groups = _groups.where((item) => item.id != group.id).toList();
      _guests = [
        for (final guest in _guests)
          guest.groupId == group.id ? guest.withoutGroup() : guest,
      ];
      _refreshSummary(group.weddingPlanId);
    });
  }

  Future<bool> _changeGroups(Future<void> Function() change) async {
    if (_isSavingGroups) return false;
    _isSavingGroups = true;
    _groupsErrorMessage = null;
    notifyListeners();
    try {
      await change();
      return true;
    } on ApiException catch (error) {
      _groupsErrorMessage = _guestErrorMessage(error);
      return false;
    } catch (_) {
      _groupsErrorMessage = 'ما قدرنا نحفظ المجموعة. جرّب مرة ثانية.';
      return false;
    } finally {
      _isSavingGroups = false;
      notifyListeners();
    }
  }

  /// D99 (RA-BE-62): an add (by hand, from the contacts, a pasted list, on
  /// a plan kept on the phone) that would pass [planGuestsMax] stops here,
  /// in the server's words. The phone's list is the plan's whole list.
  bool _refusePastLimit(String weddingPlanId, int adding) {
    final count = _guests
        .where((guest) => guest.weddingPlanId == weddingPlanId)
        .length;
    if (count + adding <= planGuestsMax) return false;
    _errorMessage = planGuestsFullMessage(count);
    _noticeMessage = null;
    notifyListeners();
    return true;
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

/// [savingGuest]: adding or editing a guest, where a conflict (409) means
/// the guest is already on the list. Elsewhere (removing, reading, groups) a
class _GuestsBundle {
  const _GuestsBundle(this.guests, this.groups, [this.summary]);

  final List<Guest> guests;
  final List<GuestGroup> groups;
  final GuestSummary? summary;
}

/// conflict means something else and keeps the server's own words.
String _guestErrorMessage(ApiException error, {bool savingGuest = false}) {
  final normalized = error.message.trim();
  if ((savingGuest && error.statusCode == 409) ||
      normalized.contains('هذا الضيف مضاف') ||
      normalized.contains('Guest already exists') ||
      normalized.contains('duplicate')) {
    // The server knows a guest twice by the number (RA-MO-61: «هذا الضيف
    // مضاف مسبقًا» was formal and a man for the bride's guests).
    return 'الرقم هذا مضاف في القائمة من قبل';
  }
  if (normalized.contains('valid Yemeni phone') ||
      normalized.contains('phone must')) {
    return 'رقم الجوال غير صحيح';
  }
  return normalized.isEmpty ? 'ما قدرنا نكمل طلب الضيوف.' : normalized;
}
