import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/media/media_upload_api.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_storage.dart';
import '../data/chat_api.dart';
import '../data/chat_realtime_client.dart';
import '../models/chat_models.dart';

class ChatProvider extends ChangeNotifier {
  ChatProvider({
    required ChatApi api,
    required ChatRealtimeClient realtime,
    required AuthStorage authStorage,
  }) : _api = api,
       _realtime = realtime,
       _authStorage = authStorage;

  final ChatApi _api;
  final ChatRealtimeClient _realtime;
  final AuthStorage _authStorage;

  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;
  List<ChatConversation> _conversations = const [];
  final Map<String, List<ChatMessage>> _messages = {};
  final Map<String, String?> _nextCursors = {};
  bool _realtimeStarted = false;

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;
  List<ChatConversation> get conversations => _conversations;
  String? get currentUserId => _authStorage.readUser()?.id;
  List<ChatMessage> messagesFor(String conversationId) =>
      _messages[conversationId] ?? const [];

  Future<void> initialize() async {
    _startRealtime();
    await loadConversations();
  }

  void _startRealtime() {
    if (_realtimeStarted) return;
    _realtimeStarted = true;
    unawaited(_connectRealtime());
  }

  Future<void> _connectRealtime() async {
    try {
      await _realtime.connect(onMessage: _receive, onRead: _receiveRead);
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
    _isLoading = true;
    _errorMessage = null;
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
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOlder(String conversationId) async {
    final cursor = _nextCursors[conversationId];
    if (cursor == null) return;
    final page = await _api.messages(conversationId, cursor: cursor);
    _messages[conversationId] = [...page.items, ...messagesFor(conversationId)];
    _nextCursors[conversationId] = page.nextCursor;
    notifyListeners();
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
          if (message.id == pendingId) sent else message,
      ];
      return true;
    } on ApiException catch (error) {
      _messages[conversationId] = messagesFor(
        conversationId,
      ).where((message) => message.id != pendingId).toList(growable: false);
      _errorMessage = error.message;
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> setMuted(ChatConversation conversation, bool enabled) async {
    await _api.setMuted(conversation.id, enabled);
    await loadConversations();
  }

  Future<void> setBlocked(ChatConversation conversation, bool enabled) async {
    await _api.setBlocked(conversation.id, enabled);
    await loadConversations();
  }

  Future<void> report(ChatConversation conversation, String reason) async {
    await _api.report(conversation.id, reason);
  }

  void _receive(ChatMessage message) {
    final current = messagesFor(message.conversationId);
    if (current.any((item) => item.id == message.id)) return;
    _messages[message.conversationId] = [...current, message];
    notifyListeners();
  }

  void _receiveRead(String conversationId, String userId) {
    if (conversationId.isEmpty || userId.isEmpty) return;
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
    _realtime.dispose();
    super.dispose();
  }
}
