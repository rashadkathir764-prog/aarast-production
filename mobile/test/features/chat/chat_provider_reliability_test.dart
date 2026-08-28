import 'package:aarast_mobile/core/media/media_upload_api.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/chat/data/chat_api.dart';
import 'package:aarast_mobile/features/chat/data/chat_realtime_client.dart';
import 'package:aarast_mobile/features/chat/models/chat_models.dart';
import 'package:aarast_mobile/features/chat/providers/chat_provider.dart';
import 'package:aarast_mobile/features/chat/screens/chat_screen.dart';
import 'package:aarast_mobile/features/chat/screens/quote_conversation_entry_screen.dart';
import 'package:aarast_mobile/features/chat/widgets/conversation_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

  test('chat API reads one inbox row per conversation with a cursor', () async {
    final client = _ConversationApiClient();
    final page = await ChatApi(client).listConversations(cursor: 'cursor-1');

    final uri = Uri.parse(client.lastPath!);
    expect(uri.path, '/api/v1/conversations');
    expect(uri.queryParameters['cursor'], 'cursor-1');
    expect(page.items.single.id, 'conversation-api');
    expect(page.items.single.quoteRequestCount, 2);
    expect(page.nextCursor, 'cursor-2');
  });

  test('quote entry uses the read-only conversation lookup endpoint', () async {
    final client = _ConversationApiClient();

    final conversation = await ChatApi(client).conversationForQuote('quote-1');

    expect(client.lastPath, '/api/v1/quote-requests/quote-1/conversation');
    expect(conversation.id, 'conversation-api');
  });

  test(
    'a resolved quote opens its conversation before timeline loading',
    () async {
      final api = _FakeChatApi(
        conversations: [_conversation(providerJoined: false, canSend: false)],
        timelineError: const ApiException(
          aarastBackendConnectionErrorMessage,
          isNetworkFailure: true,
        ),
        timelineFailuresRemaining: 1,
      );
      final chat = ChatProvider(
        api: api,
        realtime: _FakeRealtimeClient(storage),
        authStorage: storage,
      );

      final conversation = await chat.openQuote('quote-1');

      expect(conversation?.id, 'conversation-1');
      expect(conversation?.providerJoined, isFalse);
      expect(api.timelineCalls, 0);
      expect(chat.hasConversationLoadError('conversation-1'), isFalse);
      chat.dispose();
    },
  );

  test('conversation parser distinguishes PLAN and ACCOUNT scopes', () {
    final plan = ChatConversation.fromJson(_conversationJson());
    final account = ChatConversation.fromJson(
      _conversationJson(scope: 'ACCOUNT', weddingPlan: null),
    );

    expect(plan.scope, ChatConversationScope.plan);
    expect(plan.weddingPlan?.title, 'خطة رشا ومحمد');
    expect(plan.quoteRequestCount, 2);
    expect(account.scope, ChatConversationScope.account);
    expect(account.weddingPlan, isNull);
  });

  test(
    'conversation parser tolerates stale cache fields after unification',
    () {
      final conversation = ChatConversation.fromJson({
        'id': 'conversation-from-old-cache',
        'quoteRequestId': 'legacy-quote-id',
        'provider': {'id': 'provider-1', 'businessName': 'قاعة السعادة'},
        'createdAt': '2026-07-01T00:00:00.000Z',
        'updatedAt': '2026-07-01T00:00:00.000Z',
      });

      expect(conversation.id, 'conversation-from-old-cache');
      expect(conversation.scope, ChatConversationScope.plan);
      expect(conversation.quoteRequestCount, 0);
      expect(conversation.providerJoined, isFalse);
      expect(conversation.canSend, isFalse);
      expect(conversation.permissions.canManageProviders, isFalse);
    },
  );

  test('opening a conversation loads timeline and starts realtime', () async {
    final api = _FakeChatApi(
      initialTimeline: ChatTimelinePage(items: [_eventItem()]),
    );
    final realtime = _FakeRealtimeClient(storage);
    final chat = ChatProvider(
      api: api,
      realtime: realtime,
      authStorage: storage,
    );

    await chat.openConversation('conversation-1');
    await Future<void>.delayed(Duration.zero);

    expect(realtime.connectCalls, 1);
    expect(chat.timelineFor('conversation-1'), hasLength(1));
    expect(chat.quoteRequestsFor('conversation-1'), hasLength(2));
    chat.dispose();
  });

  test('inbox pagination appends conversations without duplicates', () async {
    final api = _FakeChatApi(
      conversationPage: ChatConversationPage(
        items: [_conversation(id: 'conversation-1')],
        nextCursor: 'conversation-1',
      ),
      olderConversationPage: ChatConversationPage(
        items: [
          _conversation(id: 'conversation-1'),
          _conversation(id: 'conversation-2'),
        ],
      ),
    );
    final chat = ChatProvider(
      api: api,
      realtime: _FakeRealtimeClient(storage),
      authStorage: storage,
    );

    await chat.loadConversations();
    await chat.loadMoreConversations();

    expect(chat.conversations.map((item) => item.id), [
      'conversation-1',
      'conversation-2',
    ]);
    expect(api.requestedConversationCursors, [null, 'conversation-1']);
    chat.dispose();
  });

  test('realtime message updates unread count and last activity', () async {
    final realtime = _FakeRealtimeClient(storage);
    final chat = ChatProvider(
      api: _FakeChatApi(conversations: [_conversation()]),
      realtime: realtime,
      authStorage: storage,
    );
    await chat.initialize();
    await Future<void>.delayed(Duration.zero);

    realtime.emitMessage(_message(createdAt: DateTime.utc(2026, 7, 8)));

    expect(chat.conversations.single.unreadMessageCount, 1);
    expect(chat.conversations.single.lastMessage?.id, 'message-1');
    expect(chat.conversations.single.lastActivityAt, DateTime.utc(2026, 7, 8));
    chat.dispose();
  });

  test('activity event refreshes the conversation timeline', () async {
    final realtime = _FakeRealtimeClient(storage);
    final api = _FakeChatApi(conversations: [_conversation()]);
    final chat = ChatProvider(
      api: api,
      realtime: realtime,
      authStorage: storage,
    );
    await chat.initialize();
    await Future<void>.delayed(Duration.zero);
    api.timelinePage = ChatTimelinePage(
      items: [_eventItem(type: 'QUOTE_OFFER_RECEIVED')],
    );

    realtime.emitActivity('conversation-1');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      chat.timelineFor('conversation-1').single.event?.type,
      'QUOTE_OFFER_RECEIVED',
    );
    chat.dispose();
  });

  test('permission revocation removes private conversation state', () async {
    final realtime = _FakeRealtimeClient(storage);
    final chat = ChatProvider(
      api: _FakeChatApi(conversations: [_conversation()]),
      realtime: realtime,
      authStorage: storage,
    );
    await chat.initialize();
    await chat.openConversation('conversation-1');

    realtime.emitPermissionRevoked('conversation-1');

    expect(chat.conversations, isEmpty);
    expect(chat.timelineFor('conversation-1'), isEmpty);
    expect(chat.errorMessage, 'تم سحب صلاحية الوصول إلى هذه المحادثة.');
    chat.dispose();
  });

  test('sender realtime echo and REST response produce one message', () async {
    final realtime = _FakeRealtimeClient(storage);
    final api = _FakeChatApi();
    api.onSend = realtime.emitMessage;
    final chat = ChatProvider(
      api: api,
      realtime: realtime,
      authStorage: storage,
    );
    await chat.initialize();
    await chat.openConversation('conversation-1');

    final sent = await chat.send('conversation-1', 'رسالة واحدة');

    expect(sent, isTrue);
    expect(
      chat
          .timelineFor('conversation-1')
          .where((item) => item.message?.id == 'message-1'),
      hasLength(1),
    );
    chat.dispose();
  });

  test(
    'session switch clears conversation, timeline and realtime rooms',
    () async {
      final realtime = _FakeRealtimeClient(storage);
      final chat = ChatProvider(
        api: _FakeChatApi(conversations: [_conversation()]),
        realtime: realtime,
        authStorage: storage,
      );
      await chat.initialize();
      await chat.openConversation('conversation-1');

      chat.syncSessionUser(null);

      expect(chat.conversations, isEmpty);
      expect(chat.timelineFor('conversation-1'), isEmpty);
      expect(realtime.resetCalls, 1);
      chat.dispose();
    },
  );

  testWidgets('timeline paginates older messages and events', (tester) async {
    final chat = ChatProvider(
      api: _FakeChatApi(
        conversations: [_conversation()],
        initialTimeline: ChatTimelinePage(
          items: [_messageItem(body: 'الرسالة الأحدث')],
          nextCursor: 'older',
        ),
        olderTimeline: ChatTimelinePage(
          items: [_eventItem(type: 'QUOTE_REQUEST_CREATED')],
        ),
      ),
      realtime: _FakeRealtimeClient(storage),
      authStorage: storage,
    );

    await tester.pumpWidget(_chatApp(chat));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chat-load-older')));
    await tester.pumpAndSettle();

    expect(find.text('الرسالة الأحدث'), findsOneWidget);
    expect(find.text('أُنشئ طلب عرض سعر'), findsOneWidget);
    chat.dispose();
  });

  testWidgets('timeline event opens its quote request context', (tester) async {
    final chat = ChatProvider(
      api: _FakeChatApi(
        conversations: [_conversation()],
        initialTimeline: ChatTimelinePage(
          items: [_eventItem(type: 'QUOTE_OFFER_RECEIVED')],
        ),
      ),
      realtime: _FakeRealtimeClient(storage),
      authStorage: storage,
    );
    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(
          path: '/chat',
          builder: (_, _) => const ChatScreen(conversationId: 'conversation-1'),
        ),
        GoRoute(
          path: '/wedding-plans/:id/providers',
          builder: (_, state) => Text(
            'quote:${state.uri.queryParameters['quoteId']}',
            textDirection: TextDirection.rtl,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ChatProvider>.value(
        value: chat,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('conversation-event-quote_offer_received')),
    );
    await tester.pumpAndSettle();

    expect(find.text('quote:quote-1'), findsOneWidget);
    chat.dispose();
  });

  testWidgets('conversation list opens the unified conversation id', (
    tester,
  ) async {
    final chat = ChatProvider(
      api: _FakeChatApi(conversations: [_conversation()]),
      realtime: _FakeRealtimeClient(storage),
      authStorage: storage,
    );
    final router = GoRouter(
      initialLocation: '/conversations',
      routes: [
        GoRoute(
          path: '/conversations',
          builder: (_, _) => const ConversationListView(),
        ),
        GoRoute(
          path: '/conversations/:id',
          builder: (_, state) => Text(
            'chat:${state.pathParameters['id']}',
            textDirection: TextDirection.rtl,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<ChatProvider>.value(
        value: chat,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('قاعة السعادة'));
    await tester.pumpAndSettle();

    expect(find.text('chat:conversation-1'), findsOneWidget);
    chat.dispose();
  });

  testWidgets('provider-not-joined state disables the composer truthfully', (
    tester,
  ) async {
    final chat = ChatProvider(
      api: _FakeChatApi(
        conversations: [_conversation(providerJoined: false, canSend: false)],
      ),
      realtime: _FakeRealtimeClient(storage),
      authStorage: storage,
    );

    await tester.pumpWidget(_chatApp(chat));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'المورد لم ينضم للمحادثة بعد. ستتمكن من الإرسال بعد ربط حسابه.',
      ),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNothing);
    chat.dispose();
  });

  testWidgets(
    'quote route opens provider-not-joined conversation in read-only mode',
    (tester) async {
      final api = _FakeChatApi(
        conversations: [_conversation(providerJoined: false, canSend: false)],
      );
      final chat = ChatProvider(
        api: api,
        realtime: _FakeRealtimeClient(storage),
        authStorage: storage,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<ChatProvider>.value(
          value: chat,
          child: const MaterialApp(
            home: QuoteConversationEntryScreen(quoteRequestId: 'quote-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(
        find.text(
          'المورد لم ينضم للمحادثة بعد. ستتمكن من الإرسال بعد ربط حسابه.',
        ),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(api.conversationForQuoteCalls, 1);
      expect(api.timelineCalls, 1);
      chat.dispose();
    },
  );

  testWidgets('retry reloads chat after one transient timeline failure', (
    tester,
  ) async {
    final api = _FakeChatApi(
      conversations: [_conversation()],
      initialTimeline: ChatTimelinePage(items: [_eventItem()]),
      timelineError: const ApiException(
        aarastBackendConnectionErrorMessage,
        isNetworkFailure: true,
      ),
      timelineFailuresRemaining: 1,
    );
    final chat = ChatProvider(
      api: api,
      realtime: _FakeRealtimeClient(storage),
      authStorage: storage,
    );

    await tester.pumpWidget(_chatApp(chat));
    await tester.pumpAndSettle();

    expect(find.text('تعذر تحميل المحادثة'), findsOneWidget);
    expect(find.text('حاول مرة أخرى'), findsOneWidget);

    await tester.tap(find.text('حاول مرة أخرى'));
    await tester.pumpAndSettle();

    expect(find.text('أُنشئ طلب عرض سعر'), findsOneWidget);
    expect(chat.hasConversationLoadError('conversation-1'), isFalse);
    expect(api.timelineCalls, 2);
    chat.dispose();
  });

  testWidgets('failed send keeps timeline clean and shows backend error', (
    tester,
  ) async {
    final chat = ChatProvider(
      api: _FakeChatApi(
        conversations: [_conversation()],
        sendError: const ApiException('تعذر إرسال الرسالة الآن.'),
      ),
      realtime: _FakeRealtimeClient(storage),
      authStorage: storage,
    );

    await tester.pumpWidget(_chatApp(chat));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'رسالة لن تصل');
    await tester.tap(find.byIcon(LucideIcons.send));
    await tester.pumpAndSettle();

    expect(find.text('تعذر إرسال الرسالة الآن.'), findsOneWidget);
    expect(chat.timelineFor('conversation-1'), isEmpty);
    chat.dispose();
  });

  test('realtime read receipt updates the sent-message state', () async {
    final realtime = _FakeRealtimeClient(storage);
    final chat = ChatProvider(
      api: _FakeChatApi(conversations: [_conversation()]),
      realtime: realtime,
      authStorage: storage,
    );
    await chat.initialize();
    final sent = _message(senderUserId: 'user-1');

    realtime.emitRead(
      'conversation-1',
      'provider-user-1',
      DateTime.utc(2026, 7, 7, 12, 1),
    );

    expect(chat.isMessageRead(sent), isTrue);
    chat.dispose();
  });
}

Widget _chatApp(ChatProvider chat) =>
    ChangeNotifierProvider<ChatProvider>.value(
      value: chat,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const ChatScreen(conversationId: 'conversation-1'),
      ),
    );

ChatConversation _conversation({
  String id = 'conversation-1',
  ChatConversationScope scope = ChatConversationScope.plan,
  bool blocked = false,
  bool blockedByMe = false,
  bool blockedByCounterpart = false,
  bool providerJoined = true,
  bool canSend = true,
}) => ChatConversation(
  id: id,
  scope: scope,
  weddingPlan: scope == ChatConversationScope.plan
      ? const ChatWeddingPlan(id: 'plan-1', title: 'خطة رشا ومحمد')
      : null,
  provider: const ChatProviderSummary(
    id: 'provider-1',
    businessName: 'قاعة السعادة',
  ),
  counterpart: const ChatUser(id: 'provider-user-1', name: 'المزوّد'),
  quoteRequestCount: 2,
  unreadMessageCount: 0,
  muted: false,
  blocked: blocked,
  blockedByMe: blockedByMe,
  blockedByCounterpart: blockedByCounterpart,
  providerJoined: providerJoined,
  canSend: canSend,
  permissions: const ChatConversationPermissions(
    canManageProviders: true,
    canViewMoney: false,
    canManageMoney: false,
    canViewContact: true,
  ),
  lastActivityAt: DateTime.utc(2026, 7, 7),
  createdAt: DateTime.utc(2026, 7, 7),
  updatedAt: DateTime.utc(2026, 7, 7),
);

ChatMessage _message({
  String id = 'message-1',
  String senderUserId = 'provider-user-1',
  String body = 'رسالة واحدة',
  DateTime? createdAt,
}) => ChatMessage(
  id: id,
  conversationId: 'conversation-1',
  senderUserId: senderUserId,
  body: body,
  createdAt: createdAt ?? DateTime.utc(2026, 7, 7, 12),
);

ChatTimelineItem _messageItem({String body = 'رسالة واحدة'}) =>
    ChatTimelineItem.fromJson({
      'kind': 'MESSAGE',
      'occurredAt': '2026-07-07T12:00:00.000Z',
      'message': {
        'id': 'message-1',
        'conversationId': 'conversation-1',
        'senderUserId': 'provider-user-1',
        'body': body,
        'createdAt': '2026-07-07T12:00:00.000Z',
      },
    });

ChatTimelineItem _eventItem({String type = 'QUOTE_REQUEST_CREATED'}) =>
    ChatTimelineItem.fromJson({
      'kind': 'EVENT',
      'occurredAt': '2026-07-07T11:00:00.000Z',
      'event': {
        'id': 'event-$type',
        'conversationId': 'conversation-1',
        'quoteRequestId': 'quote-1',
        'type': type,
        'occurredAt': '2026-07-07T11:00:00.000Z',
      },
    });

Map<String, dynamic> _conversationJson({
  String scope = 'PLAN',
  Map<String, dynamic>? weddingPlan = const {
    'id': 'plan-1',
    'title': 'خطة رشا ومحمد',
  },
}) => {
  'id': 'conversation-api',
  'scope': scope,
  'weddingPlan': weddingPlan,
  'provider': {'id': 'provider-1', 'businessName': 'قاعة السعادة'},
  'counterpart': {'id': 'provider-user-1', 'name': 'المزوّد'},
  'quoteRequestCount': 2,
  'unreadMessageCount': 0,
  'muted': false,
  'blocked': false,
  'providerJoined': true,
  'canSend': true,
  'permissions': {
    'canManageProviders': true,
    'canViewMoney': false,
    'canManageMoney': false,
    'canViewContact': true,
  },
  'lastActivityAt': '2026-07-11T00:00:00.000Z',
  'createdAt': '2026-07-11T00:00:00.000Z',
  'updatedAt': '2026-07-11T00:00:00.000Z',
};

class _FakeChatApi extends ChatApi {
  _FakeChatApi({
    this.conversations = const [],
    this.conversationPage,
    this.olderConversationPage,
    this.initialTimeline = const ChatTimelinePage(items: []),
    this.olderTimeline = const ChatTimelinePage(items: []),
    this.timelineError,
    this.timelineFailuresRemaining = 0,
    this.sendError,
  }) : super(ApiClient(tokenProvider: () async => null));

  final List<ChatConversation> conversations;
  final ChatConversationPage? conversationPage;
  final ChatConversationPage? olderConversationPage;
  final ChatTimelinePage initialTimeline;
  ChatTimelinePage? _timelineOverride;
  ChatTimelinePage get timelinePage => _timelineOverride ?? initialTimeline;
  set timelinePage(ChatTimelinePage value) => _timelineOverride = value;
  final ChatTimelinePage olderTimeline;
  final ApiException? timelineError;
  int timelineFailuresRemaining;
  final ApiException? sendError;
  void Function(ChatMessage message)? onSend;
  int markReadCalls = 0;
  int timelineCalls = 0;
  int conversationForQuoteCalls = 0;
  final List<String?> requestedConversationCursors = [];

  @override
  Future<ChatConversation> conversationForQuote(String quoteRequestId) async {
    conversationForQuoteCalls += 1;
    return conversations.isNotEmpty ? conversations.first : _conversation();
  }

  @override
  Future<ChatConversation> getConversation(String conversationId) async {
    for (final conversation in conversations) {
      if (conversation.id == conversationId) return conversation;
    }
    return _conversation(id: conversationId);
  }

  @override
  Future<ChatConversationPage> listConversations({String? cursor}) async {
    requestedConversationCursors.add(cursor);
    if (cursor != null && olderConversationPage != null) {
      return olderConversationPage!;
    }
    return conversationPage ?? ChatConversationPage(items: conversations);
  }

  @override
  Future<ChatTimelinePage> timeline(
    String conversationId, {
    String? cursor,
  }) async {
    timelineCalls += 1;
    if (timelineFailuresRemaining > 0) {
      timelineFailuresRemaining -= 1;
      throw timelineError ??
          const ApiException(
            aarastBackendConnectionErrorMessage,
            isNetworkFailure: true,
          );
    }
    return cursor == null ? timelinePage : olderTimeline;
  }

  @override
  Future<ChatQuoteRequestPage> quoteRequests(String conversationId) async =>
      ChatQuoteRequestPage(
        items: [
          ChatQuoteRequestSummary(
            id: 'quote-1',
            status: 'SENT',
            createdAt: DateTime.utc(2026, 7, 7),
          ),
          ChatQuoteRequestSummary(
            id: 'quote-2',
            status: 'ACCEPTED',
            createdAt: DateTime.utc(2026, 7, 8),
          ),
        ],
      );

  @override
  Future<ChatMessage> send(
    String conversationId, {
    required String body,
    List<MediaUploadTicket> attachments = const [],
  }) async {
    if (sendError != null) throw sendError!;
    final message = _message(senderUserId: 'user-1', body: body);
    onSend?.call(message);
    return message;
  }

  @override
  Future<void> markRead(String conversationId) async {
    markReadCalls += 1;
  }
}

class _ConversationApiClient extends ApiClient {
  _ConversationApiClient() : super(tokenProvider: () async => null);

  String? lastPath;

  @override
  Future<Map<String, dynamic>> getJson(String path) async {
    lastPath = path;
    if (path == '/api/v1/quote-requests/quote-1/conversation' ||
        path == '/api/v1/conversations/conversation-api') {
      return _conversationJson();
    }
    return {
      'items': [_conversationJson()],
      'nextCursor': 'cursor-2',
    };
  }
}

class _FakeRealtimeClient extends ChatRealtimeClient {
  _FakeRealtimeClient(super.authStorage);

  final List<String> joinedConversationIds = [];
  void Function(ChatMessage message)? _onMessage;
  void Function(String conversationId)? _onActivity;
  void Function(String conversationId)? _onPermissionRevoked;
  void Function(String conversationId, String userId, DateTime? lastReadAt)?
  _onRead;
  int connectCalls = 0;
  int resetCalls = 0;

  @override
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
  }) async {
    connectCalls += 1;
    _onMessage = onMessage;
    _onActivity = onActivityAvailable;
    _onPermissionRevoked = onPermissionRevoked;
    _onRead = onRead;
  }

  @override
  void join(String conversationId) {
    if (!joinedConversationIds.contains(conversationId)) {
      joinedConversationIds.add(conversationId);
    }
  }

  void emitMessage(ChatMessage message) => _onMessage?.call(message);

  void emitActivity(String conversationId) => _onActivity?.call(conversationId);

  void emitPermissionRevoked(String conversationId) =>
      _onPermissionRevoked?.call(conversationId);

  void emitRead(String conversationId, String userId, DateTime lastReadAt) {
    _onRead?.call(conversationId, userId, lastReadAt);
  }

  @override
  void reset() {
    resetCalls += 1;
    joinedConversationIds.clear();
  }
}
