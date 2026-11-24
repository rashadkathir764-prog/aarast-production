import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
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

/// How long the chat socket waits before trying again (RA-MO-365): the step
/// doubles from [base] with each attempt that fails and stops at [cap], and
/// half of it is drawn at random so phones cut off together do not all come
/// back in the same second. It came back every two seconds, for ever, and
/// without a connection kept waking the radio.
class ChatReconnectBackoff {
  ChatReconnectBackoff({
    required this.base,
    this.cap = const Duration(seconds: 60),
    double Function()? jitter,
  }) : _jitter = jitter ?? Random().nextDouble;

  final Duration base;
  final Duration cap;

  /// A draw in [0, 1).
  final double Function() _jitter;
  int _failures = 0;

  /// The wait before the next attempt; each call counts one failure.
  Duration next() {
    final factor = 1 << min(_failures, 20);
    _failures++;
    final step = min(base.inMicroseconds * factor, cap.inMicroseconds);
    return Duration(microseconds: step ~/ 2 + (step / 2 * _jitter()).floor());
  }

  /// A connection that came up: the next failure starts from [base] again.
  void reset() => _failures = 0;
}

/// The chat's live socket. It is closed while the app is in the background
/// and opened again on the return (RA-MO-365); what came while it was closed
/// is read through `onReconnected`.
class ChatRealtimeClient with WidgetsBindingObserver {
  ChatRealtimeClient(
    this._authStorage, {
    ChatSocketFactory? socketFactory,
    this.reconnectDelay = const Duration(seconds: 2),
    double Function()? jitter,
  }) : _socketFactory = socketFactory ?? _defaultSocketFactory,
       _backoff = ChatReconnectBackoff(base: reconnectDelay, jitter: jitter);

  final AuthStorage _authStorage;
  final ChatSocketFactory _socketFactory;

  /// The first wait after a lost connection; [ChatReconnectBackoff] grows it.
  final Duration reconnectDelay;
  final ChatReconnectBackoff _backoff;
  final Set<String> _desiredConversationIds = {};

  ChatSocketConnection? _socket;
  Timer? _reconnectTimer;
  Future<void>? _connectFuture;
  void Function(ChatMessage message)? _onMessage;
  void Function(String conversationId, String messageId)? _onMessageAvailable;
  void Function(String conversationId)? _onActivityAvailable;
  void Function(String conversationId)? _onPermissionRevoked;
  void Function(String conversationId, String userId, DateTime? lastReadAt)?
  _onRead;
  bool _stopped = true;

  /// The app is in the background: no socket is held and none is opened.
  bool _away = false;

  /// A socket of this session was ready once, so the next ready one comes
  /// after a gap.
  bool _wasReady = false;

  Set<String> get desiredConversationIds =>
      Set<String>.unmodifiable(_desiredConversationIds);

  /// Runs when a socket is ready again after one was lost (a dropped
  /// connection, the app back from the background): the events of the gap
  /// never reached this phone.
  void Function()? onReconnected;

  Future<void> connect({
    required void Function(ChatMessage message) onMessage,
    required void Function(String conversationId, String messageId)
    onMessageAvailable,
    required void Function(String conversationId) onActivityAvailable,
    required void Function(String conversationId) onPermissionRevoked,
    required void Function(
      String conversationId,
      String userId,
      DateTime? lastReadAt,
    )
    onRead,
  }) {
    _onMessage = onMessage;
    _onMessageAvailable = onMessageAvailable;
    _onActivityAvailable = onActivityAvailable;
    _onPermissionRevoked = onPermissionRevoked;
    _onRead = onRead;
    _stopped = false;
    return _connect();
  }

  Future<void> _connect() {
    if (_socket?.connected == true) return Future.value();
    final active = _connectFuture;
    if (active != null) return active;

    final future = _openSocket();
    _connectFuture = future;
    return future.whenComplete(() {
      if (identical(_connectFuture, future)) _connectFuture = null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _comeBack();
      case AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached:
        _goAway();
      // A dialog of the phone's over the app, the shade pulled: still here.
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _goAway() {
    if (_away) return;
    _away = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _connectFuture = null;
    final socket = _socket;
    _socket = null;
    socket?.dispose();
  }

  void _comeBack() {
    if (!_away) return;
    _away = false;
    _backoff.reset();
    if (_stopped || _onMessage == null) return;
    unawaited(_connect().catchError((_) {}));
  }

  Future<void> _openSocket() async {
    final token = await _authStorage.readAccessToken();
    if (_stopped || _away || token == null || token.isEmpty) return;

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
      _backoff.reset();
      for (final conversationId in _desiredConversationIds) {
        _emitJoin(socket, conversationId);
      }
      if (!ready.isCompleted) ready.complete();
      if (_wasReady) onReconnected?.call();
      _wasReady = true;
    });
    socket.onConnectError((error) {
      if (!ready.isCompleted) {
        ready.completeError(error ?? 'ما وصلنا');
      }
      if (identical(_socket, socket)) _scheduleReconnect();
    });
    socket.onDisconnect((_) {
      if (identical(_socket, socket)) _scheduleReconnect();
    });
    socket.on('conversation:message', (value) {
      final json = _json(value);
      if (json != null) _onMessage?.call(ChatMessage.fromJson(json));
    });
    socket.on('conversation:message-available', (value) {
      final json = _json(value);
      if (json == null) return;
      _onMessageAvailable?.call(
        json['conversationId']?.toString() ?? '',
        json['messageId']?.toString() ?? '',
      );
    });
    socket.on('conversation:event', (value) {
      final json = _json(value);
      if (json == null) return;
      _onActivityAvailable?.call(json['conversationId']?.toString() ?? '');
    });
    socket.on('conversation:activity-available', (value) {
      final json = _json(value);
      if (json == null) return;
      _onActivityAvailable?.call(json['conversationId']?.toString() ?? '');
    });
    socket.on('conversation:permission-revoked', (value) {
      final json = _json(value);
      if (json == null) return;
      _onPermissionRevoked?.call(json['conversationId']?.toString() ?? '');
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
    if (_stopped || _away || _reconnectTimer?.isActive == true) return;
    _reconnectTimer = Timer(_backoff.next(), () {
      if (_stopped || _away || _onMessage == null) return;
      _connectFuture = null;
      // A failed attempt schedules the next one itself.
      unawaited(_connect().catchError((_) {}));
    });
  }

  void reset() {
    _stopped = true;
    _wasReady = false;
    _backoff.reset();
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
