import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../../core/config/api_config.dart';
import '../../../core/storage/auth_storage.dart';
import '../models/chat_models.dart';

abstract interface class ChatSocketConnection {
  bool get connected;

  void connect();

  void dispose();

  void emit(String event, [Object? data]);

  void on(String event, void Function(Object?) handler);

  void onConnectError(void Function(Object?) handler);

  void onDisconnect(void Function(Object?) handler);
}

typedef ChatSocketFactory =
    ChatSocketConnection Function(String url, Map<String, dynamic> options);

class ChatRealtimeClient {
  ChatRealtimeClient(
    this._authStorage, {
    ChatSocketFactory? socketFactory,
    this.reconnectDelay = const Duration(seconds: 2),
  }) : _socketFactory = socketFactory ?? _defaultSocketFactory;

  final AuthStorage _authStorage;
  final ChatSocketFactory _socketFactory;
  final Duration reconnectDelay;
  final Set<String> _desiredConversationIds = {};

  ChatSocketConnection? _socket;
  Timer? _reconnectTimer;
  Future<void>? _connectFuture;
  void Function(ChatMessage message)? _onMessage;
  void Function(String conversationId, String userId, DateTime? lastReadAt)?
  _onRead;
  bool _stopped = true;

  Set<String> get desiredConversationIds =>
      Set<String>.unmodifiable(_desiredConversationIds);

  Future<void> connect({
    required void Function(ChatMessage message) onMessage,
    required void Function(
      String conversationId,
      String userId,
      DateTime? lastReadAt,
    )
    onRead,
  }) {
    _onMessage = onMessage;
    _onRead = onRead;
    _stopped = false;
    if (_socket?.connected == true) return Future.value();
    final active = _connectFuture;
    if (active != null) return active;

    final future = _openSocket();
    _connectFuture = future;
    return future.whenComplete(() {
      if (identical(_connectFuture, future)) _connectFuture = null;
    });
  }

  Future<void> _openSocket() async {
    final token = await _authStorage.readAccessToken();
    if (_stopped || token == null || token.isEmpty) return;

    final previous = _socket;
    _socket = null;
    previous?.dispose();
    final ready = Completer<void>();
    final socket = _socketFactory(
      '${ApiConfig.baseUrl}/chat',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuthFn((callback) {
            unawaited(
              _authStorage.readAccessToken().then((latestToken) {
                callback({'token': latestToken ?? ''});
              }),
            );
          })
          .enableForceNew()
          .disableReconnection()
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;

    socket.on('chat:ready', (_) {
      if (_stopped || !identical(_socket, socket)) return;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      for (final conversationId in _desiredConversationIds) {
        _emitJoin(socket, conversationId);
      }
      if (!ready.isCompleted) ready.complete();
    });
    socket.onConnectError((error) {
      if (!ready.isCompleted) {
        ready.completeError(error ?? 'تعذر الاتصال');
      }
      _scheduleReconnect();
    });
    socket.onDisconnect((_) {
      if (identical(_socket, socket)) _scheduleReconnect();
    });
    socket.on('conversation:message', (value) {
      final json = _json(value);
      if (json != null) _onMessage?.call(ChatMessage.fromJson(json));
    });
    socket.on('conversation:read', (value) {
      final json = _json(value);
      if (json == null) return;
      _onRead?.call(
        json['conversationId']?.toString() ?? '',
        json['userId']?.toString() ?? '',
        DateTime.tryParse(json['lastReadAt']?.toString() ?? ''),
      );
    });
    socket.connect();

    try {
      await ready.future.timeout(const Duration(seconds: 10));
    } on Object {
      _scheduleReconnect();
      rethrow;
    }
  }

  void join(String conversationId) {
    final normalized = conversationId.trim();
    if (normalized.isEmpty) return;
    _desiredConversationIds.add(normalized);
    final socket = _socket;
    if (socket?.connected == true) _emitJoin(socket!, normalized);
  }

  void markRead(String conversationId) {
    final socket = _socket;
    if (socket?.connected != true) return;
    socket!.emit('conversation:read', {'conversationId': conversationId});
  }

  void _emitJoin(ChatSocketConnection socket, String conversationId) {
    socket.emit('conversation:join', {'conversationId': conversationId});
  }

  void _scheduleReconnect() {
    if (_stopped || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(reconnectDelay, () {
      if (_stopped || _onMessage == null || _onRead == null) return;
      _connectFuture = null;
      unawaited(
        connect(onMessage: _onMessage!, onRead: _onRead!).catchError((_) {}),
      );
    });
  }

  void reset() {
    _stopped = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectFuture = null;
    _desiredConversationIds.clear();
    _socket?.dispose();
    _socket = null;
  }

  void dispose() => reset();
}

class _SocketIoConnection implements ChatSocketConnection {
  _SocketIoConnection(this._socket);

  final io.Socket _socket;

  @override
  bool get connected => _socket.connected;

  @override
  void connect() => _socket.connect();

  @override
  void dispose() => _socket.dispose();

  @override
  void emit(String event, [Object? data]) => _socket.emit(event, data);

  @override
  void on(String event, void Function(Object?) handler) {
    _socket.on(event, handler);
  }

  @override
  void onConnectError(void Function(Object?) handler) {
    _socket.onConnectError(handler);
  }

  @override
  void onDisconnect(void Function(Object?) handler) {
    _socket.onDisconnect(handler);
  }
}

ChatSocketConnection _defaultSocketFactory(
  String url,
  Map<String, dynamic> options,
) {
  return _SocketIoConnection(io.io(url, options));
}

Map<String, dynamic>? _json(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
