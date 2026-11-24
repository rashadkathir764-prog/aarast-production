import 'dart:async';

import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/chat/data/chat_realtime_client.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AuthStorage storage;
  late _FakeSocketFactory factory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    storage = AuthStorage(preferences);
    await _saveSession(storage, userId: 'user-1', token: 'token-1');
    factory = _FakeSocketFactory();
  });

  test(
    'room requested before ready joins on ready and after reconnect',
    () async {
      final client = ChatRealtimeClient(
        storage,
        socketFactory: factory.call,
        reconnectDelay: Duration.zero,
      );
      final connecting = client.connect(
        onMessage: (_) {},
        onMessageAvailable: (_, _) {},
        onActivityAvailable: (_) {},
        onPermissionRevoked: (_) {},
        onRead: (_, _, _) {},
      );
      client.join('conversation-1');
      await Future<void>.delayed(Duration.zero);
      expect(factory.sockets.single.emitted, isEmpty);

      factory.sockets.single.serverEvent('chat:ready', {'userId': 'user-1'});
      await connecting;
      expect(factory.sockets.single.emitted, hasLength(1));
      expect(factory.sockets.single.emitted.single.$1, 'conversation:join');
      expect(factory.sockets.single.emitted.single.$2, {
        'conversationId': 'conversation-1',
      });

      factory.sockets.single.serverDisconnect('transport close');
      await pumpEventQueue();
      expect(factory.sockets, hasLength(2));

      factory.sockets.last.serverEvent('chat:ready', {'userId': 'user-1'});
      await Future<void>.delayed(Duration.zero);
      expect(factory.sockets.last.emitted, hasLength(1));
      expect(factory.sockets.last.emitted.single.$1, 'conversation:join');
      expect(factory.sockets.last.emitted.single.$2, {
        'conversationId': 'conversation-1',
      });

      client.dispose();
    },
  );

  test('reconnect authentication reads the latest access token', () async {
    final client = ChatRealtimeClient(
      storage,
      socketFactory: factory.call,
      reconnectDelay: Duration.zero,
    );
    final connecting = client.connect(
      onMessage: (_) {},
      onMessageAvailable: (_, _) {},
      onActivityAvailable: (_) {},
      onPermissionRevoked: (_) {},
      onRead: (_, _, _) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(await factory.sockets.single.resolveAuth(), {'token': 'token-1'});
    factory.sockets.single.serverEvent('chat:ready', {'userId': 'user-1'});
    await connecting;

    await _saveSession(storage, userId: 'user-1', token: 'token-2');
    factory.sockets.single.serverDisconnect('transport close');
    await pumpEventQueue();

    expect(await factory.sockets.last.resolveAuth(), {'token': 'token-2'});
    client.dispose();
  });

  test(
    'disposing an old socket during reconnect does not schedule another one',
    () async {
      final client = ChatRealtimeClient(
        storage,
        socketFactory: factory.call,
        reconnectDelay: Duration.zero,
      );
      final connecting = client.connect(
        onMessage: (_) {},
        onMessageAvailable: (_, _) {},
        onActivityAvailable: (_) {},
        onPermissionRevoked: (_) {},
        onRead: (_, _, _) {},
      );
      await Future<void>.delayed(Duration.zero);
      factory.sockets.single.serverEvent('chat:ready', {'userId': 'user-1'});
      await connecting;

      factory.sockets.single.serverDisconnect('transport close');
      await pumpEventQueue();

      expect(factory.sockets, hasLength(2));
      await pumpEventQueue();
      expect(factory.sockets, hasLength(2));
      client.dispose();
    },
  );

  test('reset cancels reconnect and clears requested rooms', () async {
    final client = ChatRealtimeClient(
      storage,
      socketFactory: factory.call,
      reconnectDelay: Duration.zero,
    );
    final connecting = client.connect(
      onMessage: (_) {},
      onMessageAvailable: (_, _) {},
      onActivityAvailable: (_) {},
      onPermissionRevoked: (_) {},
      onRead: (_, _, _) {},
    );
    client.join('conversation-1');
    await Future<void>.delayed(Duration.zero);
    factory.sockets.single.serverEvent('chat:ready', {'userId': 'user-1'});
    await connecting;

    client.reset();
    factory.sockets.single.serverDisconnect('transport close');
    await pumpEventQueue();

    expect(factory.sockets, hasLength(1));
    expect(client.desiredConversationIds, isEmpty);
  });

  test(
    'durable message availability event exposes recovery identifiers',
    () async {
      String? conversationId;
      String? messageId;
      final client = ChatRealtimeClient(storage, socketFactory: factory.call);
      final connecting = client.connect(
        onMessage: (_) {},
        onMessageAvailable: (conversation, message) {
          conversationId = conversation;
          messageId = message;
        },
        onActivityAvailable: (_) {},
        onPermissionRevoked: (_) {},
        onRead: (_, _, _) {},
      );
      await Future<void>.delayed(Duration.zero);
      final socket = factory.sockets.single;
      socket.serverEvent('chat:ready', {'userId': 'user-1'});
      await connecting;
      socket.serverEvent('conversation:message-available', {
        'conversationId': 'conversation-1',
        'messageId': 'message-1',
      });

      expect(conversationId, 'conversation-1');
      expect(messageId, 'message-1');
      client.dispose();
    },
  );

  // RA-MO-365: the socket came back every two seconds whatever happened, and
  // went on in the background; without a connection it woke the radio for
  // nothing.
  testWidgets('a server that keeps refusing is tried further apart, at most '
      'a minute apart', (tester) async {
    final client = ChatRealtimeClient(
      storage,
      socketFactory: factory.call,
      reconnectDelay: const Duration(seconds: 1),
      jitter: () => 0.999,
    );
    unawaited(
      client
          .connect(
            onMessage: (_) {},
            onMessageAvailable: (_, _) {},
            onActivityAvailable: (_) {},
            onPermissionRevoked: (_) {},
            onRead: (_, _, _) {},
          )
          .catchError((_) {}),
    );
    await tester.pump();
    final opened = <int>[0];
    var seconds = 0;
    while (factory.sockets.length < 12) {
      if (factory.sockets.length > opened.length) opened.add(seconds);
      factory.sockets.last.serverEvent('connect_error', 'offline');
      await tester.pump(const Duration(seconds: 1));
      seconds++;
      if (seconds > 1000) fail('no socket opened again');
    }
    opened.add(seconds);
    final gaps = [
      for (var i = 1; i < opened.length; i++) opened[i] - opened[i - 1],
    ];
    expect(gaps.first, lessThanOrEqualTo(2));
    for (var i = 1; i < gaps.length; i++) {
      expect(gaps[i], greaterThanOrEqualTo(gaps[i - 1]), reason: '$gaps');
    }
    expect(gaps.last, inInclusiveRange(30, 61), reason: '$gaps');
    client.dispose();
    // The last attempt's wait for «ready» runs out with nothing after it.
    await tester.pump(const Duration(seconds: 11));
  });

  test('the jittered wait doubles from the base and stops at a minute', () {
    var draw = 0.0;
    final backoff = ChatReconnectBackoff(
      base: const Duration(seconds: 2),
      jitter: () => draw,
    );
    // Equal jitter: half the step is kept, the other half drawn.
    draw = 0;
    expect(backoff.next(), const Duration(seconds: 1));
    draw = 0.999999;
    expect(backoff.next().inMilliseconds, closeTo(4000, 1));
    for (var i = 0; i < 20; i++) {
      backoff.next();
    }
    expect(backoff.next().inMilliseconds, closeTo(60000, 1));
    draw = 0;
    expect(backoff.next(), const Duration(seconds: 30));
    backoff.reset();
    expect(backoff.next(), const Duration(seconds: 1));
  });

  test('the background closes the socket; the return opens it, joins the '
      'rooms and reads what came meanwhile', () async {
    var caughtUp = 0;
    final client = ChatRealtimeClient(
      storage,
      socketFactory: factory.call,
      reconnectDelay: Duration.zero,
    )..onReconnected = () => caughtUp++;
    final connecting = client.connect(
      onMessage: (_) {},
      onMessageAvailable: (_, _) {},
      onActivityAvailable: (_) {},
      onPermissionRevoked: (_) {},
      onRead: (_, _, _) {},
    );
    client.join('conversation-1');
    await Future<void>.delayed(Duration.zero);
    factory.sockets.single.serverEvent('chat:ready', {'userId': 'user-1'});
    await connecting;
    expect(caughtUp, 0, reason: 'the first connection has nothing to catch');

    client.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(factory.sockets.single.connected, isFalse);
    await pumpEventQueue();
    expect(factory.sockets, hasLength(1), reason: 'no reconnect while away');
    client.join('conversation-2');

    client.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(factory.sockets, hasLength(2));
    factory.sockets.last.serverEvent('chat:ready', {'userId': 'user-1'});
    expect(factory.sockets.last.emitted.map((event) => event.$2), [
      {'conversationId': 'conversation-1'},
      {'conversationId': 'conversation-2'},
    ]);
    expect(caughtUp, 1);
    client.dispose();
  });

  test('a session started in the background waits for the return', () async {
    final client = ChatRealtimeClient(
      storage,
      socketFactory: factory.call,
      reconnectDelay: Duration.zero,
    );
    client.didChangeAppLifecycleState(AppLifecycleState.hidden);
    unawaited(
      client.connect(
        onMessage: (_) {},
        onMessageAvailable: (_, _) {},
        onActivityAvailable: (_) {},
        onPermissionRevoked: (_) {},
        onRead: (_, _, _) {},
      ),
    );
    await pumpEventQueue();
    expect(factory.sockets, isEmpty);
    client.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(factory.sockets, hasLength(1));
    client.dispose();
  });

  test('activity and permission events expose the conversation id', () async {
    String? activityConversationId;
    String? revokedConversationId;
    final client = ChatRealtimeClient(storage, socketFactory: factory.call);
    final connecting = client.connect(
      onMessage: (_) {},
      onMessageAvailable: (_, _) {},
      onActivityAvailable: (conversationId) {
        activityConversationId = conversationId;
      },
      onPermissionRevoked: (conversationId) {
        revokedConversationId = conversationId;
      },
      onRead: (_, _, _) {},
    );
    await Future<void>.delayed(Duration.zero);
    final socket = factory.sockets.single;
    socket.serverEvent('chat:ready', {'userId': 'user-1'});
    await connecting;

    socket.serverEvent('conversation:activity-available', {
      'conversationId': 'conversation-1',
    });
    socket.serverEvent('conversation:permission-revoked', {
      'conversationId': 'conversation-2',
    });

    expect(activityConversationId, 'conversation-1');
    expect(revokedConversationId, 'conversation-2');
    client.dispose();
  });
}

