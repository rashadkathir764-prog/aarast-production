import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cached_first_load.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../data/sharing_api.dart';
import '../models/plan_access_permissions.dart';
import '../models/plan_role_permissions.dart';
import '../models/shared_member.dart';
import '../models/shared_wedding_plan.dart';

enum SharingAuthGateKind { sessionExpired }

class SharingProvider extends ChangeNotifier with SessionScopedNotifier {
  SharingProvider(this._api);

  final SharingApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _errorCode;
  String? _accessErrorMessage;
  SharingAuthGateKind? _authGateKind;
  List<SharedMember> _members = const [];
  List<PlanInvite> _invites = const [];
  List<PlanInvite> _myInvites = const [];
  List<SharedWeddingPlan> _sharedPlans = const [];
  PlanAccessPermissions _access = const PlanAccessPermissions.denied(
    weddingPlanId: '',
  );
  SharedMember? _selectedMember;
  PlanInvite? _selectedInvite;
  SharedMember? _acceptedInviteMember;
  String? _acceptedInviteContextKey;
  final Map<String, Future<PlanInvite?>> _reissueFlights = {};
  final Map<String, ({bool accept, Future<bool> future})>
  _inviteResponseFlights = {};
  int _memberLoadGeneration = 0;
  String? _memberLoadWeddingPlanId;
  int _accessLoadGeneration = 0;
  String? _accessLoadWeddingPlanId;
  int _myInvitesLoadGeneration = 0;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  /// The server's stable code behind [errorMessage] («PLAN_ARCHIVED_READ_ONLY»),
  /// so a screen can offer the right way on; null when there is none.
  String? get errorCode => _errorCode;
  String? get accessErrorMessage => _accessErrorMessage;
  SharingAuthGateKind? get authGateKind => _authGateKind;
  List<SharedMember> get members => _members;
  List<PlanInvite> get invites => _invites;
  List<PlanInvite> get myInvites => _myInvites;
  List<SharedWeddingPlan> get sharedPlans => _sharedPlans;
  PlanAccessPermissions get access => _access;
  SharedMember? get selectedMember => _selectedMember;
  PlanInvite? get selectedInvite => _selectedInvite;
  SharedMember? get acceptedInviteMember => _acceptedInviteMember;
  String? get acceptedInviteContextKey => _acceptedInviteContextKey;

  PlanInvite? inviteById(String id) {
    for (final invite in _invites) {
      if (invite.id == id) return invite;
    }
    return null;
  }

  Future<void> loadMembers(
    String weddingPlanId, {
    bool preserveCurrentState = false,
  }) async {
    final generation = ++_memberLoadGeneration;
    _memberLoadWeddingPlanId = weddingPlanId;
    _errorMessage = null;
    _errorCode = null;
    _authGateKind = null;
    if (preserveCurrentState) {
      _isLoading = false;
    } else {
      _isLoading = true;
      _members = const [];
      _invites = const [];
      _selectedMember = null;
      notifyListeners();
    }

    // D85: the phone's copy shows at once; the server's answer replaces it.
    await readCachedFirst<_MembersBundle>(
      cached: () async {
        final members = await _api.cachedSharedMembers(weddingPlanId);
        if (members.isEmpty) return null;
        return _MembersBundle(
          members,
          await _api.cachedPlanInvites(weddingPlanId) ?? const [],
        );
      },
      remote: () async {
        final results = await Future.wait<Object>([
          _api.getSharedMembers(weddingPlanId),
          // RA-MO-194: the invites are for who may invite; the server
          // answers anyone else 403 or 404. That answer failed the whole
          // read, so a helper got no participants at all, and with them no
          // names on tasks. The participants stand without the invites.
          _api
              .getPlanInvites(weddingPlanId)
              .onError<ApiException>(
                (error, _) => error.statusCode == 403 || error.statusCode == 404
                    ? const <PlanInvite>[]
                    : throw error,
              ),
        ]);
        return _MembersBundle(
          results[0] as List<SharedMember>,
          results[1] as List<PlanInvite>,
        );
      },
      apply: (bundle) {
        if (!_isCurrentMemberLoad(generation, weddingPlanId)) return;
        _members = bundle.members;
        _invites = bundle.invites;
      },
      state: ({required loading, required stale, error}) {
        if (!_isCurrentMemberLoad(generation, weddingPlanId)) return;
        if (!preserveCurrentState) _isLoading = loading;
        _isStale = stale;
        if (error != null) _errorMessage = error;
        notifyListeners();
      },
      describe: (error) {
        if (error is ApiException) {
          _handleApiError(error);
          return _errorMessage ?? 'ما قدرنا نجيب المشاركين.';
        }
        return 'ما قدرنا نجيب المشاركين.';
      },
    );
  }

