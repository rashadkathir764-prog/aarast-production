import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../data/sharing_api.dart';
import '../models/shared_member.dart';
import '../models/shared_wedding_plan.dart';

class SharingProvider extends ChangeNotifier {
  SharingProvider(this._api);

  final SharingApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<SharedMember> _members = const [];
  List<SharedWeddingPlan> _sharedPlans = const [];
  SharedMember? _selectedMember;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  List<SharedMember> get members => _members;
  List<SharedWeddingPlan> get sharedPlans => _sharedPlans;
  SharedMember? get selectedMember => _selectedMember;

  Future<void> loadMembers(String weddingPlanId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _members = await _api.getSharedMembers(weddingPlanId);
      if (_selectedMember != null) {
        _selectedMember = _findMember(_selectedMember!.id);
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'تعذر تحميل أعضاء المشاركة.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSharedPlans() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _sharedPlans = await _api.getSharedWeddingPlans();
    } on ApiException catch (error) {
      _errorMessage = error.message;
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
    required String userId,
    required String role,
    required bool canViewBudget,
    required bool canViewExpenses,
    required bool canViewDebts,
    required bool canManageTasks,
    required bool canManageFinancialRecords,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final member = await _api.createSharedMember(
        weddingPlanId: weddingPlanId,
        userId: userId,
        role: role,
        canViewBudget: canViewBudget,
        canViewExpenses: canViewExpenses,
        canViewDebts: canViewDebts,
        canManageTasks: canManageTasks,
        canManageFinancialRecords: canManageFinancialRecords,
      );
      _members = [member, ..._members.where((item) => item.id != member.id)];
      _selectedMember = member;
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر إضافة عضو المشاركة.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateMember({
    required String id,
    required String role,
    required bool canViewBudget,
    required bool canViewExpenses,
    required bool canViewDebts,
    required bool canManageTasks,
    required bool canManageFinancialRecords,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final member = await _api.updateSharedMember(id, {
        'role': role,
        'canViewBudget': canViewBudget,
        'canViewExpenses': canViewExpenses,
        'canViewDebts': canViewDebts,
        'canManageTasks': canManageTasks,
        'canManageFinancialRecords': canManageFinancialRecords,
      });
      _members = [
        for (final item in _members) item.id == member.id ? member : item,
      ];
      _selectedMember = member;
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر تحديث صلاحيات العضو.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> removeMember(String id) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _api.deleteSharedMember(id);
      _members = _members.where((item) => item.id != id).toList();
      if (_selectedMember?.id == id) {
        _selectedMember = null;
      }
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
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
}
