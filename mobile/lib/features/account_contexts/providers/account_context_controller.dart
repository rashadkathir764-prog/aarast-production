import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/context_lifecycle_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_storage.dart';
import '../data/account_contexts_api.dart';
import '../models/account_context.dart';

typedef SetActiveWeddingPlan = Future<void> Function(String planId);
typedef ReadActiveWeddingPlanId = Future<String?> Function();
typedef ResetAccountContextState =
    FutureOr<void> Function(
      AccountContext? previousContext,
      AccountContext? nextContext,
    );

class AccountContextController extends ChangeNotifier {
  AccountContextController({
    required AccountContextsGateway contextsApi,
    required AuthStorage authStorage,
    required SetActiveWeddingPlan setActiveWeddingPlan,
    String? userId,
    ReadActiveWeddingPlanId? readActiveWeddingPlanId,
    ResetAccountContextState? resetContextState,
  }) : _contextsApi = contextsApi,
       _authStorage = authStorage,
       _setActiveWeddingPlan = setActiveWeddingPlan,
       _userId = userId,
       _readActiveWeddingPlanId = readActiveWeddingPlanId,
       _resetContextStateCallback = resetContextState;

  static const _contextChangedNotice = 'تم تحديث المسار المتاح لحماية بياناتك.';
  static const _genericLoadFailure =
      'تعذر تحديث المسارات المتاحة الآن. حاول مرة أخرى.';
  static const _genericSelectionFailure =
      'تعذر فتح المسار المختار. حاول مرة أخرى.';

  final AccountContextsGateway _contextsApi;
  final AuthStorage _authStorage;
  final SetActiveWeddingPlan _setActiveWeddingPlan;
  final String? _userId;
  final ReadActiveWeddingPlanId? _readActiveWeddingPlanId;
  final ResetAccountContextState? _resetContextStateCallback;

  List<AccountContext> _contexts = const [];
  AccountContext? _selectedContext;
  String? _errorMessage;
  String? _noticeMessage;
  bool _hasLoadedContexts = false;
  int _generation = 0;
  int _refreshCount = 0;
  int _selectionCount = 0;
  Future<void> _commitTail = Future<void>.value();
  bool _disposed = false;

