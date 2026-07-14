import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../../sharing/data/sharing_api.dart';
import '../../sharing/models/plan_access_permissions.dart';
import '../data/finance_api.dart';
import '../models/budget_category.dart';
import '../models/money_summary.dart';
import '../models/wedding_cost.dart';

class FinanceProvider extends ChangeNotifier with SessionScopedNotifier {
  FinanceProvider(this._api, {SharingApi? permissionsApi})
    : _permissionsApi = permissionsApi;

  final FinanceApi _api;
  final SharingApi? _permissionsApi;

  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _hasLoadedMoney = false;
  String? _errorMessage;
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
  MoneySummary _summary = MoneySummary.empty('');
  PlanAccessPermissions _access = const PlanAccessPermissions.denied(
    weddingPlanId: '',
  );
  String? _loadedPlanId;
  int _loadGeneration = 0;
  int _costRequestGeneration = 0;
  int _paymentRequestGeneration = 0;

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get hasLoadedMoney => _hasLoadedMoney;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;
  List<BudgetCategory> get categories => List.unmodifiable(_categories);
  List<WeddingCost> get costs => List.unmodifiable(_costs);
  List<CostPayment> get payments => List.unmodifiable(_payments);
  List<PaymentSchedule> get dueSchedules => List.unmodifiable(_dueSchedules);
  MoneySummary get summary => _summary;
  PlanAccessPermissions get access => _access;
  String? get loadedPlanId => _loadedPlanId;
  bool get canViewMoney => _access.canViewMoney;
  bool get canManageMoney => _access.canManageMoney;
  bool get hasMoreCosts => _costsPage < _costsTotalPages;
  bool get hasMorePayments => _paymentsPage < _paymentsTotalPages;
  bool get isLoadingMoreCosts => _isLoadingMoreCosts;
  bool get isLoadingMorePayments => _isLoadingMorePayments;

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
    _errorMessage = null;
    notifyListeners();

