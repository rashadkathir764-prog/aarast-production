import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_storage.dart';
import '../data/account_contexts_api.dart';
import '../models/account_context.dart';

typedef SetActiveWeddingPlan = Future<void> Function(String planId);
typedef ReadActiveWeddingPlanId = Future<String?> Function();

class AccountContextController extends ChangeNotifier {
  AccountContextController({
    required AccountContextsGateway contextsApi,
    required AuthStorage authStorage,
    required SetActiveWeddingPlan setActiveWeddingPlan,
    ReadActiveWeddingPlanId? readActiveWeddingPlanId,
  }) : _contextsApi = contextsApi,
       _authStorage = authStorage,
       _setActiveWeddingPlan = setActiveWeddingPlan,
       _readActiveWeddingPlanId = readActiveWeddingPlanId;

  static const _contextChangedNotice =
      'تم تحديث مساحة الحساب المتاحة لحماية بياناتك.';
  static const _genericLoadFailure =
      'تعذر تحديث مساحات الحساب الآن. حاول مرة أخرى.';
  static const _genericSelectionFailure =
      'تعذر فتح مساحة الحساب المختارة. حاول مرة أخرى.';

  final AccountContextsGateway _contextsApi;
  final AuthStorage _authStorage;
  final SetActiveWeddingPlan _setActiveWeddingPlan;
  final ReadActiveWeddingPlanId? _readActiveWeddingPlanId;

  List<AccountContext> _contexts = const [];
  AccountContext? _selectedContext;
  String? _errorMessage;
  String? _noticeMessage;
  int _generation = 0;
  int _refreshCount = 0;
  int _selectionCount = 0;
  Future<void> _commitTail = Future<void>.value();
  String? _stableActiveWeddingPlanId;
  bool _disposed = false;

