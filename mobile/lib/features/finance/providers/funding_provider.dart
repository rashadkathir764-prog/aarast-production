import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cached_first_load.dart';
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

  /// The last save that failed. Read right after the save.
  String? _errorMessage;

  /// The sources could not be read; the next good read clears it.
  String? _loadErrorMessage;
  List<FundingSource> _sources = const [];

  String? get loadedPlanId => _loadedPlanId;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get loadErrorMessage => _loadErrorMessage;
  List<FundingSource> get sources => List.unmodifiable(_sources);

  FundingSource? sourceById(String id) {
    for (final source in _sources) {
      if (source.id == id) return source;
    }
    return null;
  }

  /// D85: the copy stays because the server did not answer.
  bool _isStale = false;
  bool get isStale => _isStale;

  /// Sources saved for [_loadedPlanId] while its list was being read: the
  /// read was sent before them, so its answer does not hold them (RA-MO-38).
  final List<FundingSource> _savedDuringRead = [];

  /// D85: the phone's copy shows at once; the server's answer replaces it.
  Future<void> load(String weddingPlanId) async {
    if (_loadedPlanId != weddingPlanId) {
      _loadedPlanId = weddingPlanId;
      _sources = const [];
    }
    // What was saved before this read is in its answer.
    _savedDuringRead.clear();
    bool current() => _loadedPlanId == weddingPlanId;
    await readCachedFirst<List<FundingSource>>(
      cached: () async {
        final copy = await _api.cachedFundingSources(weddingPlanId);
        return copy.isEmpty ? null : copy;
      },
      remote: () => _api.getFundingSources(weddingPlanId),
      apply: (sources) {
        if (!current()) return;
        _sources = [
          ...sources,
          for (final saved in _savedDuringRead)
            if (!sources.any((source) => source.id == saved.id)) saved,
        ];
      },
      state: ({required loading, required stale, error}) {
        if (!current()) return;
        _isLoading = loading;
        _isStale = stale;
        _loadErrorMessage = error;
        notifyListeners();
      },
      describe: (error) => error is ApiException
          ? error.message
          : 'ما قدرنا نجيب مصادر الفلوس الحين.',
    );
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
      // Another plan's list (or none yet) is not this one: the next read of
      // this plan brings it.
      if (_loadedPlanId != weddingPlanId) return;
      _sources = [..._sources, created];
      if (_isLoading) _savedDuringRead.add(created);
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
      // RA-MO-38: saved is saved, whichever list the screen shows. The sheet
      // can save before this plan's list was read (the money is read first);
      // «ما قدرنا نحفظ» then made the person save the same source twice.
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'ما انحفظ التغيير الحين. جرّب مرة ثانية.';
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