Future<void> _saveSession(
  AuthStorage storage, {
  required String userId,
  required String token,
}) {
  return storage.saveSession(
    accessToken: token,
    user: SafeUser(
      id: userId,
      name: 'مستخدم $userId',
      role: 'USER',
      status: 'ACTIVE',
    ),
  );
}

class _FakeSocketFactory {
  final List<_FakeSocket> sockets = [];

  ChatSocketConnection call(String url, Map<String, dynamic> options) {
    final socket = _FakeSocket(options);
    sockets.add(socket);
    return socket;
  }
}

class _FakeSocket implements ChatSocketConnection {
  _FakeSocket(this.options);

  final Map<String, dynamic> options;
  final Map<String, List<void Function(Object?)>> _handlers = {};
  final List<(String, Object?)> emitted = [];

  @override
  bool connected = false;

  @override
  void connect() {}

  @override
  void dispose() {
    serverDisconnect('client dispose');
  }

  @override
  void emit(String event, [Object? data]) {
    emitted.add((event, data));
  }

  @override
  void on(String event, void Function(Object?) handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
  }

  @override
  void onConnectError(void Function(Object?) handler) {
    on('connect_error', handler);
  }

  @override
  void onDisconnect(void Function(Object?) handler) {
    on('disconnect', handler);
  }

  void serverEvent(String event, Object? data) {
    if (event == 'chat:ready') connected = true;
    for (final handler in _handlers[event] ?? const []) {
      handler(data);
    }
  }

  void serverDisconnect(String reason) {
    connected = false;
    serverEvent('disconnect', reason);
  }

  Future<Map<String, dynamic>> resolveAuth() async {
    final completer = Completer<Map<String, dynamic>>();
    final auth = options['auth'] as Function;
    Function.apply(auth, [
      (Map<Object?, Object?> value) {
        completer.complete(Map<String, dynamic>.from(value));
      },
    ]);
    return completer.future;
  }
}
