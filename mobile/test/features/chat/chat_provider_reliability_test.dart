import 'dart:async';

import 'package:aarast_mobile/core/media/media_upload_api.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/models/safe_user.dart';
import 'package:aarast_mobile/features/chat/data/chat_api.dart';
import 'package:aarast_mobile/features/chat/data/chat_realtime_client.dart';
import 'package:aarast_mobile/features/chat/models/chat_models.dart';
import 'package:aarast_mobile/features/chat/providers/chat_provider.dart';
import 'package:aarast_mobile/features/chat/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AuthStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    storage = AuthStorage(preferences);
    await storage.saveSession(
      accessToken: 'access-token',
      user: const SafeUser(
        id: 'user-1',
        name: 'المستخدم',
        role: 'USER',
        status: 'ACTIVE',
      ),
    );
  });

  test(
    'opening a conversation starts realtime even without inbox initialization',
    () async {
      final api = _FakeChatApi();
      final realtime = _FakeRealtimeClient(storage);
      final chat = ChatProvider(
        api: api,
        realtime: realtime,
        authStorage: storage,
      );

      await chat.openConversation('conversation-1');
      await Future<void>.delayed(Duration.zero);

      expect(realtime.connectCalls, 1);
      chat.dispose();
    },
  );

  test('direct conversation open loads its inbox metadata', () async {
    final api = _FakeChatApi(conversations: [_conversation(blocked: true)]);
    final realtime = _FakeRealtimeClient(storage);
    final chat = ChatProvider(
      api: api,
      realtime: realtime,
      authStorage: storage,
    );

    await chat.openConversation('conversation-1');

    expect(chat.conversations.single.id, 'conversation-1');
    expect(chat.conversations.single.blocked, isTrue);
    chat.dispose();
  });

  test(
    'conversation joins after a delayed realtime connection becomes ready',
    () async {
      final api = _FakeChatApi();
      final realtime = _FakeRealtimeClient(storage, delayConnection: true);
      final chat = ChatProvider(
        api: api,
        realtime: realtime,
        authStorage: storage,
      );

      final initialization = chat.initialize();
      await initialization;
      await chat.openConversation('conversation-1');
      expect(realtime.joinedConversationIds, isEmpty);

      realtime.completeConnection();
      await Future<void>.delayed(Duration.zero);

      expect(realtime.joinedConversationIds, ['conversation-1']);
      chat.dispose();
    },
  );

  test('sender realtime echo and REST response produce one message', () async {
    final realtime = _FakeRealtimeClient(storage);
    final api = _FakeChatApi();
    api.onSend = (message) => realtime.emitMessage(message);
    final chat = ChatProvider(
      api: api,
      realtime: realtime,
      authStorage: storage,
    );
    await chat.initialize();
    await Future<void>.delayed(Duration.zero);
    await chat.openConversation('conversation-1');

    final sent = await chat.send('conversation-1', 'رسالة واحدة');

    expect(sent, isTrue);
    expect(
      chat
          .messagesFor('conversation-1')
          .where((item) => item.id == 'message-1'),
      hasLength(1),
    );
    chat.dispose();
  });

  test('incoming realtime message updates inbox unread state', () async {
    final realtime = _FakeRealtimeClient(storage);
    final api = _FakeChatApi(conversations: [_conversation()]);
    final chat = ChatProvider(
      api: api,
      realtime: realtime,
      authStorage: storage,
    );
    await chat.initialize();
    await Future<void>.delayed(Duration.zero);

    realtime.emitMessage(_message(senderUserId: 'provider-user-1'));

    expect(chat.conversations.single.unreadCount, 1);
    expect(chat.conversations.single.lastMessage?.id, 'message-1');
    chat.dispose();
  });

  test('incoming message in the open conversation is marked read', () async {
    final realtime = _FakeRealtimeClient(storage);
    final api = _FakeChatApi(conversations: [_conversation()]);
    final chat = ChatProvider(
      api: api,
      realtime: realtime,
      authStorage: storage,
    );
    await chat.initialize();
    await Future<void>.delayed(Duration.zero);
    await chat.openConversation('conversation-1');
    expect(api.markReadCalls, 1);

    realtime.emitMessage(_message(senderUserId: 'provider-user-1'));
    await Future<void>.delayed(Duration.zero);

    expect(api.markReadCalls, 2);
    expect(chat.conversations.single.unreadCount, 0);
    chat.dispose();
  });

  test(
    'account switch clears private chat state and restarts realtime',
    () async {
      final realtime = _FakeRealtimeClient(storage);
      final api = _FakeChatApi(conversations: [_conversation()]);
      final chat = ChatProvider(
        api: api,
        realtime: realtime,
        authStorage: storage,
      );
      await chat.initialize();
      await Future<void>.delayed(Duration.zero);
      await chat.openConversation('conversation-1');
      expect(chat.conversations, isNotEmpty);

      chat.syncSessionUser(null);

      expect(chat.currentUserId, isNull);
      expect(chat.conversations, isEmpty);
      expect(chat.messagesFor('conversation-1'), isEmpty);
      expect(realtime.resetCalls, 1);

      chat.syncSessionUser('user-2');
      await Future<void>.delayed(Duration.zero);

      expect(chat.currentUserId, 'user-2');
      expect(realtime.connectCalls, 2);
      chat.dispose();
    },
  );

  testWidgets('chat screen loads message history older than the first page', (
    tester,
  ) async {
    final realtime = _FakeRealtimeClient(storage);
    final api = _FakeChatApi(
      conversations: [_conversation()],
      initialPage: ChatMessagePage(
        items: [_message(id: 'message-2', body: 'الرسالة الأحدث')],
        nextCursor: 'message-1',
      ),
      olderPage: ChatMessagePage(
        items: [_message(id: 'message-1', body: 'الرسالة الأقدم')],
      ),
    );
    final chat = ChatProvider(
      api: api,
      realtime: realtime,
      authStorage: storage,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ChatProvider>.value(
        value: chat,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ChatScreen(conversationId: 'conversation-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat-load-older')), findsOneWidget);
    await tester.tap(find.byKey(const Key('chat-load-older')));
    await tester.pumpAndSettle();

    expect(find.text('الرسالة الأقدم'), findsOneWidget);
    expect(find.text('الرسالة الأحدث'), findsOneWidget);
    chat.dispose();
  });

  testWidgets('chat explains when the counterpart owns the block', (
    tester,
  ) async {
    final realtime = _FakeRealtimeClient(storage);
    final api = _FakeChatApi(
      conversations: [_conversation(blocked: true, blockedByCounterpart: true)],
    );
    final chat = ChatProvider(
      api: api,
      realtime: realtime,
      authStorage: storage,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ChatProvider>.value(
        value: chat,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ChatScreen(conversationId: 'conversation-1'),
        ),
      ),
    );
    await chat.initialize();
    await tester.pumpAndSettle();

    expect(
      find.text('أوقف الطرف الآخر المحادثة. لا يمكن إرسال رسائل جديدة الآن.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    chat.dispose();
  });

  testWidgets('failed send action shows the backend error', (tester) async {
    final realtime = _FakeRealtimeClient(storage);
    final api = _FakeChatApi(
      conversations: [_conversation()],
      sendError: const ApiException('تعذر إرسال الرسالة الآن.'),
    );
    final chat = ChatProvider(
      api: api,
      realtime: realtime,
      authStorage: storage,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ChatProvider>.value(
        value: chat,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ChatScreen(conversationId: 'conversation-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'رسالة لن تصل');
    await tester.tap(find.byIcon(LucideIcons.send));
    await tester.pumpAndSettle();

    expect(find.text('تعذر إرسال الرسالة الآن.'), findsOneWidget);
    expect(chat.messagesFor('conversation-1'), isEmpty);
    chat.dispose();
  });

  testWidgets(
    'chat shows a truthful read receipt for the latest sent message',
    (tester) async {
      final realtime = _FakeRealtimeClient(storage);
      final api = _FakeChatApi(
        conversations: [
          _conversation(counterpartLastReadAt: DateTime.utc(2026, 7, 7, 12, 1)),
        ],
        initialPage: ChatMessagePage(items: [_message(senderUserId: 'user-1')]),
      );
      final chat = ChatProvider(
        api: api,
        realtime: realtime,
        authStorage: storage,
      );

      await chat.initialize();
      await tester.pumpWidget(
        ChangeNotifierProvider<ChatProvider>.value(
          value: chat,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ChatScreen(conversationId: 'conversation-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تمت القراءة'), findsOneWidget);
      chat.dispose();
    },
  );

  test('realtime read receipt updates sent message state', () async {
    final realtime = _FakeRealtimeClient(storage);
    final api = _FakeChatApi(conversations: [_conversation()]);
    final chat = ChatProvider(
      api: api,
      realtime: realtime,
      authStorage: storage,
    );
    await chat.initialize();
    await Future<void>.delayed(Duration.zero);
    final sent = _message(senderUserId: 'user-1');

    realtime.emitRead(
      'conversation-1',
      'provider-user-1',
      DateTime.utc(2026, 7, 7, 12, 1),
    );

    expect(chat.isMessageRead(sent), isTrue);
    chat.dispose();
  });

  test('messages received after leaving the chat remain unread', () async {
    final realtime = _FakeRealtimeClient(storage);
    final api = _FakeChatApi(conversations: [_conversation()]);
    final chat = ChatProvider(
      api: api,
      realtime: realtime,
      authStorage: storage,
    );
    await chat.initialize();
    await Future<void>.delayed(Duration.zero);
    await chat.openConversation('conversation-1');
    chat.closeConversation('conversation-1');

    realtime.emitMessage(_message());
    await Future<void>.delayed(Duration.zero);

    expect(api.markReadCalls, 1);
    expect(chat.conversations.single.unreadCount, 1);
    chat.dispose();
  });

  test(
    'failed block action returns false and exposes a user-facing error',
    () async {
      final realtime = _FakeRealtimeClient(storage);
      final api = _FakeChatApi(
        conversations: [_conversation()],
        actionError: const ApiException('تعذر تحديث الحظر الآن.'),
      );
      final chat = ChatProvider(
        api: api,
        realtime: realtime,
        authStorage: storage,
      );
      await chat.initialize();

      final changed = await chat.setBlocked(chat.conversations.single, true);

      expect(changed, isFalse);
      expect(chat.errorMessage, 'تعذر تحديث الحظر الآن.');
      chat.dispose();
    },
  );
}

ChatConversation _conversation({
  bool blocked = false,
  bool blockedByMe = false,
  bool blockedByCounterpart = false,
  DateTime? counterpartLastReadAt,
}) => ChatConversation(
  id: 'conversation-1',
  quoteRequestId: 'quote-1',
  counterpart: const ChatUser(id: 'provider-user-1', name: 'المزوّد'),
  unreadCount: 0,
  muted: false,
  blocked: blocked,
  blockedByMe: blockedByMe,
  blockedByCounterpart: blockedByCounterpart,
  counterpartLastReadAt: counterpartLastReadAt,
  createdAt: DateTime.utc(2026, 7, 7),
  updatedAt: DateTime.utc(2026, 7, 7),
);

ChatMessage _message({
  String id = 'message-1',
  String senderUserId = 'provider-user-1',
  String body = 'رسالة واحدة',
}) => ChatMessage(
  id: id,
  conversationId: 'conversation-1',
  senderUserId: senderUserId,
  body: body,
  createdAt: DateTime.utc(2026, 7, 7, 12),
);

class _FakeChatApi extends ChatApi {
  _FakeChatApi({
    this.conversations = const [],
    this.initialPage = const ChatMessagePage(items: []),
    this.olderPage = const ChatMessagePage(items: []),
    this.actionError,
    this.sendError,
  }) : super(ApiClient(tokenProvider: () async => null));

  final List<ChatConversation> conversations;
  final ChatMessagePage initialPage;
  final ChatMessagePage olderPage;
  final ApiException? actionError;
  final ApiException? sendError;
  void Function(ChatMessage message)? onSend;
  int markReadCalls = 0;

  @override
  Future<List<ChatConversation>> listConversations() async => conversations;

  @override
  Future<ChatMessagePage> messages(
    String conversationId, {
    String? cursor,
  }) async => cursor == null ? initialPage : olderPage;

  @override
  Future<ChatMessage> send(
    String conversationId, {
    required String body,
    List<MediaUploadTicket> attachments = const [],
  }) async {
    if (sendError != null) throw sendError!;
    final message = _message(senderUserId: 'user-1');
    onSend?.call(message);
    return message;
  }

  @override
  Future<void> markRead(String conversationId) async {
    markReadCalls += 1;
  }

  @override
  Future<void> setBlocked(String conversationId, bool enabled) async {
    if (actionError != null) throw actionError!;
  }
}

class _FakeRealtimeClient extends ChatRealtimeClient {
  _FakeRealtimeClient(super.authStorage, {this.delayConnection = false});

  final bool delayConnection;
  final List<String> joinedConversationIds = [];
  final Completer<void> _connection = Completer<void>();
  void Function(ChatMessage message)? _onMessage;
  void Function(String conversationId, String userId, DateTime? lastReadAt)?
  _onRead;
  bool _connected = false;
  int connectCalls = 0;
  int resetCalls = 0;

  @override
  Future<void> connect({
    required void Function(ChatMessage message) onMessage,
    required void Function(String conversationId, String messageId)
    onMessageAvailable,
    required void Function(
      String conversationId,
      String userId,
      DateTime? lastReadAt,
    )
    onRead,
  }) async {
    connectCalls += 1;
    _onMessage = onMessage;
    _onRead = onRead;
    if (delayConnection) {
      await _connection.future;
    }
    _connected = true;
  }

  @override
  void join(String conversationId) {
    if (_connected && !joinedConversationIds.contains(conversationId)) {
      joinedConversationIds.add(conversationId);
    }
  }

  void completeConnection() {
    if (!_connection.isCompleted) _connection.complete();
  }

  void emitMessage(ChatMessage message) => _onMessage?.call(message);

  void emitRead(String conversationId, String userId, DateTime lastReadAt) {
    _onRead?.call(conversationId, userId, lastReadAt);
  }

  @override
  void reset() {
    resetCalls += 1;
    _connected = false;
    joinedConversationIds.clear();
  }
}
