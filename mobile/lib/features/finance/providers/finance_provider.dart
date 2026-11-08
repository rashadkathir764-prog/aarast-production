import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/cached_first_load.dart';
import '../../../core/offline/offline_contract.dart' show OfflineReads;
import '../../../core/preferences/device_preferences.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../../sharing/sharing_api.dart' show PlanAccessPermissions, SharingApi;
import '../data/finance_api.dart';
import '../models/budget_category.dart';
import '../models/money_summary.dart';
import '../models/wedding_cost.dart';

/// What an amount reads as while «أخفِ المبالغ» is on (G17).
const hiddenMoneyText = '••••';

class FinanceProvider extends ChangeNotifier with SessionScopedNotifier {
  FinanceProvider(
    this._api, {
    SharingApi? permissionsApi,
    DevicePreferences? preferences,
  }) : _permissionsApi = permissionsApi,
       _preferences = preferences {
    _preferences?.addListener(notifyListeners);
  }

  /// «أخفِ المبالغ» (g02) lives on the phone and outlasts this plan.
  final DevicePreferences? _preferences;

  static const savedButStaleMessage =
      'انحفظ، بس ما قدرنا نحدّث شاشة المال الحين. اسحب للتحديث.';

  final FinanceApi _api;
  final SharingApi? _permissionsApi;

  bool _isLoading = false;

  /// Saves still running. Counted on their own, never by the reads'
  /// generation, so a read cannot strand or cut short a save (J1-08).
  int _activeSubmits = 0;
  bool _hasLoadedMoney = false;

  /// The last save that failed. Read right after the save.
  String? _errorMessage;

  /// Money could not be read (or the access to it was lost), so what shows
  /// may be old or missing. Only a read sets it; the next good read clears it.
  String? _loadErrorMessage;
  String? _noticeMessage;
  List<BudgetCategory> _categories = const [];
  List<WeddingCost> _costs = const [];
  List<CostPayment> _payments = const [];
  List<PaymentSchedule> _dueSchedules = const [];
  final Map<String, List<CostPayment>> _paymentsByCost = {};
  final Map<String, List<PaymentSchedule>> _schedulesByCost = {};
  int _costsPage = 1;
  int _costsTotalPages = 1;
  int _paymentsPage = 1;
  int _paymentsTotalPages = 1;
  bool _isLoadingMoreCosts = false;
  bool _isLoadingMorePayments = false;
  bool _amountsHidden = false;
  MoneySummary _summary = MoneySummary.empty('');
  PlanAccessPermissions _access = const PlanAccessPermissions.denied(
    weddingPlanId: '',
  );
  String? _loadedPlanId;
  int _loadGeneration = 0;
  int _costRequestGeneration = 0;
  int _paymentRequestGeneration = 0;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _activeSubmits > 0;
  bool get hasLoadedMoney => _hasLoadedMoney;
  String? get errorMessage => _errorMessage;
  String? get loadErrorMessage => _loadErrorMessage;
  String? get noticeMessage => _noticeMessage;

  /// The message to confirm a successful save: [success], unless the save
  /// came with a notice (stale view or local-only plan) the user must see.
  String savedMessage(String success) => _noticeMessage ?? success;
  List<BudgetCategory> get categories => List.unmodifiable(_categories);

  /// The wedding budget's items: every item but the groom's mahr, which is
  /// outside the budget (C1) and never sent with it.
  List<BudgetCategory> get budgetItems => List.unmodifiable(_budgetItems);
  List<WeddingCost> get costs => List.unmodifiable(_costs);
  List<CostPayment> get payments => List.unmodifiable(_payments);
  List<PaymentSchedule> get dueSchedules => List.unmodifiable(_dueSchedules);
  MoneySummary get summary => _summary;
  PlanAccessPermissions get access => _access;
  String? get loadedPlanId => _loadedPlanId;
  bool get canViewMoney => _access.canViewMoney;
  bool get canManageMoney => _access.canManageMoney;

  /// The budget and its items are the owner's: the server refuses every other
  /// member, even one who manages agreements and payments.
  bool get canManageBudget => _access.isOwner;
  bool get hasMoreCosts => _costsPage < _costsTotalPages;
  bool get hasMorePayments => _paymentsPage < _paymentsTotalPages;
  bool get isLoadingMoreCosts => _isLoadingMoreCosts;
  bool get isLoadingMorePayments => _isLoadingMorePayments;
  bool get amountsHidden => _preferences?.hideAmounts ?? _amountsHidden;

