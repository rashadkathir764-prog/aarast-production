import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
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

    try {
      final results = await Future.wait<Object>([
        _api.getSharedMembers(weddingPlanId),
        _api.getPlanInvites(weddingPlanId),
      ]);
      if (!_isCurrentMemberLoad(generation, weddingPlanId)) return;
      _members = results[0] as List<SharedMember>;
      _invites = results[1] as List<PlanInvite>;
    } on ApiException catch (error) {
      if (!_isCurrentMemberLoad(generation, weddingPlanId)) return;
      _handleApiError(error);
    } catch (_) {
      if (!_isCurrentMemberLoad(generation, weddingPlanId)) return;
      _errorMessage = 'تعذر تحميل أعضاء المشاركة.';
    } finally {
      if (_isCurrentMemberLoad(generation, weddingPlanId)) {
        if (!preserveCurrentState) {
          _isLoading = false;
        }
        notifyListeners();
      }
    }
  }

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
          error.message,
          fallback: 'تعذر التحقق من صلاحية إدارة المشاركين.',
        );
      }
      return false;
    } catch (_) {
      if (!_isCurrentAccessLoad(generation, weddingPlanId)) return false;
      _accessErrorMessage = 'تعذر التحقق من صلاحية إدارة المشاركين.';
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
    _authGateKind = null;
    notifyListeners();

    try {
      _sharedPlans = await _api.getSharedWeddingPlans();
    } on ApiException catch (error) {
      _handleApiError(error);
    } catch (_) {
      _errorMessage = 'تعذر تحميل الخطط المشتركة معك.';
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

  Future<bool> createMember({
    required String weddingPlanId,
    String? userId,
    String? phone,
    required String role,
    required bool canViewMoney,
    required bool canManageTasks,
    required bool canManageMoney,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _authGateKind = null;
    notifyListeners();

    try {
      final member = await _api.createSharedMember(
        weddingPlanId: weddingPlanId,
        userId: userId,
        phone: phone,
        role: role,
        canViewMoney: canViewMoney,
        canManageTasks: canManageTasks,
        canManageMoney: canManageMoney,
      );
      _members = [member, ..._members.where((item) => item.id != member.id)];
      _selectedMember = member;
      return true;
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        _handleApiError(error);
        return false;
      }
      _errorMessage = _sharingErrorMessage(
        error.message,
        fallback: 'تعذر إضافة عضو المشاركة. تحقق من رقم الهاتف والصلاحيات.',
      );
      return false;
    } catch (_) {
      _errorMessage = 'تعذر إضافة عضو المشاركة.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
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
      _errorMessage = 'تعذر إرسال دعوة المشاركة.';
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> cancelInvite(PlanInvite invite) async {
    _isSubmitting = true;
    _errorMessage = null;
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
      } else {
        _errorMessage = 'تعذر إلغاء الدعوة.';
      }
      return false;
    } catch (_) {
      _errorMessage = 'تعذر إلغاء الدعوة.';
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
      _errorMessage = 'تعذر إصدار رابط دعوة جديد.';
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> loadInvite(String token) async {
    _isLoading = true;
    _errorMessage = null;
    _selectedInvite = null;
    notifyListeners();
    try {
      _selectedInvite = await _api.getInvite(token);
    } on ApiException catch (error) {
      _errorMessage = _sharingErrorMessage(error.message);
    } catch (_) {
      _errorMessage = 'تعذر تحميل الدعوة المرتبطة بهذا الرابط.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMyInvites({String? token}) async {
    final generation = ++_myInvitesLoadGeneration;
    _isLoading = true;
    _errorMessage = null;
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
      _errorMessage = _sharingErrorMessage(error.message);
    } catch (_) {
      if (!_isCurrentMyInvitesLoad(generation)) return;
      _errorMessage = 'تعذر تحميل الدعوات المرتبطة بهذا الرقم.';
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
      _errorMessage = _sharingErrorMessage(error.message);
      return false;
    } catch (_) {
      if (await _reconcileInviteResponse(token, accept: accept)) {
        return true;
      }
      _errorMessage = accept
          ? 'تعذر تأكيد قبول الدعوة. تحقق من حالة الدعوة وحاول مرة أخرى.'
          : 'تعذر رفض الدعوة. حاول مرة أخرى.';
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
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _authGateKind = null;
    notifyListeners();

    try {
      // Send the complete permission snapshot so editing one permission never
      // silently resets another.
      final member = await _api.updateSharedMember(weddingPlanId, id, {
        'role': role,
        'canViewMoney': permissions.canViewMoney,
        'canEditPlan': permissions.canEditPlan,
        'canManageTasks': permissions.canManageTasks,
        'canManageGuests': permissions.canManageGuests,
        'canManageProviders': permissions.canManageProviders,
        'canInviteMembers': permissions.canInviteMembers,
        'canManageMoney': permissions.canManageMoney,
        'receiveNotifications': permissions.receiveNotifications,
      });
      _members = [
        for (final item in _members) item.id == member.id ? member : item,
      ];
      _selectedMember = member;
      return true;
    } on ApiException catch (error) {
      _handleApiError(error);
      return false;
    } catch (_) {
      _errorMessage = 'تعذر تحديث صلاحيات العضو.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> removeMember(String weddingPlanId, String id) async {
    _isSubmitting = true;
    _errorMessage = null;
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
      _errorMessage = 'تعذر إزالة عضو المشاركة.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
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
      return;
    }
    _authGateKind = null;
    if (error.serverCode == 'INVITE_REISSUE_COOLDOWN') {
      final retryAfterSeconds = error.retryAfterSeconds;
      _errorMessage = retryAfterSeconds == null
          ? 'تمت محاولة إرسال الدعوة مؤخرًا. انتظر قليلًا ثم أعد المحاولة.'
          : 'تمت محاولة إرسال الدعوة مؤخرًا. أعد المحاولة بعد '
                '$retryAfterSeconds ثانية.';
      return;
    }
    _errorMessage = _sharingErrorMessage(error.message);
  }
}

String _sharingErrorMessage(
  String message, {
  String fallback = 'تعذر تنفيذ طلب المشاركة. تحقق من البيانات والصلاحيات.',
}) {
  final normalized = message.trim();
  if (normalized.contains('User is already shared on this wedding plan')) {
    return 'هذا العضو مضاف مسبقاً إلى هذه الخطة';
  }
  if (normalized.contains('No registered user found for this phone')) {
    return 'الرقم غير مسجل';
  }
  if (normalized.contains('User not found for phone')) {
    return 'الرقم غير مسجل';
  }
  if (normalized.contains('A pending invitation already exists')) {
    return 'توجد دعوة معلقة لهذا الرقم.';
  }

  return switch (normalized) {
    'User is already shared on this wedding plan' =>
      'هذا العضو مضاف مسبقاً إلى هذه الخطة',
    'No registered user found for this phone' => 'الرقم غير مسجل',
    'User not found for phone' => 'الرقم غير مسجل',
    'A pending invitation already exists for this participant' =>
      'توجد دعوة معلقة لهذا الرقم.',
    'Provide either userId or phone, not both' =>
      'أدخل رقم الهاتف فقط ولا ترسل معرف المستخدم معه.',
    'Provide either userId or phone' => 'رقم هاتف العضو مطلوب.',
    'Owner cannot be added as a shared member' =>
      'لا يمكن إضافة صاحب الخطة كعضو مشاركة.',
    'userId must reference an existing user' =>
      'لا يوجد مستخدم مسجل بهذا المعرف.',
    'Shared member not found' => 'لم يتم العثور على عضو المشاركة.',
    _ when normalized.contains('not found') => fallback,
    _ when normalized.contains('must') => fallback,
    _ when normalized.contains('Bad Request') => fallback,
    _ => normalized.isEmpty ? fallback : normalized,
  };
}
