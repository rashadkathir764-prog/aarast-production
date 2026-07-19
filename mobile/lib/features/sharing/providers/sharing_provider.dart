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
  bool _isLookingUp = false;
  String? _errorMessage;
  String? _accessErrorMessage;
  String? _lookupErrorMessage;
  SharingAuthGateKind? _authGateKind;
  List<SharedMember> _members = const [];
  List<PlanInvite> _invites = const [];
  List<PlanInvite> _myInvites = const [];
  List<SharedWeddingPlan> _sharedPlans = const [];
  PlanAccessPermissions _access = const PlanAccessPermissions.denied(
    weddingPlanId: '',
  );
  SharedMember? _selectedMember;
  SharedUserLookup? _lookupUser;
  PlanInvite? _selectedInvite;
  SharedMember? _acceptedInviteMember;
  final Map<String, Future<PlanInvite?>> _reissueFlights = {};
  int _memberLoadGeneration = 0;
  String? _memberLoadWeddingPlanId;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get isLookingUp => _isLookingUp;
  String? get errorMessage => _errorMessage;
  String? get accessErrorMessage => _accessErrorMessage;
  String? get lookupErrorMessage => _lookupErrorMessage;
  SharingAuthGateKind? get authGateKind => _authGateKind;
  List<SharedMember> get members => _members;
  List<PlanInvite> get invites => _invites;
  List<PlanInvite> get myInvites => _myInvites;
  List<SharedWeddingPlan> get sharedPlans => _sharedPlans;
  PlanAccessPermissions get access => _access;
  SharedMember? get selectedMember => _selectedMember;
  SharedUserLookup? get lookupUser => _lookupUser;
  PlanInvite? get selectedInvite => _selectedInvite;
  SharedMember? get acceptedInviteMember => _acceptedInviteMember;

  PlanInvite? inviteById(String id) {
    for (final invite in _invites) {
      if (invite.id == id) return invite;
    }
    return null;
  }

  Future<void> loadMembers(String weddingPlanId) async {
    final generation = ++_memberLoadGeneration;
    _memberLoadWeddingPlanId = weddingPlanId;
    _isLoading = true;
    _errorMessage = null;
    _authGateKind = null;
    _members = const [];
    _invites = const [];
    _selectedMember = null;
    _lookupUser = null;
    notifyListeners();

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
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrentMemberLoad(int generation, String weddingPlanId) {
    return generation == _memberLoadGeneration &&
        weddingPlanId == _memberLoadWeddingPlanId;
  }

  Future<bool> loadAccess(String weddingPlanId) async {
    _accessErrorMessage = null;
    _authGateKind = null;
    _access = PlanAccessPermissions.denied(weddingPlanId: weddingPlanId);
    notifyListeners();
    try {
      _access = await _api.getMyPlanPermissions(weddingPlanId);
      return true;
    } on ApiException catch (error) {
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
      _accessErrorMessage = 'تعذر التحقق من صلاحية إدارة المشاركين.';
      return false;
    } finally {
      notifyListeners();
    }
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

  Future<bool> lookupUserByPhone(String weddingPlanId, String phone) async {
    _isLookingUp = true;
    _lookupErrorMessage = null;
    _lookupUser = null;
    _authGateKind = null;
    notifyListeners();

    try {
      _lookupUser = await _api.lookupUserByPhone(weddingPlanId, phone);
      return true;
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        _handleApiError(error);
        return false;
      }
      _lookupErrorMessage = _sharingErrorMessage(
        error.message,
        fallback: 'الرقم غير مسجل',
      );
      return false;
    } catch (_) {
      _lookupErrorMessage = 'تعذر البحث عن المستخدم. حاول مرة أخرى.';
      return false;
    } finally {
      _isLookingUp = false;
      notifyListeners();
    }
  }

  void clearLookup() {
    _lookupUser = null;
    _lookupErrorMessage = null;
    notifyListeners();
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
      _lookupUser = null;
      _lookupErrorMessage = null;
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
    notifyListeners();
    try {
      _selectedInvite = await _api.getInvite(token);
    } on ApiException catch (error) {
      _errorMessage = _sharingErrorMessage(error.message);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMyInvites({String? token}) async {
    _isLoading = true;
    _errorMessage = null;
    _selectedInvite = null;
    _acceptedInviteMember = null;
    notifyListeners();
    try {
      final cleanToken = token?.trim();
      if (cleanToken != null && cleanToken.isNotEmpty) {
        final invite = await _api.getInvite(cleanToken);
        _myInvites = [invite];
      } else {
        _myInvites = await _api.getMyInvites();
      }
      if (_myInvites.length == 1) {
        _selectedInvite = _myInvites.single;
      }
    } on ApiException catch (error) {
      _errorMessage = _sharingErrorMessage(error.message);
    } catch (_) {
      _errorMessage = 'تعذر تحميل الدعوات المرتبطة بهذا الرقم.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearInviteAccessState() {
    _myInvites = const [];
    _selectedInvite = null;
    _acceptedInviteMember = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> respondToInvite(String token, {required bool accept}) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (accept) {
        final result = await _api.acceptInvite(token);
        _selectedInvite = result.invite;
        _acceptedInviteMember = result.member;
      } else {
        _selectedInvite = await _api.declineInvite(token);
        _acceptedInviteMember = null;
      }
      _myInvites = [
        for (final invite in _myInvites)
          invite.token == token ? _selectedInvite! : invite,
      ];
      return true;
    } on ApiException catch (error) {
      _errorMessage = _sharingErrorMessage(error.message);
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
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
    _lookupErrorMessage = null;
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
      _lookupErrorMessage = null;
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