  /// G17: one rule for every money figure, whichever feature draws it.
  String shownAmount(String text) => amountsHidden ? hiddenMoneyText : text;

  void toggleAmountsVisibility() {
    final preferences = _preferences;
    if (preferences != null) {
      preferences.setHideAmounts(!preferences.hideAmounts);
      return;
    }
    _amountsHidden = !_amountsHidden;
    notifyListeners();
  }

  WeddingCost? costById(String id) {
    for (final cost in _costs) {
      if (cost.id == id) return cost;
    }
    return null;
  }

  BudgetCategory? categoryById(String id) {
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  /// G40: the directory categories «ابحث» on item [itemId] searches, as the
  /// server's money summary lists them; empty when none (no «ابحث»).
  List<String> providerCategoryIdsFor(String itemId) {
    for (final category in _summary.categories) {
      if (category.categoryId == itemId) return category.providerCategoryIds;
    }
    return const [];
  }

  CostPayment? paymentById(String id) {
    for (final payment in _payments) {
      if (payment.id == id) return payment;
    }
    for (final payments in _paymentsByCost.values) {
      for (final payment in payments) {
        if (payment.id == id) return payment;
      }
    }
    return null;
  }

  PaymentSchedule? scheduleById(String id) {
    for (final schedule in _dueSchedules) {
      if (schedule.id == id) return schedule;
    }
    for (final schedules in _schedulesByCost.values) {
      for (final schedule in schedules) {
        if (schedule.id == id) return schedule;
      }
    }
    return null;
  }

  List<CostPayment> paymentsForCost(String costId) =>
      List.unmodifiable(_paymentsByCost[costId] ?? const []);

  List<PaymentSchedule> schedulesForCost(String costId) =>
      List.unmodifiable(_schedulesByCost[costId] ?? const []);

  /// The earliest date still waiting on this agreement.
  PaymentSchedule? nextPendingSchedule(String costId) {
    final pending = [
      for (final schedule in schedulesForCost(costId))
        if (schedule.isPending) schedule,
    ]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return pending.firstOrNull;
  }

  Future<void> loadMoney(
    String planId, {
    bool canViewMoney = true,
    bool canManageMoney = true,
  }) async {
    final generation = ++_loadGeneration;
    if (_loadedPlanId != planId) {
      _loadedPlanId = planId;
      _clear(planId);
    }
    final costRequest = ++_costRequestGeneration;
    final paymentRequest = ++_paymentRequestGeneration;
    _isLoading = true;
    _loadErrorMessage = null;
    notifyListeners();

    // The reader's right to the money is resolved first (it is the phone's
    // copy too when the server is out of reach).
    try {
      final access = await _resolveAccess(
        planId,
        canViewMoney: canViewMoney,
        canManageMoney: canManageMoney,
      );
      if (!_isCurrent(generation)) return;
      _access = access;
      if (!access.canViewMoney) {
        _clear(planId);
        _loadErrorMessage = 'لا تملك صلاحية عرض المال في هذه الخطة.';
        _isLoading = false;
        notifyListeners();
        return;
      }
    } on ApiException catch (error) {
      if (!_isCurrent(generation)) return;
      _clear(planId);
      _loadErrorMessage = _isPrivateAccessFailure(error)
          ? 'لم يعد لديك وصول إلى المال في هذه الخطة.'
          : error.message;
      _isLoading = false;
      notifyListeners();
      return;
    } catch (_) {
      if (!_isCurrent(generation)) return;
      _clear(planId);
      _loadErrorMessage = 'ما قدرنا نجيب المال الحين. جرّب مرة ثانية.';
      _isLoading = false;
      notifyListeners();
      return;
    }

    // D85: the phone's copy of the money shows at once; the server's
    // answer replaces it, and a server out of reach keeps it (stale).
    await readCachedFirst<_MoneyBundle>(
      cached: () async {
        final summary = await _api.cachedMoneySummary(planId);
        if (summary == null) return null;
        return _MoneyBundle(
          summary,
          await _api.cachedCosts(planId),
          await _api.cachedPayments(planId),
          await _api.cachedDueSchedules(planId),
        );
      },
      remote: () async {
        final results = await Future.wait<Object>([
          _api.getMoneySummary(planId),
          _api.getCosts(planId),
          _api.getPlanPayments(planId),
          _api.getDuePaymentSchedules(planId),
        ]);
        return _MoneyBundle(
          results[0] as MoneySummary,
          results[1] as FinancePage<WeddingCost>,
          results[2] as FinancePage<CostPayment>,
          results[3] as List<PaymentSchedule>,
        );
      },
      apply: (bundle) {
        if (!_isCurrent(generation)) return;
        _summary = bundle.summary;
        _categories = _categoriesFromSummary(_summary);
        if (costRequest == _costRequestGeneration) {
          _costs = bundle.costs.items;
          _costsPage = bundle.costs.page;
          _costsTotalPages = bundle.costs.totalPages;
        }
        if (paymentRequest == _paymentRequestGeneration) {
          _payments = bundle.payments.items;
          _paymentsPage = bundle.payments.page;
          _paymentsTotalPages = bundle.payments.totalPages;
        }
        _dueSchedules = bundle.dueSchedules;
        _sortState();
        _hasLoadedMoney = true;
      },
      state: ({required loading, required stale, error}) {
        if (!_isCurrent(generation)) return;
        _isLoading = loading;
        _isStale = stale;
        _loadErrorMessage = error;
        notifyListeners();
      },
      describe: (error) {
        if (error is ApiException) {
          if (_isPrivateAccessFailure(error)) {
            _clear(planId);
            return 'لم يعد لديك وصول إلى المال في هذه الخطة.';
          }
          return error.message;
        }
        return 'ما قدرنا نجيب المال الحين. جرّب مرة ثانية.';
      },
    );
    await _refreshPendingMoney(planId);
    // RA-MO-38: every money screen reads the plan's agreements from here
    // (the items, an item's page, the payment picker, the mahr), so they are
    // all of them, not the first page of 30. A copy served without the
    // server has no next page to ask for.
    while (_isCurrent(generation) &&
        !_isStale &&
        hasMoreCosts &&
        !_isLoadingMoreCosts) {
      final before = _costsPage;
      await loadMoreCosts();
      if (_costsPage == before) break;
    }
  }

  /// D85: the copy stays because the server did not answer.
  bool _isStale = false;
  bool get isStale => _isStale;

  /// D86: money changes of this plan still on the phone (queued or
  /// refused), shown beside the server's numbers, never added to them.
  int _pendingMoneyChanges = 0;
  int get pendingMoneyChanges => _pendingMoneyChanges;

  Future<void> _refreshPendingMoney(String planId) async {
    final count = await _api.pendingMoneyChangeCount(planId);
    if (_loadedPlanId != planId || isSessionDisposed) return;
    if (count != _pendingMoneyChanges) {
      _pendingMoneyChanges = count;
      notifyListeners();
    }
  }

  /// D86 (w20 «مين دفع ايش»): every agreement and payment of the plan, not
  /// the first page only, so a list under a server total is never short.
  Future<void> loadAllCostsAndPayments() async {
    while (hasMoreCosts && !_isLoadingMoreCosts) {
      final before = _costsPage;
      await loadMoreCosts();
      if (_costsPage == before) break;
    }
    while (hasMorePayments && !_isLoadingMorePayments) {
      final before = _paymentsPage;
      await loadMorePayments();
      if (_paymentsPage == before) break;
    }
  }

  Future<void> loadCostDetails(String costId) async {
    final generation = _loadGeneration;
    final planId = _loadedPlanId;
    if (planId == null) return;
    // D87: a read the server did not answer serves the phone's copy without
    // an error; the count of copies served is how it is told (RA-MO-38).
    final served = OfflineReads.copiesServed;
    var cost = costById(costId);
    try {
      if (cost == null) {
        cost = await _api.getCost(costId);
        if (!_isCurrent(generation) ||
            _loadedPlanId != planId ||
            cost.weddingPlanId != planId) {
          return;
        }
        _costs = [cost, ..._costs.where((item) => item.id != cost!.id)];
      }
      // D86: the payments and the dates are read apart; one that the
      // phone has no copy of never hides the other.
      var stale = false;
      try {
        _paymentsByCost[costId] = await _api.getCostPayments(
          costId,
          planId: cost.weddingPlanId,
        );
      } on ApiException catch (error) {
        if (!error.isNetworkFailure) rethrow;
        stale = true;
      }
      try {
        _schedulesByCost[costId] = await _api.getCostSchedules(
          costId,
          planId: cost.weddingPlanId,
        );
      } on ApiException catch (error) {
        if (!error.isNetworkFailure) rethrow;
        stale = true;
        _schedulesByCost[costId] ??= const [];
      }
      if (!_isCurrent(generation) || _loadedPlanId != planId) return;
      if (stale || OfflineReads.copiesServed > served) _isStale = true;
      notifyListeners();
    } on ApiException catch (error) {
      if (!_isCurrent(generation) || _loadedPlanId != planId) return;
      if (_isPrivateAccessFailure(error)) {
        _clear(planId);
        _loadErrorMessage = 'لم يعد لديك وصول إلى المال في هذه الخطة.';
      } else {
        _loadErrorMessage = error.message;
      }
      notifyListeners();
    }
  }

  /// The next page of the plan's agreements, added to the same list
  /// («البنود», c02).
  Future<void> loadMoreCosts() async {
    final planId = _loadedPlanId;
    if (planId == null || !hasMoreCosts || _isLoadingMoreCosts) return;
    final planGeneration = _loadGeneration;
    final requestGeneration = ++_costRequestGeneration;
    _isLoadingMoreCosts = true;
    notifyListeners();
    try {
      final next = await _api.getCosts(planId, page: _costsPage + 1);
      if (!_isCurrent(planGeneration) ||
          _loadedPlanId != planId ||
          requestGeneration != _costRequestGeneration) {
        return;
      }
      _costs = [
        ..._costs,
        for (final item in next.items)
          if (_costs.every((existing) => existing.id != item.id)) item,
      ];
      _costsPage = next.page;
      _costsTotalPages = next.totalPages;
      _sortState();
    } on ApiException catch (error) {
      if (_isCurrent(planGeneration) &&
          _loadedPlanId == planId &&
          requestGeneration == _costRequestGeneration) {
        _loadErrorMessage = error.message;
      }
    } finally {
      if (_isCurrent(planGeneration) &&
          _loadedPlanId == planId &&
          requestGeneration == _costRequestGeneration) {
        _isLoadingMoreCosts = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMorePayments() async {
    final planId = _loadedPlanId;
    if (planId == null || !hasMorePayments || _isLoadingMorePayments) return;
    final planGeneration = _loadGeneration;
    final requestGeneration = ++_paymentRequestGeneration;
    _isLoadingMorePayments = true;
    notifyListeners();
    try {
      final next = await _api.getPlanPayments(planId, page: _paymentsPage + 1);
      if (!_isCurrent(planGeneration) ||
          _loadedPlanId != planId ||
          requestGeneration != _paymentRequestGeneration) {
        return;
      }
      _payments = [
        ..._payments,
        for (final item in next.items)
          if (_payments.every((existing) => existing.id != item.id)) item,
      ];
      _paymentsPage = next.page;
      _paymentsTotalPages = next.totalPages;
      _sortState();
    } on ApiException catch (error) {
      if (_isCurrent(planGeneration) &&
          _loadedPlanId == planId &&
          requestGeneration == _paymentRequestGeneration) {
        _loadErrorMessage = error.message;
      }
    } finally {
      if (_isCurrent(planGeneration) &&
          _loadedPlanId == planId &&
          requestGeneration == _paymentRequestGeneration) {
        _isLoadingMorePayments = false;
        notifyListeners();
      }
    }
  }

  Future<bool> saveBudget({
    required String planId,
    required String? totalBudget,
    required String currency,
    required List<({String? id, String name, String? allocatedAmount})>
    categories,
  }) {
    return _submit(planId, () async {
      await _replaceBudget(
        planId: planId,
        totalBudget: totalBudget,
        currency: currency,
        categories: categories,
      );
    });
  }

  /// a06 (b01's mahr step): records the plan's mahr on the server, then
  /// reads the money again (the groom's agreement is a new item with its
  /// payment and its date; the bride's is in «من وين»).
  Future<bool> recordMahr({
    required String planId,
    required String total,
    required String settled,
    DateTime? remainingDueDate,
  }) {
    return _submit(
      planId,
      () => _api.recordMahr(
        planId,
        total: total,
        settled: settled,
        remainingDueDate: remainingDueDate,
      ),
      refresh: () => _reloadData(planId),
    );
  }

  Future<String?> createCategory({
    required String planId,
    required String name,
    String? allocatedAmount,
  }) async {
    String? createdId;
    final existingIds = _categories.map((category) => category.id).toSet();
    final normalizedName = _normalizeCategoryName(name);
    final saved = await _submit(planId, () async {
      await _replaceBudget(
        planId: planId,
        totalBudget: _summary.budget.total,
        currency: _summary.currency,
        categories: [
          ..._budgetCategoryInputs(_budgetItems),
          (id: null, name: name, allocatedAmount: allocatedAmount),
        ],
      );
      for (final category in _categories) {
        if (!existingIds.contains(category.id) &&
            _normalizeCategoryName(category.name) == normalizedName) {
          createdId = category.id;
          break;
        }
      }
    });
    return saved ? createdId : null;
  }

  Future<bool> updateCategory({
    required BudgetCategory category,
    required String name,
    String? allocatedAmount,
  }) {
    return _submit(category.weddingPlanId, () async {
      await _replaceBudget(
        planId: category.weddingPlanId,
        totalBudget: _summary.budget.total,
        currency: _summary.currency,
        categories: [
          for (final item in _budgetItems)
            (
              id: item.id,
              name: item.id == category.id ? name : item.name,
              allocatedAmount: item.id == category.id
                  ? allocatedAmount
                  : item.allocatedAmount,
            ),
        ],
      );
    });
  }

  /// w10 «بيانات الخطة»: sets the wedding budget (null clears it) and
  /// keeps every item's share. The plan's money must be loaded first.
  Future<bool> setTotalBudget({
    required String planId,
    required String? totalBudget,
  }) {
    return _submit(planId, () async {
      await _replaceBudget(
        planId: planId,
        totalBudget: totalBudget,
        currency: _summary.currency,
        categories: _budgetCategoryInputs(_budgetItems),
      );
    });
  }

  /// w18 «زِد الميزانية»: raises the wedding budget and [category]'s share
  /// by the same [amount], so the other items keep theirs.
  Future<bool> growCategory({
    required BudgetCategory category,
    required num amount,
  }) {
    return _submit(category.weddingPlanId, () async {
      final total = moneyValue(_summary.budget.total) + amount;
      await _replaceBudget(
        planId: category.weddingPlanId,
        totalBudget: '${total.round()}',
        currency: _summary.currency,
        categories: [
          for (final item in _budgetItems)
            (
              id: item.id,
              name: item.name,
              allocatedAmount: item.id == category.id
                  ? '${(moneyValue(item.allocatedAmount) + amount).round()}'
                  : item.allocatedAmount,
            ),
        ],
      );
    });
  }

  Future<bool> deleteCategory(BudgetCategory category) {
    return _submit(category.weddingPlanId, () async {
      if (category.costsCount > 0) {
        throw const ApiException(
          'انقل تكاليف هذا التصنيف أو احذفها قبل حذف التصنيف.',
        );
      }
      await _replaceBudget(
        planId: category.weddingPlanId,
        totalBudget: _summary.budget.total,
        currency: _summary.currency,
        categories: _budgetCategoryInputs(
          _budgetItems.where((item) => item.id != category.id),
        ),
      );
    });
  }

  Future<WeddingCost?> createCost({
    required String planId,
    required String budgetCategoryId,
    required String title,
    required String totalAmount,
    String? initialPaymentAmount,
    String? providerId,
    String? quoteOfferId,
    String? partyName,
    String? partyPhone,
    String? payer,
    String? payerName,
    DateTime? agreementDate,
    String? note,
    bool isPrivate = false,
  }) async {
    WeddingCost? result;
    final ok = await _submit(planId, () async {
      result = await _api.createCost(
        planId: planId,
        budgetCategoryId: budgetCategoryId,
        title: title,
        totalAmount: totalAmount,
        initialPaymentAmount: initialPaymentAmount,
        providerId: providerId,
        quoteOfferId: quoteOfferId,
        partyName: partyName,
        partyPhone: partyPhone,
        payer: payer,
        payerName: payerName,
        agreementDate: agreementDate,
        note: note,
        isPrivate: isPrivate,
      );
    }, refresh: () => _reloadData(planId));
    return ok ? result : null;
  }

  Future<bool> updateCost({
    required WeddingCost cost,
    required String budgetCategoryId,
    required String title,
    required String totalAmount,
    String? providerId,
    String? quoteOfferId,
    String? partyName,
    String? partyPhone,
    String? payer,
    String? payerName,
    DateTime? agreementDate,
    String? note,
    bool shareWithPlan = false,
  }) {
    return _submit(cost.weddingPlanId, () async {
      await _api.updateCost(
        cost: cost,
        budgetCategoryId: budgetCategoryId,
        title: title,
        totalAmount: totalAmount,
        providerId: providerId,
        quoteOfferId: quoteOfferId,
        partyName: partyName,
        partyPhone: partyPhone,
        payer: payer,
        payerName: payerName,
        agreementDate: agreementDate,
        note: note,
        shareWithPlan: shareWithPlan,
      );
    }, refresh: () => _reloadData(cost.weddingPlanId));
  }

  Future<bool> deleteCost(WeddingCost cost) {
    return _submit(
      cost.weddingPlanId,
      () => _api.deleteCost(cost),
      refresh: () => _reloadData(cost.weddingPlanId),
    );
  }

  Future<bool> cancelCost(WeddingCost cost) {
    return _submit(
      cost.weddingPlanId,
      () => _api.cancelCost(cost),
      refresh: () => _reloadData(cost.weddingPlanId),
    );
  }

  Future<void> _reloadCost(WeddingCost cost) async {
    await _reloadData(cost.weddingPlanId);
    await loadCostDetails(cost.id);
  }

  Future<CostPayment?> recordPayment({
    required WeddingCost cost,
    required String amount,
    DateTime? paidAt,
    String? method,
    String? note,
  }) async {
    CostPayment? result;
    final ok = await _submit(cost.weddingPlanId, () async {
      result = await _api.createPayment(
        cost: cost,
        amount: amount,
        paidAt: paidAt,
        method: method,
        note: note,
      );
    }, refresh: () => _reloadCost(cost));
    return ok ? result : null;
  }

  Future<bool> reversePayment({
    required CostPayment payment,
    required WeddingCost cost,
    required String reason,
  }) {
    return _submit(
      cost.weddingPlanId,
      () => _api.reversePayment(payment: payment, cost: cost, reason: reason),
      refresh: () => _reloadCost(cost),
    );
  }

  Future<PaymentSchedule?> createSchedule({
    required WeddingCost cost,
    required String amount,
    required DateTime dueDate,
    String? note,
  }) async {
    PaymentSchedule? result;
    final ok = await _submit(cost.weddingPlanId, () async {
      result = await _api.createSchedule(
        cost: cost,
        amount: amount,
        dueDate: dueDate,
        note: note,
      );
    }, refresh: () => _reloadCost(cost));
    return ok ? result : null;
  }

  Future<bool> updateSchedule({
    required PaymentSchedule schedule,
    required WeddingCost cost,
    required String amount,
    required DateTime dueDate,
    String? note,
  }) {
    return _submit(cost.weddingPlanId, () async {
      await _api.updateSchedule(
        schedule: schedule,
        cost: cost,
        amount: amount,
        dueDate: dueDate,
        note: note,
      );
    }, refresh: () => _reloadCost(cost));
  }

  Future<bool> deleteSchedule({
    required PaymentSchedule schedule,
    required WeddingCost cost,
  }) {
    return _submit(
      cost.weddingPlanId,
      () => _api.deleteSchedule(schedule),
      refresh: () => _reloadCost(cost),
    );
  }

  Future<bool> cancelSchedule({
    required PaymentSchedule schedule,
    required WeddingCost cost,
  }) {
    return _submit(
      cost.weddingPlanId,
      () => _api.cancelSchedule(schedule),
      refresh: () => _reloadCost(cost),
    );
  }

  Future<CostPayment?> paySchedule({
    required PaymentSchedule schedule,
    required WeddingCost cost,
    DateTime? paidAt,
    String? method,
    String? note,
  }) async {
    CostPayment? result;
    final ok = await _submit(cost.weddingPlanId, () async {
      result = await _api.paySchedule(
        schedule: schedule,
        cost: cost,
        paidAt: paidAt,
        method: method,
        note: note,
      );
    }, refresh: () => _reloadCost(cost));
    return ok ? result : null;
  }

  Future<PlanAccessPermissions> _resolveAccess(
    String planId, {
    required bool canViewMoney,
    required bool canManageMoney,
  }) async {
    if (_isLocalPlan(planId)) {
      return PlanAccessPermissions.owner(weddingPlanId: planId);
    }
    final permissionsApi = _permissionsApi;
    if (permissionsApi != null) {
      try {
        return await permissionsApi.getMyPlanPermissions(planId);
      } on ApiException catch (error) {
        if (error.isNetworkFailure &&
            _access.weddingPlanId == planId &&
            _access.isOwner) {
          return _access;
        }
        rethrow;
      }
    }
    return PlanAccessPermissions(
      weddingPlanId: planId,
      isOwner: canManageMoney,
      canViewMoney: canViewMoney || canManageMoney,
      canManageMoney: canManageMoney,
    );
  }

  /// Runs [write], then [refresh]. Only a failed [write] is a failed save: once
  /// the write is confirmed, a failed [refresh] keeps the save and asks the
  /// user to reload, so a retry re-reads instead of writing again.
  ///
  /// J1-08: the answer depends on the write alone. A read of the money that
  /// ran meanwhile (pull to refresh, the screen's own load) changes what is
  /// shown, never whether the server saved; and the busy state is released on
  /// every path, independent of those reads.
  Future<bool> _submit(
    String planId,
    Future<void> Function() write, {
    Future<void> Function()? refresh,
  }) async {
    if (!_access.canManageMoney && !_isLocalPlan(planId)) {
      _errorMessage = 'لا تملك صلاحية إدارة المال في هذه الخطة.';
      notifyListeners();
      return false;
    }
    _errorMessage = null;
    _noticeMessage = null;
    _beginSubmit();
    try {
      try {
        await write();
      } on ApiException catch (error) {
        _errorMessage = error.message;
        return false;
      } catch (_) {
        _errorMessage = 'ما انحفظ التغيير الحين. جرّب مرة ثانية.';
        return false;
      }
      var refreshed = true;
      if (refresh != null) {
        // Only this refresh's read counts, not an older failed one.
        _loadErrorMessage = null;
        try {
          await refresh();
          // The refresh's reads report their failures in _loadErrorMessage.
          refreshed = _loadErrorMessage == null;
        } catch (_) {
          refreshed = false;
        }
      }
      // Another plan (or no session) is on screen now: the save stands, but
      // its notices belong to a view that is gone.
      if (isSessionDisposed || _loadedPlanId != planId) return true;
      if (!refreshed) {
        // The save went through: the notice says the view is old, so the
        // read failure is not shown a second time.
        _loadErrorMessage = null;
        _noticeMessage = savedButStaleMessage;
      } else if (_isLocalPlan(planId)) {
        _noticeMessage = CachePolicy.localPlanningSaveMessage;
      }
      return true;
    } finally {
      _endSubmit();
      unawaited(_refreshPendingMoney(planId));
    }
  }

  /// One save, from its first write to the screen's last step (J1-08):
  /// [isSubmitting] stays on for all of [body], so the button cannot be
  /// pressed again between the agreement and its payment dates. A save asked
  /// for while another one runs is refused (null) and writes nothing.
  Future<T?> saveOnce<T>(Future<T> Function() body) async {
    if (isSubmitting) return null;
    _beginSubmit();
    try {
      return await body();
    } finally {
      _endSubmit();
    }
  }

  void _beginSubmit() {
    _activeSubmits += 1;
    notifyListeners();
  }

  /// Always runs once per [_beginSubmit], whatever was read meanwhile, so the
  /// button never stays spinning.
  void _endSubmit() {
    _activeSubmits -= 1;
    notifyListeners();
  }

  Future<void> _reloadData(String planId) async {
    final generation = _loadGeneration;
    final costRequest = ++_costRequestGeneration;
    final paymentRequest = ++_paymentRequestGeneration;
    final results = await Future.wait<Object>([
      _api.getMoneySummary(planId),
      _api.getCosts(planId),
      _api.getPlanPayments(planId),
      _api.getDuePaymentSchedules(planId),
    ]);
    if (!_isCurrent(generation) || _loadedPlanId != planId) return;
    _summary = results[0] as MoneySummary;
    _categories = _categoriesFromSummary(_summary);
    final costsPage = results[1] as FinancePage<WeddingCost>;
    final paymentsPage = results[2] as FinancePage<CostPayment>;
    if (costRequest == _costRequestGeneration) {
      _costs = costsPage.items;
      _costsPage = costsPage.page;
      _costsTotalPages = costsPage.totalPages;
    }
    if (paymentRequest == _paymentRequestGeneration) {
      _payments = paymentsPage.items;
      _paymentsPage = paymentsPage.page;
      _paymentsTotalPages = paymentsPage.totalPages;
    }
    _dueSchedules = results[3] as List<PaymentSchedule>;
    _sortState();
    _hasLoadedMoney = true;
  }

  Future<void> _replaceBudget({
    required String planId,
    required String? totalBudget,
    required String currency,
    required List<({String? id, String name, String? allocatedAmount})>
    categories,
  }) async {
    // The budget is replaced whole: every item not sent is removed on the
    // server. Built from a plan whose money was never read (a weak network:
    // the read failed and the save went on), it sent no item and the default
    // currency, and the server deleted every item without an agreement.
    if (!_hasLoadedMoney || _loadedPlanId != planId) {
      throw const ApiException(
        'ما قدرنا نقرأ ميزانيتك الحين، فما غيّرناها. تأكد من النت وجرّب مرة ثانية.',
      );
    }
    final result = await _api.replaceMoneyBudget(
      planId: planId,
      totalBudget: totalBudget,
      currency: currency,
      categories: categories,
    );
    if (_loadedPlanId != planId || isSessionDisposed) return;
    _summary = result.summary;
    // The budget's reply lists the budget's items only; the mahr item is
    // outside the budget (C1) and stays as it was.
    _categories = [
      ...result.categories,
      ..._categories.where((category) => category.isMahr),
    ];
  }

  Iterable<BudgetCategory> get _budgetItems =>
      _categories.where((category) => !category.isMahr);

  List<({String? id, String name, String? allocatedAmount})>
  _budgetCategoryInputs(Iterable<BudgetCategory> categories) {
    return [
      for (final category in categories)
        (
          id: category.id,
          name: category.name,
          allocatedAmount: category.allocatedAmount,
        ),
    ];
  }

  List<BudgetCategory> _categoriesFromSummary(MoneySummary summary) {
    return [
      for (final category in summary.categories)
        BudgetCategory(
          id: category.categoryId,
          weddingPlanId: summary.planId,
          name: category.name,
          allocatedAmount: category.allocatedAmount,
          estimatedAmount: category.estimatedAmount,
          confirmedCost: category.confirmedCost,
          paid: category.paid,
          outstanding: category.outstanding,
          remainingAllocation: category.remainingAllocation,
          costsCount: category.costsCount,
          isMahr: category.isMahr,
        ),
    ];
  }

  void _sortState() {
    _costs = [..._costs]
      ..sort((a, b) {
        final left = a.updatedAt ?? a.createdAt ?? DateTime(0);
        final right = b.updatedAt ?? b.createdAt ?? DateTime(0);
        return right.compareTo(left);
      });
    _payments = [..._payments]..sort((a, b) => b.paidAt.compareTo(a.paidAt));
    _dueSchedules = [..._dueSchedules]
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  void clearMessages() {
    _errorMessage = null;
    _loadErrorMessage = null;
    _noticeMessage = null;
    notifyListeners();
  }

  void _clear(String planId) {
    _costRequestGeneration += 1;
    _paymentRequestGeneration += 1;
    _access = PlanAccessPermissions.denied(weddingPlanId: planId);
    _categories = const [];
    _costs = const [];
    _payments = const [];
    _dueSchedules = const [];
    _paymentsByCost.clear();
    _schedulesByCost.clear();
    _costsPage = 1;
    _costsTotalPages = 1;
    _paymentsPage = 1;
    _paymentsTotalPages = 1;
    _isLoadingMoreCosts = false;
    _isLoadingMorePayments = false;
    // A save still running ends on its own (see _endSubmit).
    _hasLoadedMoney = false;
    _summary = MoneySummary.empty(planId);
  }

  bool _isCurrent(int generation) =>
      generation == _loadGeneration && !isSessionDisposed;

  bool _isPrivateAccessFailure(ApiException error) =>
      error.statusCode == 401 ||
      error.statusCode == 403 ||
      error.statusCode == 404;

  bool _isLocalPlan(String planId) =>
      planId == 'local-guest-plan' ||
      planId.startsWith('guest-plan-') ||
      planId.startsWith('local-guest-');

  String _normalizeCategoryName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  @override
  void dispose() {
    _loadGeneration += 1;
    _preferences?.removeListener(notifyListeners);
    super.dispose();
  }
}

/// What one read of the money brings, from the phone or from the server.
class _MoneyBundle {
  const _MoneyBundle(
    this.summary,
    this.costs,
    this.payments,
    this.dueSchedules,
  );

  final MoneySummary summary;
  final FinancePage<WeddingCost> costs;
  final FinancePage<CostPayment> payments;
  final List<PaymentSchedule> dueSchedules;
}
