import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/media/media_upload_api.dart';
import '../../../core/network/api_client.dart';
import '../../../core/session/session_scoped_change_notifier.dart';
import '../../../core/storage/auth_storage.dart';
import '../data/chat_api.dart';
import '../data/chat_realtime_client.dart';
import '../models/chat_models.dart';

class ChatProvider extends ChangeNotifier with SessionScopedNotifier {
  ChatProvider({
    required ChatApi api,
    required ChatRealtimeClient realtime,
    required AuthStorage authStorage,
    String? sessionUserId,
  }) : _api = api,
       _realtime = realtime,
       _sessionUserId = sessionUserId ?? authStorage.readUser()?.id;

  final ChatApi _api;
  final ChatRealtimeClient _realtime;

  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;
  List<ChatConversation> _conversations = const [];
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, String?> _nextCursors = {};
  final Set<String> _loadingOlder = {};
  final Set<String> _conversationLoadErrors = {};
  bool _realtimeStarted = false;
  String? _activeConversationId;
  String? _sessionUserId;

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;
  List<ChatConversation> get conversations => _conversations;
  String? get currentUserId => _sessionUserId;
  List<ChatMessage> messagesFor(String conversationId) =>
      _messages[conversationId] ?? const [];
  bool canLoadOlder(String conversationId) =>
      _nextCursors[conversationId] != null;
  bool isLoadingOlder(String conversationId) =>
      _loadingOlder.contains(conversationId);
  bool hasConversationLoadError(String conversationId) =>
      _conversationLoadErrors.contains(conversationId);
  bool isMessageRead(ChatMessage message) {
    if (message.pending || message.senderUserId != currentUserId) return false;
    for (final conversation in _conversations) {
      if (conversation.id != message.conversationId) continue;
      final readAt = conversation.counterpartLastReadAt;
      return readAt != null && !readAt.isBefore(message.createdAt);
    }
    return false;
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
    _messages.clear();
    _nextCursors.clear();
    _loadingOlder.clear();
    _conversationLoadErrors.clear();
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
        onRead: _receiveRead,
      );
      for (final conversation in _conversations) {
        _realtime.join(conversation.id);
      }
      for (final conversationId in _messages.keys) {
        _realtime.join(conversationId);
      }
    } on Object {
      _realtimeStarted = false;
    }
  }

  Future<void> loadConversations() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _conversations = await _api.listConversations();
      for (final conversation in _conversations) {
        _realtime.join(conversation.id);
      }
    } on ApiException catch (error) {
      _errorMessage = error.message;
    } catch (_) {
      _errorMessage = aarastBackendConnectionErrorMessage;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ChatConversation?> openQuote(String quoteRequestId) async {
    _errorMessage = null;
    try {
      final conversation = await _api.ensureForQuote(quoteRequestId);
      _upsertConversation(conversation);
      await openConversation(conversation.id);
      return conversation;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> openConversation(String conversationId) async {
    _activeConversationId = conversationId;
    _startRealtime();
    if (!_conversations.any((item) => item.id == conversationId)) {
      await loadConversations();
    }
    _isLoading = true;
    _errorMessage = null;
    _conversationLoadErrors.remove(conversationId);
    notifyListeners();
    try {
      final page = await _api.messages(conversationId);
      _messages[conversationId] = page.items;
      _nextCursors[conversationId] = page.nextCursor;
      _realtime.join(conversationId);
      await _api.markRead(conversationId);
      _realtime.markRead(conversationId);
      _clearUnread(conversationId);
    } on ApiException catch (error) {
      _errorMessage = error.message;
      _conversationLoadErrors.add(conversationId);
    } catch (_) {
      _errorMessage = aarastBackendConnectionErrorMessage;
      _conversationLoadErrors.add(conversationId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void closeConversation(String conversationId) {
    if (_activeConversationId == conversationId) {
      _activeConversationId = null;
    }
  }

  Future<void> loadOlder(String conversationId) async {
    final cursor = _nextCursors[conversationId];
    if (cursor == null || _loadingOlder.contains(conversationId)) return;
    _loadingOlder.add(conversationId);
    _errorMessage = null;
    notifyListeners();
    try {
      final page = await _api.messages(conversationId, cursor: cursor);
      final existing = messagesFor(conversationId);
      final existingIds = existing.map((message) => message.id).toSet();
      _messages[conversationId] = [
        ...page.items.where((message) => !existingIds.contains(message.id)),
        ...existing,
      ];
      _nextCursors[conversationId] = page.nextCursor;
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
    final pendingId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final pending = ChatMessage(
      id: pendingId,
      conversationId: conversationId,
      senderUserId: currentUserId ?? '',
      body: normalized,
      createdAt: DateTime.now(),
      pending: true,
    );
    _messages[conversationId] = [...messagesFor(conversationId), pending];
    _isSending = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final sent = await _api.send(
        conversationId,
        body: normalized,
        attachments: attachments,
      );
      _messages[conversationId] = [
        for (final message in messagesFor(conversationId))
          if (message.id != pendingId && message.id != sent.id) message,
        sent,
      ];
      _applyMessageToConversation(sent);
      return true;
    } on ApiException catch (error) {
      _messages[conversationId] = messagesFor(
        conversationId,
      ).where((message) => message.id != pendingId).toList(growable: false);
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _messages[conversationId] = messagesFor(
        conversationId,
      ).where((message) => message.id != pendingId).toList(growable: false);
      _errorMessage = aarastBackendConnectionErrorMessage;
      return false;
    } finally {
      _isSending = false;
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
  }

  void _receive(ChatMessage message) {
    final current = messagesFor(message.conversationId);
    if (current.any((item) => item.id == message.id)) return;
    _messages[message.conversationId] = [...current, message];
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
    if (messagesFor(conversationId).any((item) => item.id == messageId)) return;
    try {
      final page = await _api.messages(conversationId);
      if (isSessionDisposed) return;
      for (final message in page.items) {
        if (message.id == messageId) {
          _receive(message);
          return;
        }
      }
    } on Object {
      // The durable event remains idempotent. Normal open/refresh retries REST.
    }
  }

  Future<void> _markReadAfterReceive(String conversationId) async {
    try {
      await _api.markRead(conversationId);
      _realtime.markRead(conversationId);
      _clearUnread(conversationId);
      notifyListeners();
    } on Object {
      // The visible message remains available; the next open retries read state.
    }
  }

  void _applyMessageToConversation(ChatMessage message) {
    final isActive = _activeConversationId == message.conversationId;
    final isMine = message.senderUserId == currentUserId;
    _conversations = [
      for (final item in _conversations)
        if (item.id == message.conversationId)
          ChatConversation(
            id: item.id,
            quoteRequestId: item.quoteRequestId,
            counterpart: item.counterpart,
            unreadCount: isActive || isMine ? 0 : item.unreadCount + 1,
            muted: item.muted,
            blocked: item.blocked,
            blockedByMe: item.blockedByMe,
            blockedByCounterpart: item.blockedByCounterpart,
            counterpartLastReadAt: item.counterpartLastReadAt,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
            lastMessage: message,
            lastMessageAt: message.createdAt,
            serviceTitle: item.serviceTitle,
            providerName: item.providerName,
          )
        else
          item,
    ];
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
    _conversations = [
      for (final item in _conversations)
        if (item.id == conversationId &&
            (item.counterpartLastReadAt == null ||
                item.counterpartLastReadAt!.isBefore(lastReadAt)))
          ChatConversation(
            id: item.id,
            quoteRequestId: item.quoteRequestId,
            counterpart: item.counterpart,
            unreadCount: item.unreadCount,
            muted: item.muted,
            blocked: item.blocked,
            blockedByMe: item.blockedByMe,
            blockedByCounterpart: item.blockedByCounterpart,
            counterpartLastReadAt: lastReadAt,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
            lastMessage: item.lastMessage,
            lastMessageAt: item.lastMessageAt,
            serviceTitle: item.serviceTitle,
            providerName: item.providerName,
          )
        else
          item,
    ];
    notifyListeners();
  }

  void _upsertConversation(ChatConversation conversation) {
    _conversations = [
      conversation,
      ..._conversations.where((item) => item.id != conversation.id),
    ];
    notifyListeners();
  }

  void _clearUnread(String conversationId) {
    _conversations = [
      for (final item in _conversations)
        if (item.id == conversationId)
          ChatConversation(
            id: item.id,
            quoteRequestId: item.quoteRequestId,
            counterpart: item.counterpart,
            unreadCount: 0,
            muted: item.muted,
            blocked: item.blocked,
            blockedByMe: item.blockedByMe,
            blockedByCounterpart: item.blockedByCounterpart,
            counterpartLastReadAt: item.counterpartLastReadAt,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
            lastMessage: item.lastMessage,
            lastMessageAt: item.lastMessageAt,
            serviceTitle: item.serviceTitle,
            providerName: item.providerName,
          )
        else
          item,
    ];
  }

  @override
  void dispose() {
    _realtime.reset();
    super.dispose();
  }
}
