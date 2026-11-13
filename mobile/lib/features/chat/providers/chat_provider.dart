import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/media/media_upload_api.dart';
import '../../../core/network/api_client.dart';
import '../../../core/offline/cached_first_load.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../../../core/storage/auth_storage.dart';
import '../data/chat_api.dart';
import '../data/chat_outbox.dart';
import '../data/chat_realtime_client.dart';
import '../models/chat_models.dart';

class ChatProvider extends ChangeNotifier with SessionScopedNotifier {
  ChatProvider({
    required ChatApi api,
    required ChatRealtimeClient realtime,
    required AuthStorage authStorage,
    String? sessionUserId,
    ChatOutbox? outbox,
  }) : _api = api,
       _realtime = realtime,
       _outbox = outbox,
       _sessionUserId = sessionUserId ?? authStorage.readUser()?.id;

  final ChatApi _api;
  final ChatRealtimeClient _realtime;
  final ChatOutbox? _outbox;
  bool _flushing = false;

  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;
  List<ChatConversation> _conversations = const [];
  final Map<String, List<ChatTimelineItem>> _timelines = {};
  final Map<String, List<ChatQuoteRequestSummary>> _quoteRequests = {};
  final Map<String, String?> _nextTimelineCursors = {};
  final Map<String, DateTime> _counterpartReadAt = {};
  final Map<String, Future<void>> _activityRefreshes = {};
  final Set<String> _loadingOlder = {};
  final Set<String> _conversationLoadErrors = {};
  String? _nextConversationCursor;
  bool _isLoadingMoreConversations = false;
  bool _realtimeStarted = false;
  String? _activeConversationId;
  String? _sessionUserId;

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  bool get isLoadingMoreConversations => _isLoadingMoreConversations;
  String? get errorMessage => _errorMessage;
  List<ChatConversation> get conversations => _conversations;
  String? get currentUserId => _sessionUserId;
  bool get canLoadMoreConversations => _nextConversationCursor != null;
  List<ChatTimelineItem> timelineFor(String conversationId) =>
      _timelines[conversationId] ?? const [];
  List<ChatQuoteRequestSummary> quoteRequestsFor(String conversationId) =>
      _quoteRequests[conversationId] ?? const [];
  bool canLoadOlder(String conversationId) =>
      _nextTimelineCursors[conversationId] != null;
  bool isLoadingOlder(String conversationId) =>
      _loadingOlder.contains(conversationId);
  bool hasConversationLoadError(String conversationId) =>
      _conversationLoadErrors.contains(conversationId);

  bool isMessageRead(ChatMessage message) {
    if (message.pending || message.senderUserId != currentUserId) return false;
    final readAt = _counterpartReadAt[message.conversationId];
    return readAt != null && !readAt.isBefore(message.createdAt);
  }

  void syncSessionUser(String? userId) {
    if (_sessionUserId == userId) return;
    _sessionUserId = userId;
    _realtime.reset();
    _realtimeStarted = false;
    _activeConversationId = null;
    _isLoading = false;
    _isSending = false;
    _errorMessage = null;
    _conversations = const [];
    _timelines.clear();
    _quoteRequests.clear();
    _nextTimelineCursors.clear();
    _counterpartReadAt.clear();
    _activityRefreshes.clear();
    _loadingOlder.clear();
    _conversationLoadErrors.clear();
    _nextConversationCursor = null;
    _isLoadingMoreConversations = false;
    if (userId != null) _startRealtime();
    notifyListeners();
  }

  Future<void> initialize() async {
    _startRealtime();
    await loadConversations();
  }

  void _startRealtime() {
    if (_sessionUserId == null || _realtimeStarted) return;
    _realtimeStarted = true;
    unawaited(_connectRealtime());
  }

  Future<void> _connectRealtime() async {
    try {
      await _realtime.connect(
        onMessage: _receive,
        onMessageAvailable: _recoverAvailableMessage,
        onActivityAvailable: _recoverActivity,
        onPermissionRevoked: _permissionRevoked,
        onRead: _receiveRead,
      );
      for (final conversation in _conversations) {
        _realtime.join(conversation.id);
      }
      for (final conversationId in _timelines.keys) {
        _realtime.join(conversationId);
      }
    } on Object {
      _realtimeStarted = false;
    }
  }

  /// D85: the copy stays because the server did not answer.
  bool _isStale = false;
  bool get isStale => _isStale;

