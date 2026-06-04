import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../data/debt_installment_api.dart';
import '../models/debt.dart';
import '../models/debt_summary.dart';
import '../models/installment.dart';

class DebtInstallmentProvider extends ChangeNotifier {
  DebtInstallmentProvider(this._api);

  final DebtInstallmentApi _api;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<Debt> _debts = const [];
  List<Installment> _dueInstallments = const [];
  List<Installment> _installments = const [];
  DebtSummary _summary = DebtSummary.empty();
  Debt? _selectedDebt;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  List<Debt> get debts => _debts;
  List<Installment> get dueInstallments => _dueInstallments;
  List<Installment> get installments => _installments;
  DebtSummary get summary => _summary;
  Debt? get selectedDebt => _selectedDebt;

  Future<void> loadDebts(String weddingPlanId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait<Object>([
        _api.getDebts(weddingPlanId),
        _api.getDebtSummary(weddingPlanId),
        _api.getDueInstallments(weddingPlanId),
      ]);
      _debts = results[0] as List<Debt>;
      _summary = results[1] as DebtSummary;
      _dueInstallments = results[2] as List<Installment>;
      if (_selectedDebt != null) {
        _selectedDebt = _findDebt(_selectedDebt!.id);
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'تعذر تحميل الديون والأقساط.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDebtDetails(String debtId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedDebt ??= _findDebt(debtId);
      _installments = await _api.getInstallments(debtId);
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = 'تعذر تحميل تفاصيل الدين.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectDebt(Debt debt) {
    _selectedDebt = debt;
    notifyListeners();
  }

  Future<Debt?> createDebt({
    required String weddingPlanId,
    required String creditorName,
    required String title,
    required String totalAmount,
    String? paidAmount,
    DateTime? dueDate,
    String status = 'OPEN',
    String? note,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final debt = await _api.createDebt(
        weddingPlanId: weddingPlanId,
        creditorName: creditorName,
        title: title,
        totalAmount: totalAmount,
        paidAmount: paidAmount,
        dueDate: dueDate,
        status: status,
        note: note,
      );
      _selectedDebt = debt;
      _debts = [debt, ..._debts.where((item) => item.id != debt.id)];
      _summary = await _api.getDebtSummary(weddingPlanId);
      _dueInstallments = await _api.getDueInstallments(weddingPlanId);
      return debt;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return null;
    } catch (_) {
      _errorMessage = 'تعذر إنشاء الدين.';
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> createInstallment({
    required String debtId,
    required String amount,
    DateTime? dueDate,
    DateTime? paidAt,
    String status = 'PENDING',
    String? note,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final installment = await _api.createInstallment(
        debtId: debtId,
        amount: amount,
        dueDate: dueDate,
        paidAt: paidAt,
        status: status,
        note: note,
      );
      _installments = [
        installment,
        ..._installments.where((item) => item.id != installment.id),
      ];
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر إنشاء القسط.';
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

  Debt? _findDebt(String id) {
    for (final debt in _debts) {
      if (debt.id == id) {
        return debt;
      }
    }
    return null;
  }
}
