import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../data/funding_api.dart';
import '../models/funding_source.dart';

/// The plan owner's funding sources and loan repayments. Each change shows
/// only what the server saved; a failure keeps the list and says why.
class FundingProvider extends ChangeNotifier with SessionScopedNotifier {
  FundingProvider(this._api);

  final FundingApi _api;

  String? _loadedPlanId;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  List<FundingSource> _sources = const [];

  String? get loadedPlanId => _loadedPlanId;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  List<FundingSource> get sources => List.unmodifiable(_sources);

  FundingSource? sourceById(String id) {
    for (final source in _sources) {
      if (source.id == id) return source;
    }
    return null;
  }

  Future<void> load(String weddingPlanId) async {
    if (_loadedPlanId != weddingPlanId) {
      _loadedPlanId = weddingPlanId;
      _sources = const [];
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final sources = await _api.getFundingSources(weddingPlanId);
      if (_loadedPlanId != weddingPlanId) return;
      _sources = sources;
    } on ApiException catch (error) {
      if (_loadedPlanId == weddingPlanId) _errorMessage = error.message;
    } catch (_) {
      if (_loadedPlanId == weddingPlanId) {
        _errorMessage = 'تعذر تحميل مصادر التمويل الآن.';
      }
    } finally {
      if (_loadedPlanId == weddingPlanId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> create({
    required String weddingPlanId,
    required String kind,
    required String sourceName,
    required String amount,
    required String status,
    String? sourcePhone,
    String? note,
    DateTime? expectedAt,
  }) {
    return _save(weddingPlanId, () async {
      final created = await _api.createFundingSource(
        weddingPlanId: weddingPlanId,
        kind: kind,
        sourceName: sourceName,
        amount: amount,
        status: status,
        sourcePhone: sourcePhone,
        note: note,
        expectedAt: expectedAt,
      );
      _sources = [..._sources, created];
    });
  }

  Future<bool> update(
    FundingSource source, {
    required String kind,
    required String sourceName,
    required String amount,
    required String status,
    // The whole field is sent (null clears the day), so every caller says it.
    required DateTime? expectedAt,
    String? sourcePhone,
    String? note,
  }) {
    return _save(source.weddingPlanId, () async {
      _replace(
        await _api.updateFundingSource(
          source,
          kind: kind,
          sourceName: sourceName,
          amount: amount,
          status: status,
          sourcePhone: sourcePhone,
          note: note,
          expectedAt: expectedAt,
        ),
      );
    });
  }

  Future<bool> delete(FundingSource source) {
    return _save(source.weddingPlanId, () async {
      await _api.deleteFundingSource(source);
      _sources = _sources.where((item) => item.id != source.id).toList();
    });
  }

  Future<bool> addRepayment(
    FundingSource loan, {
    required String amount,
    DateTime? dueDate,
  }) {
    return _save(loan.weddingPlanId, () async {
      _replace(await _api.addRepayment(loan, amount: amount, dueDate: dueDate));
    });
  }

  Future<bool> setRepaymentPaid(
    FundingSource loan,
    LoanRepayment repayment, {
    required bool paid,
  }) {
    return _save(loan.weddingPlanId, () async {
      _replace(
        await _api.setRepaymentStatus(
          repayment,
          paid ? RepaymentStatus.paid : RepaymentStatus.planned,
        ),
      );
    });
  }

  Future<bool> deleteRepayment(FundingSource loan, LoanRepayment repayment) {
    return _save(loan.weddingPlanId, () async {
      _replace(await _api.deleteRepayment(repayment));
    });
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> _save(
    String weddingPlanId,
    Future<void> Function() change,
  ) async {
    if (_isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await change();
      return _loadedPlanId == weddingPlanId;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر حفظ التغيير الآن. حاول مرة أخرى.';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void _replace(FundingSource updated) {
    _sources = [
      for (final item in _sources) item.id == updated.id ? updated : item,
    ];
  }
}