  /// D85: the copy stays because the server did not answer.
  bool _isStale = false;
  bool get isStale => _isStale;

  bool _isCurrentMemberLoad(int generation, String weddingPlanId) {
    return generation == _memberLoadGeneration &&
        weddingPlanId == _memberLoadWeddingPlanId;
  }

  Future<bool> loadAccess(
    String weddingPlanId, {
    bool preserveCurrentState = false,
  }) async {
    final generation = ++_accessLoadGeneration;
    _accessLoadWeddingPlanId = weddingPlanId;
    _accessErrorMessage = null;
    _authGateKind = null;
    if (!preserveCurrentState) {
      _access = PlanAccessPermissions.denied(weddingPlanId: weddingPlanId);
      notifyListeners();
    }
    try {
      final access = await _api.getMyPlanPermissions(weddingPlanId);
      if (!_isCurrentAccessLoad(generation, weddingPlanId)) return false;
      _access = access;
      return true;
    } on ApiException catch (error) {
      if (!_isCurrentAccessLoad(generation, weddingPlanId)) return false;
      if (error.isUnauthorized) {
        _handleApiError(error);
      } else {
        _accessErrorMessage = _sharingErrorMessage(
          error,
          fallback: _accessCheckFailed,
        );
      }
      return false;
    } catch (_) {
      if (!_isCurrentAccessLoad(generation, weddingPlanId)) return false;
      _accessErrorMessage = _accessCheckFailed;
      return false;
    } finally {
      if (_isCurrentAccessLoad(generation, weddingPlanId)) {
        notifyListeners();
      }
    }
  }

  bool _isCurrentAccessLoad(int generation, String weddingPlanId) {
    return generation == _accessLoadGeneration &&
        weddingPlanId == _accessLoadWeddingPlanId;
  }

