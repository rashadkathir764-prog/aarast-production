import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/api_config.dart';
import '../../../core/storage/auth_storage.dart';
import '../models/chat_models.dart';

class ChatRealtimeClient {
  ChatRealtimeClient(this._authStorage);

  final AuthStorage _authStorage;
  io.Socket? _socket;

  Future<void> connect({
    required void Function(ChatMessage message) onMessage,
    required void Function(String conversationId, String userId) onRead,
  }) async {
    if (_socket?.connected == true) return;
    final token = await _authStorage.readAccessToken();
    if (token == null || token.isEmpty) return;
    final socket = io.io(
      '${ApiConfig.baseUrl}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );
    final ready = Completer<void>();
    socket.on('chat:ready', (_) {
      if (!ready.isCompleted) ready.complete();
    });
    socket.onConnectError((error) {
      if (!ready.isCompleted) ready.completeError(error ?? 'تعذر الاتصال');
    });
    socket.on('conversation:message', (value) {
      final json = _json(value);
      if (json != null) onMessage(ChatMessage.fromJson(json));
    });
    socket.on('conversation:read', (value) {
      final json = _json(value);
      if (json == null) return;
      onRead(
        json['conversationId']?.toString() ?? '',
        json['userId']?.toString() ?? '',
      );
    });
    socket.connect();
    _socket = socket;
    await ready.future.timeout(const Duration(seconds: 10));
  }

  void join(String conversationId) {
    _socket?.emit('conversation:join', {'conversationId': conversationId});
  }

  void markRead(String conversationId) {
    _socket?.emit('conversation:read', {'conversationId': conversationId});
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
  }
}

Map<String, dynamic>? _json(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