  List<AccountContext> get contexts => _contexts;
  AccountContext? get selectedContext => _selectedContext;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;
  bool get isRefreshing => _refreshCount > 0;
  bool get isSelecting => _selectionCount > 0;

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }

  Future<void> refresh({String? activeWeddingPlanId}) async {
    final generation = ++_generation;
    final previousKey = _selectedContext?.contextKey;
    _refreshCount += 1;
    _errorMessage = null;
    _noticeMessage = null;
    _notifyListeners();

    try {
      final freshContexts = await _contextsApi.listContexts();
      if (!_isCurrent(generation)) return;

      final serverActivePlanId = await _tryReadActiveWeddingPlanId();
      if (!_isCurrent(generation)) return;
      final selected = _selectFallback(
        freshContexts,
        currentKey: previousKey,
        persistedKey: _authStorage.readAccountContextKey(),
        activeWeddingPlanId: activeWeddingPlanId ?? serverActivePlanId,
      );
      final persisted = await _enqueueCommit(() async {
        if (!_isCurrent(generation)) return false;
        final selectedPlanId = selected?.weddingPlanId;
        final activePlanIsKnown =
            _readActiveWeddingPlanId != null || activeWeddingPlanId != null;
        if (selectedPlanId != null &&
            activePlanIsKnown &&
            serverActivePlanId != selectedPlanId) {
          await _setActiveWithReconciliation(selectedPlanId);
          if (!_isCurrent(generation)) return false;
          _stableActiveWeddingPlanId = selectedPlanId;
        } else if (serverActivePlanId != null) {
          _stableActiveWeddingPlanId = serverActivePlanId;
        }
        await _persistContext(selected);
        return _isCurrent(generation);
      });
      if (!persisted || !_isCurrent(generation)) return;

      _contexts = List<AccountContext>.unmodifiable(freshContexts);
      _selectedContext = selected;
      if (previousKey != null &&
          (selected == null || selected.contextKey != previousKey)) {
        _noticeMessage = _contextChangedNotice;
      }
    } on ApiException {
      if (_isCurrent(generation)) {
        _errorMessage = _genericLoadFailure;
      }
    } on Object {
      if (_isCurrent(generation)) {
        _errorMessage = _genericLoadFailure;
      }
    } finally {
      _refreshCount -= 1;
      _notifyListeners();
    }
  }

  Future<bool> select(String contextKey) async {
    final generation = ++_generation;
    _selectionCount += 1;
    _errorMessage = null;
    _noticeMessage = null;
    _notifyListeners();

    try {
      final validated = await _contextsApi.validateContext(contextKey);
      if (!_isCurrent(generation)) return false;
      if (!validated.isAvailable) {
        throw const FormatException('Validated account context is unavailable');
      }

      final committed = await _enqueueCommit(() async {
        if (!_isCurrent(generation)) return false;
        final planId = validated.weddingPlanId;
        if (planId != null) {
          await _setActiveWithReconciliation(planId);
          if (!_isCurrent(generation)) return false;
          await _saveActivePlanWithReconciliation(planId);
          _stableActiveWeddingPlanId = planId;
        } else {
          final observedActivePlanId = await _tryReadActiveWeddingPlanId();
          final stableActivePlanId = _stableActiveWeddingPlanId;
          if (stableActivePlanId != null &&
              observedActivePlanId != null &&
              observedActivePlanId != stableActivePlanId) {
            await _setActiveWithReconciliation(stableActivePlanId);
            if (!_isCurrent(generation)) return false;
            await _saveActivePlanWithReconciliation(stableActivePlanId);
          } else if (stableActivePlanId == null &&
              observedActivePlanId != null) {
            _stableActiveWeddingPlanId = observedActivePlanId;
            await _saveActivePlanWithReconciliation(observedActivePlanId);
          }
        }
        if (!_isCurrent(generation)) return false;
        await _authStorage.saveAccountContextKey(validated.contextKey);
        return _isCurrent(generation);
      });
      if (!committed || !_isCurrent(generation)) return false;

      _contexts = List<AccountContext>.unmodifiable(
        _replaceOrAppend(_contexts, validated),
      );
      _selectedContext = validated;
      return true;
    } on ApiException catch (error) {
      if (_isCurrent(generation) &&
          _isContextAuthorityError(error)) {
        _contexts = const [];
        _selectedContext = null;
        await _authStorage.clearAccountContextKey();
        _notifyListeners();
        await refresh();
        if (!_disposed) {
          _noticeMessage = _contextChangedNotice;
          _notifyListeners();
        }
      } else if (_isCurrent(generation)) {
        _errorMessage = _genericSelectionFailure;
        _notifyListeners();
        if (error.isNetworkFailure || (error.statusCode ?? 0) >= 500) {
          await refresh();
          if (!_disposed) {
            _errorMessage = _genericSelectionFailure;
            _notifyListeners();
          }
        }
      }
      return false;
    } on Object {
      if (_isCurrent(generation)) {
        _errorMessage = _genericSelectionFailure;
      }
      return false;
    } finally {
      _selectionCount -= 1;
      _notifyListeners();
    }
  }

  Future<bool> openReadOnlyContext(String contextKey) async {
    final generation = ++_generation;
    _selectionCount += 1;
    _errorMessage = null;
    _noticeMessage = null;
    _notifyListeners();

    try {
      final archived = _firstOrNull(
        _contexts,
        (context) =>
            context.contextKey == contextKey &&
            context.isPlan &&
            !context.isAvailable &&
            context.lifecycle == 'ARCHIVED' &&
            context.accessMode == AccountContextAccessMode.readOnly &&
            context.permissions.canViewPlan,
      );
      if (archived == null || !_isCurrent(generation)) return false;

      final persisted = await _enqueueCommit(() async {
        if (!_isCurrent(generation)) return false;
        await _authStorage.saveAccountContextKey(archived.contextKey);
        return _isCurrent(generation);
      });
      if (!persisted || !_isCurrent(generation)) return false;

      _selectedContext = archived;
      return true;
    } on Object {
      if (_isCurrent(generation)) {
        _errorMessage = _genericSelectionFailure;
      }
      return false;
    } finally {
      _selectionCount -= 1;
      _notifyListeners();
    }
  }

  Future<void> clearForLogout() async {
    ++_generation;
    _contexts = const [];
    _selectedContext = null;
    _errorMessage = null;
    _noticeMessage = null;
    _notifyListeners();
    await _enqueueCommit(() async {
      await _authStorage.clearAccountContextKey();
      return true;
    });
  }

  void clearMessages() {
    _errorMessage = null;
    _noticeMessage = null;
    _notifyListeners();
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  Future<String?> _tryReadActiveWeddingPlanId() async {
    final reader = _readActiveWeddingPlanId;
    if (reader == null) return null;
    try {
      return await reader();
    } on Object {
      return null;
    }
  }

  Future<void> _setActiveWithReconciliation(String planId) async {
    try {
      await _setActiveWeddingPlan(planId);
    } on ApiException catch (error) {
      if (!error.isAmbiguousMutationFailure) rethrow;
      final observed = await _tryReadActiveWeddingPlanId();
      if (observed == planId) return;
      rethrow;
    }
  }

  Future<void> _saveActivePlanWithReconciliation(String planId) async {
    try {
      await _authStorage.saveActivePlanId(planId);
    } on Object {
      final reader = _readActiveWeddingPlanId;
      if (reader != null) {
        final observed = await _tryReadActiveWeddingPlanId();
        if (observed != planId) rethrow;
      }
      await _authStorage.saveActivePlanId(planId);
    }
  }

  bool _isContextAuthorityError(ApiException error) {
    return (error.statusCode == 409 &&
            error.serverCode == 'CONTEXT_UNAVAILABLE') ||
        (error.statusCode == 404 && error.serverCode == 'CONTEXT_NOT_FOUND');
  }

  Future<bool> _enqueueCommit(Future<bool> Function() commit) {
    final completer = Completer<bool>();
    _commitTail = _commitTail.then((_) async {
      try {
        completer.complete(await commit());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<void> _persistContext(AccountContext? context) async {
    if (context == null) {
      await _authStorage.clearAccountContextKey();
      return;
    }
    await _authStorage.saveAccountContextKey(context.contextKey);
  }

  AccountContext? _selectFallback(
    List<AccountContext> availableContexts, {
    required String? currentKey,
    required String? persistedKey,
    required String? activeWeddingPlanId,
  }) {
    AccountContext? byKey(String? key) {
      if (key == null) return null;
      return _firstOrNull(
        availableContexts,
        (context) => context.isAvailable && context.contextKey == key,
      );
    }

    return byKey(currentKey) ??
        byKey(persistedKey) ??
        _firstOrNull(
          availableContexts,
          (context) =>
              context.isAvailable &&
              context.weddingPlanId == activeWeddingPlanId &&
              activeWeddingPlanId != null,
        ) ??
        _firstOrNull(
          availableContexts,
          (context) =>
              context.isAvailable && context.role == AccountContextRole.owner,
        ) ??
        _firstOrNull(
          availableContexts,
          (context) =>
              context.isAvailable &&
              context.role == AccountContextRole.contributor,
        ) ??
        _firstOrNull(
          availableContexts,
          (context) =>
              context.isAvailable &&
              context.role == AccountContextRole.provider,
        );
  }

  List<AccountContext> _replaceOrAppend(
    List<AccountContext> items,
    AccountContext replacement,
  ) {
    var replaced = false;
    final result = <AccountContext>[
      for (final item in items)
        if (item.contextKey == replacement.contextKey) ...[
          replacement,
        ] else
          item,
    ];
    for (final item in items) {
      if (item.contextKey == replacement.contextKey) {
        replaced = true;
        break;
      }
    }
    if (!replaced) result.add(replacement);
    return result;
  }
}

AccountContext? _firstOrNull(
  Iterable<AccountContext> contexts,
  bool Function(AccountContext context) test,
) {
  for (final context in contexts) {
    if (test(context)) return context;
  }
  return null;
}