  Future<void> loadSharedPlans() async {
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    _authGateKind = null;
    notifyListeners();

    try {
      _sharedPlans = await _api.getSharedWeddingPlans();
    } on ApiException catch (error) {
      _handleApiError(error);
    } catch (_) {
      _errorMessage = 'ما قدرنا نجيب الخطط المشتركة.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectMember(SharedMember member) {
    _selectedMember = member;
    notifyListeners();
  }

  SharedMember? findMember(String id) {
    return _findMember(id);
  }

  Future<PlanInvite?> createInvite({
    required String weddingPlanId,
    required String phone,
    String? name,
    required String role,
    required bool canViewMoney,
    required bool canEditPlan,
    required bool canManageTasks,
    required bool canManageGuests,
    required bool canManageProviders,
    required bool canInviteMembers,
    required bool canManageMoney,
    required bool receiveNotifications,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _errorCode = null;
    _authGateKind = null;
    notifyListeners();
    try {
      final invite = await _api.createPlanInvite(
        weddingPlanId: weddingPlanId,
        phone: phone,
        name: name,
        role: role,
        canViewMoney: canViewMoney,
        canEditPlan: canEditPlan,
        canManageTasks: canManageTasks,
        canManageGuests: canManageGuests,
        canManageProviders: canManageProviders,
        canInviteMembers: canInviteMembers,
        canManageMoney: canManageMoney,
        receiveNotifications: receiveNotifications,
      );
      _invites = [
        invite.withIdentityToken(),
        ..._invites.where((item) => item.id != invite.id),
      ];
      return invite;
    } on ApiException catch (error) {
      _handleApiError(error);
      return null;
    } catch (_) {
      _errorMessage = 'ما قدرنا نرسل الدعوة.';
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> cancelInvite(PlanInvite invite) async {
    _isSubmitting = true;
    _errorMessage = null;
    _errorCode = null;
    _authGateKind = null;
    notifyListeners();
    try {
      await _api.cancelPlanInvite(
        weddingPlanId: invite.weddingPlanId,
        inviteId: invite.id,
      );
      _invites = _invites.where((item) => item.id != invite.id).toList();
      return true;
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        _handleApiError(error);
      } else if (error.statusCode == 409) {
        // RA-MO-271: the invite stopped waiting a moment ago (accepted,
        // declined, or cancelled from another phone). «ما قدرنا نلغي
        // الدعوة» gave no reason and left the row under «ينتظرون». The
        // list is read again, so an accepted invitee shows as a
        // participant, who is taken off from their own page.
        _invites = _invites.where((item) => item.id != invite.id).toList();
        // The read clears the message as it starts, so the reason is
        // written after it.
        unawaited(
          loadMembers(invite.weddingPlanId, preserveCurrentState: true),
        );
        _errorMessage =
            'الدعوة ما عادت تنتظر: انقبلت أو انردّت قبل شوي. حدّثنا القائمة.';
        _errorCode = error.serverCode;
      } else {
        // The measured reason when the server was not reached.
        _errorMessage = error.isNetworkFailure
            ? error.message
            : 'ما قدرنا نلغي الدعوة.';
        _errorCode = error.serverCode;
      }
      return false;
    } catch (_) {
      _errorMessage = 'ما قدرنا نلغي الدعوة.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<PlanInvite?> reissueInvite(
    PlanInvite invite, {
    String? role,
    PlanRolePermissions? permissions,
  }) async {
    final active = _reissueFlights[invite.id];
    if (active != null) return active;
    final future = _performReissueInvite(
      invite,
      role: role,
      permissions: permissions,
    );
    _reissueFlights[invite.id] = future;
    try {
      return await future;
    } finally {
      if (identical(_reissueFlights[invite.id], future)) {
        _reissueFlights.remove(invite.id);
      }
    }
  }

  Future<PlanInvite?> _performReissueInvite(
    PlanInvite invite, {
    String? role,
    PlanRolePermissions? permissions,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _errorCode = null;
    _authGateKind = null;
    notifyListeners();
    try {
      final reissued = await _api.reissuePlanInvite(
        weddingPlanId: invite.weddingPlanId,
        inviteId: invite.id,
        role: role,
        canViewMoney: permissions?.canViewMoney,
        canEditPlan: permissions?.canEditPlan,
        canManageTasks: permissions?.canManageTasks,
        canManageGuests: permissions?.canManageGuests,
        canManageProviders: permissions?.canManageProviders,
        canInviteMembers: permissions?.canInviteMembers,
        canManageMoney: permissions?.canManageMoney,
        receiveNotifications: permissions?.receiveNotifications,
      );
      _invites = [
        for (final item in _invites)
          item.id == reissued.id ? reissued.withIdentityToken() : item,
      ];
      return reissued;
    } on ApiException catch (error) {
      final retryAfterSeconds = error.retryAfterSeconds;
      if (error.serverCode == 'INVITE_REISSUE_COOLDOWN' &&
          retryAfterSeconds != null) {
        final availableAt = DateTime.now().add(
          Duration(seconds: retryAfterSeconds),
        );
        _invites = [
          for (final item in _invites)
            item.id == invite.id
                ? item.withDeliveryRetryAvailableAt(availableAt)
                : item,
        ];
      }
      _handleApiError(error);
      return null;
    } catch (_) {
      _errorMessage = 'ما قدرنا نطلّع رابط جديد.';
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> loadInvite(String token) async {
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    _selectedInvite = null;
    notifyListeners();
    try {
      _selectedInvite = await _api.getInvite(token);
    } on ApiException catch (error) {
      _errorMessage = _sharingErrorMessage(error);
      _errorCode = error.serverCode;
    } catch (_) {
      _errorMessage = 'ما قدرنا نجيب الدعوة.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMyInvites({String? token}) async {
    final generation = ++_myInvitesLoadGeneration;
    _isLoading = true;
    _errorMessage = null;
    _errorCode = null;
    _selectedInvite = null;
    _acceptedInviteMember = null;
    _acceptedInviteContextKey = null;
    notifyListeners();
    try {
      final cleanToken = token?.trim();
      final List<PlanInvite> nextInvites;
      if (cleanToken != null && cleanToken.isNotEmpty) {
        final invite = await _api.getInvite(cleanToken);
        nextInvites = [invite];
      } else {
        nextInvites = await _api.getMyInvites();
      }
      if (!_isCurrentMyInvitesLoad(generation)) return;
      _myInvites = nextInvites;
      if (nextInvites.length == 1) {
        _selectedInvite = nextInvites.single;
      }
    } on ApiException catch (error) {
      if (!_isCurrentMyInvitesLoad(generation)) return;
      _errorMessage = _sharingErrorMessage(error);
      _errorCode = error.serverCode;
    } catch (_) {
      if (!_isCurrentMyInvitesLoad(generation)) return;
      _errorMessage = 'ما قدرنا نجيب الدعوة.';
    } finally {
      if (_isCurrentMyInvitesLoad(generation)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrentMyInvitesLoad(int generation) {
    return generation == _myInvitesLoadGeneration;
  }

  void clearInviteAccessState() {
    _myInvitesLoadGeneration += 1;
    _isLoading = false;
    _myInvites = const [];
    _selectedInvite = null;
    _acceptedInviteMember = null;
    _acceptedInviteContextKey = null;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();
  }

  Future<bool> respondToInvite(String token, {required bool accept}) async {
    if (accept && _isAcceptedInviteForToken(token)) return true;
    if (!accept && _isDeclinedInviteForToken(token)) return true;

    final active = _inviteResponseFlights[token];
    if (active != null) {
      return active.accept == accept ? active.future : false;
    }
    if (_inviteResponseFlights.isNotEmpty) return false;

    final future = _performInviteResponse(token, accept: accept);
    _inviteResponseFlights[token] = (accept: accept, future: future);
    try {
      return await future;
    } finally {
      if (identical(_inviteResponseFlights[token]?.future, future)) {
        _inviteResponseFlights.remove(token);
      }
    }
  }

  Future<bool> _performInviteResponse(
    String token, {
    required bool accept,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _errorCode = null;
    notifyListeners();
    try {
      if (accept) {
        final result = await _api.acceptInvite(token);
        _applyAcceptedInvite(result, actionToken: token);
      } else {
        _selectedInvite = await _api.declineInvite(token);
        _acceptedInviteMember = null;
        _acceptedInviteContextKey = null;
        _replaceMyInvite(_selectedInvite!, actionToken: token);
      }
      return true;
    } on ApiException catch (error) {
      if ((error.isAmbiguousMutationFailure || error.statusCode == 409) &&
          await _reconcileInviteResponse(token, accept: accept)) {
        return true;
      }
      _errorMessage = _sharingErrorMessage(error);
      _errorCode = error.serverCode;
      return false;
    } catch (_) {
      if (await _reconcileInviteResponse(token, accept: accept)) {
        return true;
      }
      _errorMessage = accept
          ? 'ما تأكدنا إن الدعوة انقبلت.'
          : 'ما قدرنا نرفض الدعوة.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  bool _isAcceptedInviteForToken(String token) {
    final selected = _selectedInvite;
    if (selected == null || !selected.isAccepted) {
      return false;
    }
    final contextKey = _acceptedInviteContextKey ?? selected.contextKey;
    if (contextKey != 'plan:${selected.weddingPlanId}:contributor') {
      return false;
    }
    if (selected.token == token) return true;
    return _myInvites.any(
      (invite) => invite.id == selected.id && invite.token == token,
    );
  }

  bool _isDeclinedInviteForToken(String token) {
    final selected = _selectedInvite;
    if (selected == null || !selected.isDeclined) return false;
    if (selected.token == token) return true;
    return _myInvites.any(
      (invite) => invite.id == selected.id && invite.token == token,
    );
  }

  Future<bool> _reconcileInviteResponse(
    String token, {
    required bool accept,
  }) async {
    try {
      final observed = await _api.getInvite(token);
      if (accept) {
        final contextKey = observed.contextKey;
        if (!observed.isAccepted ||
            contextKey != 'plan:${observed.weddingPlanId}:contributor') {
          return false;
        }
        _selectedInvite = observed;
        _acceptedInviteMember = null;
        _acceptedInviteContextKey = contextKey;
      } else if (observed.isDeclined) {
        _selectedInvite = observed;
        _acceptedInviteMember = null;
        _acceptedInviteContextKey = null;
      } else {
        return false;
      }
      _replaceMyInvite(observed, actionToken: token);
      _errorMessage = null;
      return true;
    } catch (_) {
      return false;
    }
  }

  void _applyAcceptedInvite(
    AcceptedPlanInvite result, {
    required String actionToken,
  }) {
    final acceptedInvite = result.invite.withContextKey(result.contextKey);
    _selectedInvite = acceptedInvite;
    _acceptedInviteMember = result.member;
    _acceptedInviteContextKey = result.contextKey;
    _replaceMyInvite(acceptedInvite, actionToken: actionToken);
  }

  void _replaceMyInvite(PlanInvite updated, {required String actionToken}) {
    _myInvites = [
      for (final invite in _myInvites)
        if (invite.id == updated.id || invite.token == actionToken)
          updated
        else
          invite,
    ];
  }

  Future<bool> updateMember({
    required String weddingPlanId,
    required String id,
    required String role,
    required PlanRolePermissions permissions,
    required SharedMember from,
  }) async {
    // RA-MO-243: a save sends the rights the person changed, against the
    // participant as the page read them ([from]). Every right used to go
    // «so editing one never resets another»; across two phones it did the
    // reverse: a page read before the owner took the money right away gave
    // it back on its next save of anything. A new role is the whole set of
    // levels just chosen, so it goes with every level the page shows; the
    // flags the page does not show go only when a role changed them.
    final before = from.toPermissions();
    final roleChanged = role != from.role;
    const shown = {
      'canViewMoney',
      'canManageMoney',
      'canManageTasks',
      'canManageGuests',
      'canManageProviders',
    };
    final chosen = <String, bool>{
      'canViewMoney': permissions.canViewMoney,
      'canEditPlan': permissions.canEditPlan,
      'canManageTasks': permissions.canManageTasks,
      'canManageGuests': permissions.canManageGuests,
      'canManageProviders': permissions.canManageProviders,
      'canInviteMembers': permissions.canInviteMembers,
      'canManageMoney': permissions.canManageMoney,
      'receiveNotifications': permissions.receiveNotifications,
    };
    final held = <String, bool>{
      'canViewMoney': before.canViewMoney,
      'canEditPlan': before.canEditPlan,
      'canManageTasks': before.canManageTasks,
      'canManageGuests': before.canManageGuests,
      'canManageProviders': before.canManageProviders,
      'canInviteMembers': before.canInviteMembers,
      'canManageMoney': before.canManageMoney,
      'receiveNotifications': before.receiveNotifications,
    };
    final changes = <String, dynamic>{
      if (roleChanged) 'role': role,
      for (final entry in chosen.entries)
        if (entry.value != held[entry.key] ||
            (roleChanged && shown.contains(entry.key)))
          entry.key: entry.value,
    };
    if (changes.isEmpty) return true;

    _isSubmitting = true;
    _errorMessage = null;
    _errorCode = null;
    _authGateKind = null;
    notifyListeners();

    try {
      final member = await _api.updateSharedMember(weddingPlanId, id, changes);
      _members = [
        for (final item in _members) item.id == member.id ? member : item,
      ];
      _selectedMember = member;
      return true;
    } on ApiException catch (error) {
      _handleApiError(error);
      return false;
    } catch (_) {
      _errorMessage = 'ما قدرنا نحفظ اللي يشوفه.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> removeMember(String weddingPlanId, String id) async {
    _isSubmitting = true;
    _errorMessage = null;
    _errorCode = null;
    _authGateKind = null;
    notifyListeners();

    try {
      await _api.deleteSharedMember(weddingPlanId, id);
      _members = _members.where((item) => item.id != id).toList();
      if (_selectedMember?.id == id) {
        _selectedMember = null;
      }
      return true;
    } on ApiException catch (error) {
      _handleApiError(error);
      return false;
    } catch (_) {
      _errorMessage = 'ما قدرنا نشيله من الخطة.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    _errorCode = null;
    _accessErrorMessage = null;
    _authGateKind = null;
    notifyListeners();
  }

  SharedMember? _findMember(String id) {
    for (final member in _members) {
      if (member.id == id) {
        return member;
      }
    }
    return null;
  }

  void _handleApiError(ApiException error) {
    if (error.isUnauthorized) {
      _authGateKind = SharingAuthGateKind.sessionExpired;
      _errorMessage = null;
      _errorCode = null;
      return;
    }
    _authGateKind = null;
    _errorCode = error.serverCode;
    if (error.serverCode == 'INVITE_REISSUE_COOLDOWN') {
      final retryAfterSeconds = error.retryAfterSeconds;
      _errorMessage = retryAfterSeconds == null
          ? 'أرسلنا الدعوة قبل شوي. الرابط الجديد يطلع بعد دقيقة.'
          : 'أرسلنا الدعوة قبل شوي. الرابط الجديد يطلع بعد '
                '$retryAfterSeconds ثانية.';
      return;
    }
    _errorMessage = _sharingErrorMessage(error);
  }

  static const _accessCheckFailed = 'ما قدرنا نتأكد مين يدير المشاركين.';
}

/// J2-11: the network boundary already turns every server answer into
/// Arabic (a stable code into its own sentence, anything else into what
/// happened), so the message is said as it is.
String _sharingErrorMessage(
  ApiException error, {
  String fallback = 'ما قدرنا نكمّل طلب المشاركة.',
}) {
  final message = error.message.trim();
  return message.isEmpty ? fallback : message;
}

class _MembersBundle {
  const _MembersBundle(this.members, this.invites);

  final List<SharedMember> members;
  final List<PlanInvite> invites;
}