  List<AccountContext> get contexts => _contexts;
  List<AccountContext> get availableContexts =>
      _contexts.where((context) => context.isAvailable).toList(growable: false);
  AccountContext? get selectedContext => _selectedContext;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;
  bool get hasLoadedContexts => _hasLoadedContexts;
  bool get needsSelection =>
      _hasLoadedContexts &&
      _selectedContext == null &&
      availableContexts.isNotEmpty;
  bool get selectionRequired => needsSelection;
  bool get isRefreshing => _refreshCount > 0;
  bool get isSelecting => _selectionCount > 0;

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }

  Future<void> refresh({bool allowInitialSingleContext = false}) async {
    final generation = ++_generation;
    final previousContext = _selectedContext;
    ContextLifecycleLogger.event(
      'WORKSPACES_LOAD_STARTED',
      userId: _userId,
      fromContextKey: previousContext?.contextKey,
      source: 'AccountContextController',
      reason: 'refresh_requested',
    );
    final previousKey = previousContext?.contextKey;
    final persistedKey = _authStorage.readAccountContextKey();
    final wasLoaded = _hasLoadedContexts;
    _refreshCount += 1;
    _errorMessage = null;
    _noticeMessage = null;
    _notifyListeners();

    try {
      final freshContexts = await _contextsApi.listContexts();
      if (!_isCurrent(generation)) return;

      final selected = _selectFallback(
        freshContexts,
        currentKey: previousKey,
        persistedKey: persistedKey,
        allowSingleContext:
            allowInitialSingleContext &&
            !wasLoaded &&
            previousKey == null &&
            persistedKey == null,
      );
      ContextLifecycleLogger.event(
        'WORKSPACES_LOADED',
        userId: _userId,
        fromContextKey: previousContext?.contextKey,
        toContextKey: selected?.contextKey,
        source: 'AccountContextController',
        reason: 'refresh_succeeded',
      );
      final persisted = await _enqueueCommit(() async {
        if (!_isCurrent(generation)) return false;

        var stateReset = false;
        if (!_sameContext(previousContext, selected)) {
          await _resetContextState(previousContext, selected);
          stateReset = true;
          if (!_isCurrent(generation)) return false;
          await _authStorage.clearActivePlanId();
        }

        final selectedPlanId = selected?.weddingPlanId;
        if (selected == null || selected.isProvider) {
          if (!stateReset) {
            await _resetContextState(previousContext, selected);
            if (!_isCurrent(generation)) return false;
          }
          await _authStorage.clearActivePlanId();
        } else if (selectedPlanId != null) {
          final serverActivePlanId = await _tryReadActiveWeddingPlanId();
          if (!_isCurrent(generation)) return false;
          if (serverActivePlanId != null &&
              serverActivePlanId != selectedPlanId) {
            await _setActiveWithReconciliation(selectedPlanId);
            if (!_isCurrent(generation)) return false;
          }
          await _saveActivePlanWithReconciliation(selectedPlanId);
        }
        await _persistContext(selected);
        return _isCurrent(generation);
      });
      if (!persisted || !_isCurrent(generation)) return;

      _contexts = List<AccountContext>.unmodifiable(freshContexts);
      _selectedContext = selected;
      _hasLoadedContexts = true;
      if (!_sameContext(previousContext, selected)) {
        ContextLifecycleLogger.event(
          selected == null
              ? 'ACTIVE_CONTEXT_CLEARED'
              : 'ACTIVE_CONTEXT_SELECTED',
          userId: _userId,
          fromContextKey: previousContext?.contextKey,
          toContextKey: selected?.contextKey,
          source: 'AccountContextController.refresh',
          reason: selected == null
              ? 'stored_context_unavailable'
              : 'initial_or_restored_context',
        );
      }
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
    ContextLifecycleLogger.event(
      'ACTIVE_CONTEXT_SELECTION_REQUESTED',
      userId: _userId,
      fromContextKey: _selectedContext?.contextKey,
      toContextKey: contextKey,
      source: 'AccountContextController.select',
      reason: 'explicit_user_or_flow_selection',
    );
    final generation = ++_generation;
    final previousContext = _selectedContext;
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
        final contextChanged = !_sameContext(previousContext, validated);

        final planId = validated.weddingPlanId;
        if (planId != null) {
          await _setActiveWithReconciliation(planId);
          if (!_isCurrent(generation)) return false;
          if (contextChanged) {
            await _resetContextState(previousContext, validated);
            if (!_isCurrent(generation)) return false;
            await _authStorage.clearActivePlanId();
          }
          await _saveActivePlanWithReconciliation(planId);
        } else {
          await _resetContextState(previousContext, validated);
          if (!_isCurrent(generation)) return false;
          await _authStorage.clearActivePlanId();
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
      ContextLifecycleLogger.event(
        'ACTIVE_CONTEXT_SELECTED',
        userId: _userId,
        fromContextKey: previousContext?.contextKey,
        toContextKey: validated.contextKey,
        source: 'AccountContextController.select',
        reason: 'validated_context_committed',
      );
      return true;
    } on ApiException catch (error) {
      if (_isCurrent(generation) && _isContextAuthorityError(error)) {
        final previousContext = _selectedContext;
        await _resetContextState(previousContext, null);
        if (!_isCurrent(generation)) return false;
        _contexts = const [];
        _selectedContext = null;
        _hasLoadedContexts = false;
        ContextLifecycleLogger.event(
          'ACTIVE_CONTEXT_CLEARED',
          userId: _userId,
          fromContextKey: previousContext?.contextKey,
          source: 'AccountContextController.select',
          reason: 'context_authority_revoked',
        );
        await _authStorage.clearAccountContextKey();
        await _authStorage.clearActivePlanId();
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

      final previousContext = _selectedContext;
      final persisted = await _enqueueCommit(() async {
        if (!_isCurrent(generation)) return false;
        if (!_sameContext(previousContext, archived)) {
          await _resetContextState(previousContext, archived);
          if (!_isCurrent(generation)) return false;
        }
        await _authStorage.clearActivePlanId();
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

  /// Leaves the current workspace and invalidates all context-bound work.
  ///
  /// Account credentials and the authenticated user are intentionally left
  /// untouched. The caller must navigate to the context selection screen.
  Future<void> exitWorkspace() async {
    final previousContext = _selectedContext;
    ContextLifecycleLogger.event(
      'EXIT_WORKSPACE',
      userId: _userId,
      fromContextKey: previousContext?.contextKey,
      source: 'AccountContextController.exitWorkspace',
      reason: 'explicit_workspace_exit',
    );
    await _clearContext(previousContext, reason: 'workspace_exit');
  }

  /// Context cleanup used by the full account logout flow.
  ///
  /// Authentication teardown remains owned by [AuthController]; this method
  /// is deliberately separate from [exitWorkspace] at the call site.
  Future<void> clearForLogout() async {
    final previousContext = _selectedContext;
    ContextLifecycleLogger.event(
      'LOGOUT_ACCOUNT',
      userId: _userId,
      fromContextKey: previousContext?.contextKey,
      source: 'AccountContextController.clearForLogout',
      reason: 'account_logout_context_cleanup',
    );
    await _clearContext(previousContext, reason: 'account_logout');
  }

  Future<void> _clearContext(
    AccountContext? previousContext, {
    required String reason,
  }) async {
    ++_generation;
    _contexts = const [];
    _selectedContext = null;
    _hasLoadedContexts = false;
    _errorMessage = null;
    _noticeMessage = null;
    _notifyListeners();
    ContextLifecycleLogger.event(
      'ACTIVE_CONTEXT_CLEARED',
      userId: _userId,
      fromContextKey: previousContext?.contextKey,
      source: 'AccountContextController',
      reason: reason,
    );
    await _enqueueCommit(() async {
      await _resetContextState(previousContext, null);
      await _authStorage.clearAccountContextKey();
      await _authStorage.clearActivePlanId();
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
    Future<void> run() async {
      try {
        completer.complete(await commit());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }

    _commitTail = _commitTail.then<void>(
      (_) => run(),
      onError: (_, _) => run(),
    );
    return completer.future;
  }

  Future<void> _resetContextState(
    AccountContext? previousContext,
    AccountContext? nextContext,
  ) async {
    final resetter = _resetContextStateCallback;
    if (resetter != null) {
      await resetter(previousContext, nextContext);
    }
  }

  bool _sameContext(AccountContext? first, AccountContext? second) {
    final firstKey = first?.contextKey;
    return firstKey != null && firstKey == second?.contextKey;
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
    required bool allowSingleContext,
  }) {
    AccountContext? byKey(String? key) {
      if (key == null) return null;
      return _firstOrNull(
        availableContexts,
        (context) => context.isAvailable && context.contextKey == key,
      );
    }

    final retained = byKey(currentKey) ?? byKey(persistedKey);
    if (retained != null) return retained;

    final selectable = availableContexts
        .where((context) => context.isAvailable)
        .toList(growable: false);
    return allowSingleContext && selectable.length == 1
        ? selectable.single
        : null;
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