    var accessResolved = false;
    try {
      final access = await _resolveAccess(
        planId,
        canViewMoney: canViewMoney,
        canManageMoney: canManageMoney,
      );
      if (!_isCurrent(generation)) return;
      accessResolved = true;
      _access = access;
      if (!access.canViewMoney) {
        _clear(planId);
        _errorMessage = 'لا تملك صلاحية عرض المال في هذه الخطة.';
        return;
      }

      final results = await Future.wait<Object>([
        _api.getMoneySummary(planId),
        _api.getCosts(planId),
        _api.getPlanPayments(planId),
        _api.getDuePaymentSchedules(planId),
      ]);
      if (!_isCurrent(generation)) return;
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
    } on ApiException catch (error) {
      if (!_isCurrent(generation)) return;
      if (!accessResolved || _isPrivateAccessFailure(error)) {
        _clear(planId);
      }
      _errorMessage = _isPrivateAccessFailure(error)
          ? 'لم يعد لديك وصول إلى المال في هذه الخطة.'
          : error.message;
    } catch (_) {
      if (!_isCurrent(generation)) return;
      if (!accessResolved) _clear(planId);
      _errorMessage = 'تعذر تحميل المال الآن. حاول مرة أخرى.';
    } finally {
      if (_isCurrent(generation)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadCostDetails(String costId) async {
    final generation = _loadGeneration;
    final planId = _loadedPlanId;
    if (planId == null) return;
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
      final results = await Future.wait([
        _api.getCostPayments(costId, planId: cost.weddingPlanId),
        _api.getCostSchedules(costId, planId: cost.weddingPlanId),
      ]);
      if (!_isCurrent(generation) || _loadedPlanId != planId) return;
      _paymentsByCost[costId] = results[0] as List<CostPayment>;
      _schedulesByCost[costId] = results[1] as List<PaymentSchedule>;
      notifyListeners();
    } on ApiException catch (error) {
      if (!_isCurrent(generation) || _loadedPlanId != planId) return;
      if (_isPrivateAccessFailure(error)) {
        _clear(planId);
        _errorMessage = 'لم يعد لديك وصول إلى المال في هذه الخطة.';
      } else {
        _errorMessage = error.message;
      }
      notifyListeners();
    }
  }

  Future<void> loadMoreCosts({
    String? status,
    String? categoryId,
    String? search,
  }) async {
    final planId = _loadedPlanId;
    if (planId == null || !hasMoreCosts || _isLoadingMoreCosts) return;
    final planGeneration = _loadGeneration;
    final requestGeneration = ++_costRequestGeneration;
    _isLoadingMoreCosts = true;
    notifyListeners();
    try {
      final next = await _api.getCosts(
        planId,
        page: _costsPage + 1,
        status: status,
        categoryId: categoryId,
        search: search,
      );
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
        _errorMessage = error.message;
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

  Future<void> filterCosts({
    String? status,
    String? categoryId,
    String? search,
  }) async {
    final planId = _loadedPlanId;
    if (planId == null) return;
    final planGeneration = _loadGeneration;
    final requestGeneration = ++_costRequestGeneration;
    _isLoadingMoreCosts = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final page = await _api.getCosts(
        planId,
        status: status,
        categoryId: categoryId,
        search: search,
      );
      if (!_isCurrent(planGeneration) ||
          _loadedPlanId != planId ||
          requestGeneration != _costRequestGeneration) {
        return;
      }
      _costs = page.items;
      _costsPage = page.page;
      _costsTotalPages = page.totalPages;
      _sortState();
    } on ApiException catch (error) {
      if (_isCurrent(planGeneration) &&
          _loadedPlanId == planId &&
          requestGeneration == _costRequestGeneration) {
        _errorMessage = error.message;
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
        _errorMessage = error.message;
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
          ..._budgetCategoryInputs(_categories),
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
          for (final item in _categories)
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
          _categories.where((item) => item.id != category.id),
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
    DateTime? agreementDate,
    String? note,
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
        agreementDate: agreementDate,
        note: note,
      );
      await _reloadData(planId);
    });
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
    DateTime? agreementDate,
    String? note,
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
        agreementDate: agreementDate,
        note: note,
      );
      await _reloadData(cost.weddingPlanId);
    });
  }

  Future<bool> deleteCost(WeddingCost cost) {
    return _submit(cost.weddingPlanId, () async {
      await _api.deleteCost(cost);
      await _reloadData(cost.weddingPlanId);
    });
  }

  Future<bool> cancelCost(WeddingCost cost) {
    return _submit(cost.weddingPlanId, () async {
      await _api.cancelCost(cost);
      await _reloadData(cost.weddingPlanId);
    });
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
      await _reloadData(cost.weddingPlanId);
      await loadCostDetails(cost.id);
    });
    return ok ? result : null;
  }

  Future<bool> reversePayment({
    required CostPayment payment,
    required WeddingCost cost,
    required String reason,
  }) {
    return _submit(cost.weddingPlanId, () async {
      await _api.reversePayment(payment: payment, cost: cost, reason: reason);
      await _reloadData(cost.weddingPlanId);
      await loadCostDetails(cost.id);
    });
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
      await _reloadData(cost.weddingPlanId);
      await loadCostDetails(cost.id);
    });
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
      await _reloadData(cost.weddingPlanId);
      await loadCostDetails(cost.id);
    });
  }

  Future<bool> deleteSchedule({
    required PaymentSchedule schedule,
    required WeddingCost cost,
  }) {
    return _submit(cost.weddingPlanId, () async {
      await _api.deleteSchedule(schedule);
      await _reloadData(cost.weddingPlanId);
      await loadCostDetails(cost.id);
    });
  }

  Future<bool> cancelSchedule({
    required PaymentSchedule schedule,
    required WeddingCost cost,
  }) {
    return _submit(cost.weddingPlanId, () async {
      await _api.cancelSchedule(schedule);
      await _reloadData(cost.weddingPlanId);
      await loadCostDetails(cost.id);
    });
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
      await _reloadData(cost.weddingPlanId);
      await loadCostDetails(cost.id);
    });
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

  Future<bool> _submit(String planId, Future<void> Function() action) async {
    if (!_access.canManageMoney && !_isLocalPlan(planId)) {
      _errorMessage = 'لا تملك صلاحية إدارة المال في هذه الخطة.';
      notifyListeners();
      return false;
    }
    _isSubmitting = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();
    final generation = _loadGeneration;
    try {
      await action();
      if (isSessionDisposed ||
          generation != _loadGeneration ||
          _loadedPlanId != planId) {
        return false;
      }
      if (_isLocalPlan(planId)) {
        _noticeMessage = CachePolicy.localPlanningSaveMessage;
      }
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'تعذر حفظ التغيير الآن. حاول مرة أخرى.';
      return false;
    } finally {
      if (!isSessionDisposed &&
          generation == _loadGeneration &&
          _loadedPlanId == planId) {
        _isSubmitting = false;
        notifyListeners();
      }
    }
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
    final result = await _api.replaceMoneyBudget(
      planId: planId,
      totalBudget: totalBudget,
      currency: currency,
      categories: categories,
    );
    if (_loadedPlanId != planId || isSessionDisposed) return;
    _summary = result.summary;
    _categories = result.categories;
  }

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
          confirmedCost: category.confirmedCost,
          paid: category.paid,
          outstanding: category.outstanding,
          remainingAllocation: category.remainingAllocation,
          costsCount: category.costsCount,
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
    _isSubmitting = false;
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
    super.dispose();
  }
}
