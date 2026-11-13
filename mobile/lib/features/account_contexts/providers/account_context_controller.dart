import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/app_logger.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_storage.dart';
import '../data/account_contexts_api.dart';
import '../models/account_context.dart';

typedef SetActiveWeddingPlan = Future<void> Function(String planId);
typedef ReadActiveWeddingPlanId = Future<String?> Function();
typedef BeforeAccountContextsRefresh = Future<Set<String>> Function();
typedef AfterAccountContextsRefresh = Future<void> Function();

/// Removes from the phone a plan the server says this participant no
/// longer has, and says how many unsent changes went with it.
typedef ForgetRemovedPlan = Future<int> Function(String planId);
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
    BeforeAccountContextsRefresh? beforeRefresh,
    AfterAccountContextsRefresh? afterRefresh,
    ForgetRemovedPlan? forgetRemovedPlan,
  }) : _forgetRemovedPlan = forgetRemovedPlan,
       _contextsApi = contextsApi,
       _authStorage = authStorage,
       _setActiveWeddingPlan = setActiveWeddingPlan,
       _userId = userId,
       _readActiveWeddingPlanId = readActiveWeddingPlanId,
       _resetContextStateCallback = resetContextState,
       _beforeRefresh = beforeRefresh,
       _afterRefresh = afterRefresh;

  static const _contextChangedNotice =
      'تغيّر اللي مفتوح لك، وحدّثناه عشان نحمي بياناتك.';
  static const _genericLoadFailure = 'ما قدرنا نفتح حسابك. جرّب مرة ثانية.';
  static const _genericSelectionFailure =
      'ما قدرنا نفتح المسار اللي اخترته. جرّب مرة ثانية.';
  static const _offlineNotice =
      'أنت بدون نت الحين. نعرض آخر نسخة عندك، ونحدّثها لما يرجع النت.';
  static const _offlineLoadFailure =
      'ما وصلنا للخادم. تأكد من النت وجرّب مرة ثانية.';

  final AccountContextsGateway _contextsApi;
  final AuthStorage _authStorage;
  final SetActiveWeddingPlan _setActiveWeddingPlan;
  final String? _userId;
  final ReadActiveWeddingPlanId? _readActiveWeddingPlanId;
  final ResetAccountContextState? _resetContextStateCallback;
  final BeforeAccountContextsRefresh? _beforeRefresh;
  final AfterAccountContextsRefresh? _afterRefresh;
  final ForgetRemovedPlan? _forgetRemovedPlan;

  /// RA-MO-275: unsent changes that went with a plan the participant was
  /// taken off, by plan; the page that tells the removal says them.
  final Map<String, int> _droppedOnRemoval = {};
  int unsentDroppedOnRemoval(String planId) => _droppedOnRemoval[planId] ?? 0;

  List<AccountContext> _contexts = const [];
  AccountContext? _selectedContext;
  AccountContextPermissionChange? _permissionChange;
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

  /// q12: what changed in the open participant path since this phone last
  /// kept it; null when nothing changed. The home takes it once with
  /// [takePermissionChange].
  AccountContextPermissionChange? get permissionChange => _permissionChange;

  /// Hands the change to the one screen that tells it, so it is told once.
  AccountContextPermissionChange? takePermissionChange() {
    final change = _permissionChange;
    _permissionChange = null;
    return change;
  }

  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;
  bool get hasLoadedContexts => _hasLoadedContexts;

  /// Whether the last [refresh] heard the server: offline a participant's
  /// plan stays open on the kept copy with no error (D112), so a page that
  /// asks the server about a plan reads this, not [errorMessage]
  /// (RA-MO-273).
  bool get lastRefreshAnswered => _lastRefreshAnswered;
  bool _lastRefreshAnswered = false;
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
    appLogEvent(
      'WORKSPACES_LOAD_STARTED',
      category: AppLogCategory.context,
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
    _lastRefreshAnswered = false;
    _notifyListeners();

    var blockedPlanIds = const <String>{};
    AccountContextPermissionChange? permissionChange;
    // The plans this phone held as a participant before asking.
    final heldAsParticipant = {
      for (final context in [..._contexts, ?_storedContext()])
        if (context.role == AccountContextRole.contributor)
          ?context.weddingPlanId,
    };
    try {
      final beforeRefresh = _beforeRefresh;
      if (beforeRefresh != null) blockedPlanIds = await beforeRefresh();
      if (!_isCurrent(generation)) return;
      final serverContexts = await _contextsApi.listContexts();
      if (!_isCurrent(generation)) return;
      // A pending leave is a local deny boundary. The API may still return the
      // membership while the original DELETE has an ambiguous network result;
      // never expose or select that plan until the durable replay resolves.
      final freshContexts = blockedPlanIds.isEmpty
          ? serverContexts
          : serverContexts
                .where(
                  (context) =>
                      context.weddingPlanId == null ||
                      !blockedPlanIds.contains(context.weddingPlanId),
                )
                .toList(growable: false);

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
      appLogEvent(
        'WORKSPACES_LOADED',
        category: AppLogCategory.context,
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
        } else if (selected.isOwnerMemory) {
          // D112 (Q-21): a memory is read, never the active plan (the
          // server refuses it as one), so none is asked for or kept. A plan
          // that was live a moment ago starts afresh as a memory: what its
          // pages held was read with rights it no longer has.
          if (!stateReset && previousContext?.isAvailable == true) {
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
        permissionChange = AccountContextPermissionChange.between(
          _storedContext(),
          selected,
        );
        await _persistContext(selected);
        return _isCurrent(generation);
      });
      if (!persisted || !_isCurrent(generation)) return;

      _contexts = List<AccountContext>.unmodifiable(freshContexts);
      _selectedContext = selected;
      _notePermissionChange(permissionChange, selected);
      _hasLoadedContexts = true;
      _lastRefreshAnswered = true;
      await _forgetRemovedPlans(
        heldAsParticipant,
        stillHeld: {
          for (final context in serverContexts) ?context.weddingPlanId,
          ...blockedPlanIds,
        },
      );
      if (!_sameContext(previousContext, selected)) {
        appLogEvent(
          selected == null
              ? 'ACTIVE_CONTEXT_CLEARED'
              : 'ACTIVE_CONTEXT_SELECTED',
          category: AppLogCategory.context,
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
      await _afterRefresh?.call();
    } on ApiException catch (error) {
      if (_isCurrent(generation)) {
        // D112 (Q-17), the owner's word: a plan stays open without a
        // connection for its owner and for its participants, on the copy
        // the phone holds and marked old; it closes only when the server
        // answers that the right was withdrawn. (Participants used to be
        // closed out until the server answered, since 2026-08-01.) A
        // provider's portal still waits for the server.
        if (!error.isNetworkFailure) {
          _errorMessage = _genericLoadFailure;
        } else if (_hasLoadedContexts) {
          if (_staysOpenOffline(_selectedContext)) {
            _noticeMessage = _offlineNotice;
          } else {
            _errorMessage = _offlineLoadFailure;
          }
        } else if (!await _openKeptContext(generation, blockedPlanIds) &&
            _isCurrent(generation)) {
          _errorMessage = _offlineLoadFailure;
        }
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

  /// Refreshes, then opens the account plan [planId] when nothing is open:
  /// a plan just saved from this phone (a08b → b01) opens at once, never a
  /// chooser holding only that plan.
  Future<void> refreshAndOpenPlan(String planId) async {
    await refresh();
    if (_disposed || _selectedContext != null) return;
    final saved = _firstOrNull(
      availableContexts,
      (context) => context.isPlan && context.weddingPlanId == planId,
    );
    if (saved != null) await select(saved.contextKey);
  }

  Future<bool> select(String contextKey) async {
    appLogEvent(
      'ACTIVE_CONTEXT_SELECTION_REQUESTED',
      category: AppLogCategory.context,
      userId: _userId,
      fromContextKey: _selectedContext?.contextKey,
      toContextKey: contextKey,
      source: 'AccountContextController.select',
      reason: 'explicit_user_or_flow_selection',
    );
    final generation = ++_generation;
    final previousContext = _selectedContext;
    AccountContextPermissionChange? permissionChange;
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
        permissionChange = AccountContextPermissionChange.between(
          _storedContext(),
          validated,
        );
        await _authStorage.saveAccountContextKey(
          validated.contextKey,
          context: validated.toJson(),
        );
        return _isCurrent(generation);
      });
      if (!committed || !_isCurrent(generation)) return false;

      _contexts = List<AccountContext>.unmodifiable(
        _replaceOrAppend(_contexts, validated),
      );
      _selectedContext = validated;
      _notePermissionChange(permissionChange, validated);
      appLogEvent(
        'ACTIVE_CONTEXT_SELECTED',
        category: AppLogCategory.context,
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
        appLogEvent(
          'ACTIVE_CONTEXT_CLEARED',
          category: AppLogCategory.context,
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
        await _authStorage.saveAccountContextKey(
          archived.contextKey,
          context: archived.toJson(),
        );
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
    appLogEvent(
      'EXIT_WORKSPACE',
      category: AppLogCategory.context,
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
    appLogEvent(
      'LOGOUT_ACCOUNT',
      category: AppLogCategory.context,
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
    _permissionChange = null;
    _hasLoadedContexts = false;
    _errorMessage = null;
    _noticeMessage = null;
    _notifyListeners();
    appLogEvent(
      'ACTIVE_CONTEXT_CLEARED',
      category: AppLogCategory.context,
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
    await _authStorage.saveAccountContextKey(
      context.contextKey,
      context: context.toJson(),
    );
  }

  /// The path this phone kept for the signed-in user, whatever its role.
  /// RA-MO-275: a participant taken off a plan kept its copy and its
  /// unsent changes on the phone; the server refused each change, and each
  /// stayed blocked for a plan the participant can no longer open to delete
  /// it. The server's answer removes them, counted for the page that tells
  /// the removal. A plan still listed, or one whose leave is pending (the
  /// leave owns it), is kept.
  Future<void> _forgetRemovedPlans(
    Set<String> held, {
    required Set<String> stillHeld,
  }) async {
    final forget = _forgetRemovedPlan;
    if (forget == null) return;
    for (final planId in held.difference(stillHeld)) {
      try {
        final dropped = await forget(planId);
        if (dropped > 0) _droppedOnRemoval[planId] = dropped;
      } on Object catch (error) {
        debugPrint('Removed plan $planId not cleared: $error');
      }
    }
  }

  AccountContext? _storedContext() {
    final kept = _authStorage.readAccountContextSnapshot();
    if (kept == null) return null;
    try {
      return AccountContext.fromJson(kept);
    } on FormatException {
      return null;
    }
  }

  /// A new change replaces the last one; another path drops it.
  void _notePermissionChange(
    AccountContextPermissionChange? change,
    AccountContext? selected,
  ) {
    if (change != null) {
      _permissionChange = change;
    } else if (_permissionChange?.contextKey != selected?.contextKey) {
      _permissionChange = null;
    }
  }

  /// D112 (Q-17): a plan, the owner's or a participant's, reads from the
  /// phone's copy without a connection. A provider's portal does not.
  static bool _staysOpenOffline(AccountContext? context) =>
      context != null &&
      context.isPlan &&
      (context.role == AccountContextRole.owner ||
          context.role == AccountContextRole.contributor);

  /// Without a connection, the plan last opened (the user's own, or one
  /// they take part in), as the server last returned it; null when there is
  /// none or it no longer reads.
  AccountContext? _keptContext() {
    final kept = _authStorage.readAccountContextSnapshot();
    if (kept == null) return null;
    try {
      final context = AccountContext.fromJson(kept);
      return context.opens && _staysOpenOffline(context) ? context : null;
    } on FormatException {
      return null;
    }
  }

  /// Opens the kept context when the server cannot be reached; returns
  /// whether it did. A plan being left is never opened.
  Future<bool> _openKeptContext(
    int generation,
    Set<String> blockedPlanIds,
  ) async {
    final kept = _keptContext();
    if (kept == null || blockedPlanIds.contains(kept.weddingPlanId)) {
      return false;
    }
    final opened = await _enqueueCommit(() async {
      if (!_isCurrent(generation)) return false;
      await _resetContextState(null, kept);
      return _isCurrent(generation);
    });
    if (!opened || !_isCurrent(generation)) return false;
    _contexts = List<AccountContext>.unmodifiable([kept]);
    _selectedContext = kept;
    _hasLoadedContexts = true;
    _noticeMessage = _offlineNotice;
    appLogEvent(
      'ACTIVE_CONTEXT_SELECTED',
      category: AppLogCategory.context,
      userId: _userId,
      toContextKey: kept.contextKey,
      source: 'AccountContextController.refresh',
      reason: 'offline_kept_context',
    );
    return true;
  }

  AccountContext? _selectFallback(
    List<AccountContext> availableContexts, {
    required String? currentKey,
    required String? persistedKey,
    required bool allowSingleContext,
  }) {
    // D112 (Q-21): the owner's plan in the memories stays the open path,
    // through a refresh and a restart, to be read. Nothing else that is
    // unavailable does, and a memory is never picked on its own below.
    AccountContext? byKey(String? key) {
      if (key == null) return null;
      return _firstOrNull(
        availableContexts,
        (context) => context.opens && context.contextKey == key,
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