  /// D85: the phone's copy of the conversations shows at once; the
  /// server's answer replaces it.
  Future<void> loadConversations() async {
    await readCachedFirst<ChatConversationPage>(
      cached: _api.cachedConversations,
      remote: () async {
        final page = await _api.listConversations();
        // G38: the server answers again; send what waited on the phone.
        unawaited(flushOutbox());
        return page;
      },
      apply: (page) {
        _conversations = page.items;
        _nextConversationCursor = page.nextCursor;
        for (final conversation in _conversations) {
          _realtime.join(conversation.id);
        }
      },
      state: ({required loading, required stale, error}) {
        _isLoading = loading;
        _isStale = stale;
        _errorMessage = error;
        notifyListeners();
      },
      describe: (error) => error is ApiException
          ? error.message
          : aarastBackendConnectionErrorMessage,
    );
  }

  Future<void> loadMoreConversations() async {
    final cursor = _nextConversationCursor;
    if (cursor == null || _isLoadingMoreConversations) return;
    _isLoadingMoreConversations = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final page = await _api.listConversations(cursor: cursor);
      final existingIds = _conversations.map((item) => item.id).toSet();
      _conversations = [
        ..._conversations,
        ...page.items.where((item) => existingIds.add(item.id)),
      ];
      _nextConversationCursor = page.nextCursor;
      for (final conversation in page.items) {
        _realtime.join(conversation.id);
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = aarastBackendConnectionErrorMessage;
    } finally {
      _isLoadingMoreConversations = false;
      notifyListeners();
    }
  }

  /// The last [openQuote] was refused for good: the request is gone, or it
  /// is not this account's. Asking again cannot succeed.
  bool get quoteOpenRefused => _quoteOpenRefused;
  bool _quoteOpenRefused = false;

  Future<ChatConversation?> openQuote(String quoteRequestId) async {
    _errorMessage = null;
    _quoteOpenRefused = false;
    try {
      final conversation = await _api
          .conversationForQuote(quoteRequestId)
          .timeout(const Duration(seconds: 15));
      _upsertConversation(conversation);
      return conversation;
    } on TimeoutException {
      _errorMessage = 'فتح المحادثة طوّل أكثر من اللازم. جرّب مرة ثانية.';
    } on ApiException catch (error) {
      _errorMessage = error.message;
      _quoteOpenRefused = error.statusCode == 403 || error.statusCode == 404;
    } catch (_) {
      _errorMessage = aarastBackendConnectionErrorMessage;
    }
    notifyListeners();
    return null;
  }

  /// D85: the phone's copy of the conversation's first page shows at once;
  /// the server's answer replaces it, and the requests beside it follow.
  Future<void> openConversation(String conversationId) async {
    _activeConversationId = conversationId;
    _startRealtime();
    _conversationLoadErrors.remove(conversationId);
    await readCachedFirst<ChatTimelinePage>(
      cached: () => _api.cachedTimeline(conversationId),
      remote: () async {
        if (!_conversations.any((item) => item.id == conversationId)) {
          _upsertConversation(await _api.getConversation(conversationId));
        }
        final results = await Future.wait<Object>([
          _api.timeline(conversationId),
          _api.quoteRequests(conversationId),
        ]);
        final timeline = results[0] as ChatTimelinePage;
        final quoteRequests = results[1] as ChatQuoteRequestPage;
        _quoteRequests[conversationId] = quoteRequests.items;
        unawaited(flushOutbox());
        _realtime.join(conversationId);
        // Kept on the phone and sent when the server answers (D85).
        await _api.markRead(conversationId);
        _realtime.markRead(conversationId);
        _clearUnread(conversationId);
        return timeline;
      },
      apply: (timeline) {
        _timelines[conversationId] = [
          ...timeline.items,
          ..._queuedItems(conversationId),
        ];
        _nextTimelineCursors[conversationId] = timeline.nextCursor;
      },
      state: ({required loading, required stale, error}) {
        _isLoading = loading;
        _isStale = stale;
        _errorMessage = error;
        if (error != null) _conversationLoadErrors.add(conversationId);
        notifyListeners();
      },
      describe: (error) => error is ApiException
          ? error.message
          : aarastBackendConnectionErrorMessage,
    );
  }

  void closeConversation(String conversationId) {
    if (_activeConversationId == conversationId) {
      _activeConversationId = null;
    }
  }

  Future<void> loadOlder(String conversationId) async {
    final cursor = _nextTimelineCursors[conversationId];
    if (cursor == null || _loadingOlder.contains(conversationId)) return;
    _loadingOlder.add(conversationId);
    _errorMessage = null;
    notifyListeners();
    try {
      final page = await _api.timeline(conversationId, cursor: cursor);
      final existing = timelineFor(conversationId);
      final existingIds = existing.map((item) => item.identity).toSet();
      _timelines[conversationId] = [
        ...page.items.where((item) => !existingIds.contains(item.identity)),
        ...existing,
      ];
      _nextTimelineCursors[conversationId] = page.nextCursor;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = aarastBackendConnectionErrorMessage;
    } finally {
      _loadingOlder.remove(conversationId);
      notifyListeners();
    }
  }

  Future<bool> send(
    String conversationId,
    String body, {
    List<MediaUploadTicket> attachments = const [],
  }) async {
    final normalized = body.trim();
    if (normalized.isEmpty) return false;
    final conversation = _conversation(conversationId);
    if (conversation?.canSend != true) {
      _errorMessage = conversation?.providerJoined == false
          ? 'المزود ما دخل المحادثة لسا'
          : 'ما تقدر ترسل رسائل في هذي المحادثة الحين.';
      notifyListeners();
      return false;
    }
    final pendingId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final clientRequestId = 'chat-$pendingId-${normalized.hashCode.abs()}';
    final pending = ChatMessage(
      id: pendingId,
      conversationId: conversationId,
      senderUserId: currentUserId ?? '',
      body: normalized,
      createdAt: DateTime.now(),
      pending: true,
    );
    _timelines[conversationId] = [
      ...timelineFor(conversationId),
      ChatTimelineItem.pending(pending),
    ];
    _isSending = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final sent = await _api.send(
        conversationId,
        body: normalized,
        attachments: attachments,
        clientRequestId: clientRequestId,
      );
      _replacePending(conversationId, pendingId, sent);
      _applyMessageToConversation(sent);
      unawaited(flushOutbox());
      return true;
    } on ApiException catch (error) {
      // G38: a text written with no network waits on the phone and goes
      // when the network is back, with the same request id; so does one the
      // server asks to wait (RA-BE-81: too many messages in a minute).
      if (attachments.isEmpty &&
          (error.isAmbiguousMutationFailure || error.isNotNow) &&
          await _keep(
            ChatOutboxMessage(
              localId: pendingId,
              conversationId: conversationId,
              body: normalized,
              clientRequestId: clientRequestId,
              createdAt: pending.createdAt,
            ),
          )) {
        _markQueued(conversationId, pendingId);
        return true;
      }
      _removeTimelineMessage(conversationId, pendingId);
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _removeTimelineMessage(conversationId, pendingId);
      _errorMessage = aarastBackendConnectionErrorMessage;
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  /// RA-BE-95: the words of the messages refused in this chat after they
  /// waited on the phone, joined in the order written, with the last reason;
  /// taken off the phone as they are handed back. Null when there are none.
  Future<({String text, String reason})?> takeRefused(
    String conversationId,
  ) async {
    final userId = currentUserId;
    final outbox = _outbox;
    if (userId == null || outbox == null) return null;
    final all = outbox.read(userId);
    final refused = [
      for (final item in all)
        if (item.isRefused && item.conversationId == conversationId) item,
    ];
    if (refused.isEmpty) return null;
    await outbox.write(userId, [
      for (final item in all)
        if (!refused.contains(item)) item,
    ]);
    return (
      text: refused.map((item) => item.body).join('\n'),
      reason: refused.last.refusedReason!,
    );
  }

  /// G38: the messages waiting on this phone, in the order written.
  List<ChatOutboxMessage> get queuedMessages {
    final userId = currentUserId;
    final outbox = _outbox;
    if (userId == null || outbox == null) return const [];
    return [
      for (final item in outbox.read(userId))
        if (!item.isRefused) item,
    ];
  }

  Iterable<ChatTimelineItem> _queuedItems(String conversationId) => [
    for (final item in queuedMessages)
      if (item.conversationId == conversationId)
        ChatTimelineItem.pending(_queuedMessage(item)),
  ];

  ChatMessage _queuedMessage(ChatOutboxMessage item) => ChatMessage(
    id: item.localId,
    conversationId: item.conversationId,
    senderUserId: currentUserId ?? '',
    body: item.body,
    createdAt: item.createdAt,
    pending: true,
    queued: true,
  );

  Future<bool> _keep(ChatOutboxMessage message) async {
    final userId = currentUserId;
    final outbox = _outbox;
    if (userId == null || outbox == null) return false;
    try {
      await outbox.write(userId, [...outbox.read(userId), message]);
      return true;
    } on Object {
      return false;
    }
  }

  void _markQueued(String conversationId, String localId) {
    _timelines[conversationId] = [
      for (final item in timelineFor(conversationId))
        if (item.message?.id == localId)
          ChatTimelineItem.pending(
            _queuedMessage(
              queuedMessages.firstWhere((queued) => queued.localId == localId),
            ),
          )
        else
          item,
    ];
  }

  /// G38: sends the waiting messages in order; stops at the first one that
  /// still finds no network. A message the server refuses is not sent again
  /// and leaves the timeline, but its words are kept (RA-BE-95): they go back
  /// to the chat's box with the reason ([takeRefused]).
  Future<void> flushOutbox() async {
    final userId = currentUserId;
    final outbox = _outbox;
    if (userId == null || outbox == null || _flushing) return;
    _flushing = true;
    try {
      for (final item in outbox.read(userId)) {
        if (item.isRefused) continue;
        try {
          final sent = await _api.send(
            item.conversationId,
            body: item.body,
            clientRequestId: item.clientRequestId,
          );
          if (_timelines.containsKey(item.conversationId)) {
            _replacePending(item.conversationId, item.localId, sent);
          }
          _applyMessageToConversation(sent);
        } on ApiException catch (error) {
          if (error.isAmbiguousMutationFailure || error.isNotNow) break;
          _removeTimelineMessage(item.conversationId, item.localId);
          _errorMessage = 'رسالة ما وصلت: ${error.message}';
          await outbox.write(userId, [
            for (final left in outbox.read(userId))
              left.localId == item.localId ? left.refused(error.message) : left,
          ]);
          continue;
        }
        await outbox.write(userId, [
          for (final left in outbox.read(userId))
            if (left.localId != item.localId) left,
        ]);
      }
    } finally {
      _flushing = false;
      notifyListeners();
    }
  }

  Future<bool> setMuted(ChatConversation conversation, bool enabled) async {
    _errorMessage = null;
    try {
      await _api.setMuted(conversation.id, enabled);
      _replaceConversation(conversation.copyWith(muted: enabled));
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = aarastBackendConnectionErrorMessage;
    }
    notifyListeners();
    return false;
  }

  Future<bool> setBlocked(ChatConversation conversation, bool enabled) async {
    _errorMessage = null;
    try {
      await _api.setBlocked(conversation.id, enabled);
      _replaceConversation(
        conversation.copyWith(
          blocked: enabled || conversation.blockedByCounterpart,
          blockedByMe: enabled,
          canSend: !enabled && !conversation.blockedByCounterpart,
        ),
      );
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = aarastBackendConnectionErrorMessage;
    }
    notifyListeners();
    return false;
  }

  Future<bool> report(ChatConversation conversation, String reason) async {
    _errorMessage = null;
    try {
      await _api.report(conversation.id, reason);
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = aarastBackendConnectionErrorMessage;
    }
    notifyListeners();
    return false;
  }

  void _replaceConversation(ChatConversation conversation) {
    _conversations = [
      for (final item in _conversations)
        if (item.id == conversation.id) conversation else item,
    ];
    _sortConversations();
  }

  void _receive(ChatMessage message) {
    final current = timelineFor(message.conversationId);
    if (current.any((item) => item.message?.id == message.id)) return;
    _timelines[message.conversationId] = [
      ...current,
      ChatTimelineItem.pending(message),
    ];
    _applyMessageToConversation(message);
    if (_activeConversationId == message.conversationId &&
        message.senderUserId != currentUserId) {
      unawaited(_markReadAfterReceive(message.conversationId));
    }
    notifyListeners();
  }

  Future<void> _recoverAvailableMessage(
    String conversationId,
    String messageId,
  ) async {
    if (conversationId.isEmpty || messageId.isEmpty) return;
    if (timelineFor(
      conversationId,
    ).any((item) => item.message?.id == messageId)) {
      return;
    }
    await _recoverActivity(conversationId);
  }

  Future<void> _recoverActivity(String conversationId) async {
    if (conversationId.isEmpty) return;
    final active = _activityRefreshes[conversationId];
    if (active != null) return active;
    final refresh = _refreshActivity(conversationId);
    _activityRefreshes[conversationId] = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_activityRefreshes[conversationId], refresh)) {
        _activityRefreshes.remove(conversationId);
      }
    }
  }

  Future<void> _refreshActivity(String conversationId) async {
    try {
      final results = await Future.wait<Object>([
        _api.getConversation(conversationId),
        _api.timeline(conversationId),
        _api.quoteRequests(conversationId),
      ]);
      if (isSessionDisposed) return;
      _upsertConversation(results[0] as ChatConversation, notify: false);
      final page = results[1] as ChatTimelinePage;
      // The texts still waiting to go stay under the server's page, as on
      // opening the conversation (RA-MO-249).
      _timelines[conversationId] = [
        ...page.items,
        ..._queuedItems(conversationId),
      ];
      _nextTimelineCursors[conversationId] = page.nextCursor;
      _quoteRequests[conversationId] =
          (results[2] as ChatQuoteRequestPage).items;
      if (_activeConversationId == conversationId) {
        await _markReadAfterReceive(conversationId);
      }
      notifyListeners();
    } on Object {
      // The outbox event is durable; opening or refreshing retries REST.
    }
  }

  void _permissionRevoked(String conversationId) {
    if (conversationId.isEmpty) return;
    _conversations = _conversations
        .where((item) => item.id != conversationId)
        .toList(growable: false);
    _timelines.remove(conversationId);
    _quoteRequests.remove(conversationId);
    _nextTimelineCursors.remove(conversationId);
    _counterpartReadAt.remove(conversationId);
    _conversationLoadErrors.add(conversationId);
    if (_activeConversationId == conversationId) {
      _errorMessage = 'انشالت صلاحيتك على هذي المحادثة.';
    }
    notifyListeners();
  }

  Future<void> _markReadAfterReceive(String conversationId) async {
    try {
      await _api.markRead(conversationId);
      _realtime.markRead(conversationId);
      _clearUnread(conversationId);
      notifyListeners();
    } on Object {
      // The visible activity remains available; the next open retries read state.
    }
  }

  void _applyMessageToConversation(ChatMessage message) {
    final isActive = _activeConversationId == message.conversationId;
    final isMine = message.senderUserId == currentUserId;
    _conversations = [
      for (final item in _conversations)
        if (item.id == message.conversationId)
          item.copyWith(
            unreadMessageCount: isActive || isMine
                ? 0
                : item.unreadMessageCount + 1,
            lastMessage: message,
            lastActivityAt: message.createdAt,
          )
        else
          item,
    ];
    _sortConversations();
  }

  void _receiveRead(
    String conversationId,
    String userId,
    DateTime? lastReadAt,
  ) {
    if (conversationId.isEmpty ||
        userId.isEmpty ||
        userId == currentUserId ||
        lastReadAt == null) {
      return;
    }
    final current = _counterpartReadAt[conversationId];
    if (current == null || current.isBefore(lastReadAt)) {
      _counterpartReadAt[conversationId] = lastReadAt;
      notifyListeners();
    }
  }

  void _upsertConversation(
    ChatConversation conversation, {
    bool notify = true,
  }) {
    _conversations = [
      conversation,
      ..._conversations.where((item) => item.id != conversation.id),
    ];
    _sortConversations();
    if (notify) notifyListeners();
  }

  void _clearUnread(String conversationId) {
    _conversations = [
      for (final item in _conversations)
        if (item.id == conversationId)
          item.copyWith(unreadMessageCount: 0)
        else
          item,
    ];
  }

  ChatConversation? _conversation(String conversationId) {
    for (final conversation in _conversations) {
      if (conversation.id == conversationId) return conversation;
    }
    return null;
  }

  void _replacePending(
    String conversationId,
    String pendingId,
    ChatMessage sent,
  ) {
    _timelines[conversationId] = [
      for (final item in timelineFor(conversationId))
        if (item.message?.id == pendingId)
          ChatTimelineItem.pending(sent)
        else if (item.message?.id != sent.id)
          item,
    ];
  }

  void _removeTimelineMessage(String conversationId, String messageId) {
    _timelines[conversationId] = timelineFor(
      conversationId,
    ).where((item) => item.message?.id != messageId).toList(growable: false);
  }

  void _sortConversations() {
    _conversations = [..._conversations]
      ..sort((left, right) {
        final byActivity = right.lastActivityAt.compareTo(left.lastActivityAt);
        return byActivity != 0 ? byActivity : right.id.compareTo(left.id);
      });
  }

  @override
  void dispose() {
    _realtime.reset();
    super.dispose();
  }
}
