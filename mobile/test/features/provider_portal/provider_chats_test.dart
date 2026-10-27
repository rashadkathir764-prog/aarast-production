import 'package:aarast_mobile/core/media/media_upload_api.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/chat/data/chat_api.dart';
import 'package:aarast_mobile/features/chat/data/chat_realtime_client.dart';
import 'package:aarast_mobile/features/chat/models/chat_models.dart';
import 'package:aarast_mobile/features/chat/providers/chat_provider.dart';
import 'package:aarast_mobile/features/chat/screens/chat_screen.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_chats_tab.dart';
import 'package:aarast_mobile/features/provider_portal/widgets/provider_chat_case.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'provider_requests_test.dart' show RequestsApi, offerJson, quoteJson;

// Provider slice 4 (D40): p33 his conversations and p34 one of them. The
// name is the customer's (D35); the status word, the service and the day
// come from his own request list; no voice note anywhere (F14).

const _providerUser = 'provider-user-1';
final _now = DateTime.now();

Map<String, dynamic> _conversationJson({
  String id = 'conversation-1',
  String quoteId = 'quote-1',
  String name = 'محمد الحمدي',
  String body = 'الدرون عند الباب ممكن؟',
  int unread = 2,
  bool canManageProviders = false,
}) => {
  'id': id,
  'scope': 'PLAN',
  'weddingPlan': {'id': 'plan-1', 'title': 'عرس محمد'},
  'provider': {'id': 'provider-1', 'businessName': 'استوديو ضوء صنعاء'},
  'latestQuoteRequest': {
    'id': quoteId,
    'status': 'RESPONDED',
    'createdAt': '2026-10-01T00:00:00.000Z',
    'contactName': name,
    'service': {'id': 'service-1', 'title': 'صور وفيديو'},
  },
  'quoteRequestCount': 1,
  'lastMessage': {
    'id': 'message-last-$id',
    'conversationId': id,
    'senderUserId': 'customer-1',
    'body': body,
    'createdAt': _now.toUtc().toIso8601String(),
  },
  'lastActivityAt': _now.toUtc().toIso8601String(),
  'unreadMessageCount': unread,
  'providerJoined': true,
  'canSend': true,
  'permissions': {
    'canManageProviders': canManageProviders,
    'canViewMoney': true,
    'canManageMoney': canManageProviders,
    'canViewContact': true,
  },
  'createdAt': '2026-10-01T00:00:00.000Z',
  'updatedAt': '2026-10-01T00:00:00.000Z',
};

Map<String, dynamic> _message(String id, String sender, String body) => {
  'kind': 'MESSAGE',
  'occurredAt': _now.toUtc().toIso8601String(),
  'message': {
    'id': id,
    'conversationId': 'conversation-1',
    'senderUserId': sender,
    'body': body,
    'createdAt': _now.toUtc().toIso8601String(),
  },
};

class _ChatApi extends ChatApi {
  _ChatApi(this.conversations)
    : super(ApiClient(tokenProvider: () async => null));

  final List<Map<String, dynamic>> conversations;
  final sent = <String>[];

  @override
  Future<ChatConversationPage> listConversations({String? cursor}) async =>
      ChatConversationPage(
        items: [
          for (final json in conversations) ChatConversation.fromJson(json),
        ],
      );

  @override
  Future<ChatConversation> getConversation(String conversationId) async =>
      ChatConversation.fromJson(
        conversations.firstWhere((json) => json['id'] == conversationId),
      );

  @override
  Future<ChatTimelinePage> timeline(
    String conversationId, {
    String? cursor,
  }) async => ChatTimelinePage(
    items: [
      ChatTimelineItem.fromJson(
        _message('m-1', 'customer-1', 'السلام عليكم، الدرون عند الباب ممكن؟'),
      ),
      ChatTimelineItem.fromJson(
        _message('m-2', _providerUser, 'وعليكم السلام. ممكن'),
      ),
    ],
  );

  @override
  Future<ChatQuoteRequestPage> quoteRequests(String conversationId) async =>
      const ChatQuoteRequestPage(items: []);

  @override
  Future<void> markRead(String conversationId) async {}

  @override
  Future<ChatMessage> send(
    String conversationId, {
    required String body,
    List<MediaUploadTicket> attachments = const [],
    String? clientRequestId,
  }) async {
    sent.add(body);
    return ChatMessage.fromJson({
      'id': 'sent-${sent.length}',
      'conversationId': conversationId,
      'senderUserId': _providerUser,
      'body': body,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

class _QuietRealtime extends ChatRealtimeClient {
  _QuietRealtime(super.authStorage);

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
  }) async {}

  @override
  void join(String conversationId) {}
}

class _AddressApi extends RequestsApi {
  _AddressApi({super.quotes});

  @override
  Future<ProviderDashboardProfile> getProfile() async =>
      const ProviderDashboardProfile(
        id: 'provider-1',
        businessName: 'استوديو ضوء صنعاء',
        status: 'ACTIVE',
        ratingAverage: 0,
        ratingCount: 0,
        city: MarketplaceCity(id: 'city-1', nameAr: 'صنعاء'),
        primaryCategory: ProviderCategory(id: 'cat-1', nameAr: 'تصوير'),
        address: 'شارع حدة، جنب جولة المصباحي',
      );
}

final _quotes = [
  quoteJson(status: 'RESPONDED', offers: [offerJson()]),
  quoteJson(id: 'quote-2', name: 'سلمى السقاف'),
];

Future<({ChatProvider chat, _ChatApi api, List<String> opened})> _pump(
  WidgetTester tester, {
  required Widget Function() home,
  List<Map<String, dynamic>>? conversations,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(420, 1000);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final storage = AuthStorage(await SharedPreferences.getInstance());
  await storage.saveSession(
    accessToken: 'access-token',
    user: const SafeUser(
      id: _providerUser,
      name: 'صاحب الاستوديو',
      role: 'USER',
      status: 'ACTIVE',
    ),
  );
  final api = _ChatApi(
    conversations ??
        [
          _conversationJson(),
          _conversationJson(
            id: 'conversation-2',
            quoteId: 'quote-2',
            name: 'سلمى السقاف',
            body: 'متى تقدرون؟',
            unread: 1,
          ),
        ],
  );
  final chat = ChatProvider(
    api: api,
    realtime: _QuietRealtime(storage),
    authStorage: storage,
  );
  addTearDown(chat.dispose);
  await chat.initialize();
  final dashboard = ProviderDashboardProvider(_AddressApi(quotes: _quotes));
  await dashboard.loadDashboard();
  final opened = <String>[];
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => home()),
      GoRoute(
        path: '/conversations/:id',
        builder: (_, state) {
          opened.add(state.uri.toString());
          return Scaffold(body: Text('محادثة ${state.pathParameters['id']}'));
        },
      ),
      GoRoute(
        path: '/provider/requests/:id',
        builder: (_, state) {
          opened.add(state.uri.toString());
          return const Scaffold(body: Text('الطلب'));
        },
      ),
      GoRoute(
        path: '/provider/requests/:id/offer',
        builder: (_, state) {
          opened.add(state.uri.toString());
          return const Scaffold(body: Text('العرض'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ProviderDashboardProvider>.value(
          value: dashboard,
        ),
        ChangeNotifierProvider<ChatProvider>.value(value: chat),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (chat: chat, api: api, opened: opened);
}

void main() {
  group('p33 conversations', () {
    testWidgets('each row: the customer, his request\'s status, service and '
        'day, the last message and the unread count', (tester) async {
      final pumped = await _pump(
        tester,
        home: () => const Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: ProviderChatsTab(),
          ),
        ),
      );

      expect(find.text('الرسائل'), findsOneWidget);
      expect(find.text('مع العرسان'), findsOneWidget);
      expect(find.text('محمد الحمدي'), findsOneWidget);
      expect(find.text('ردّيت'), findsOneWidget);
      expect(find.text('سلمى السقاف'), findsOneWidget);
      expect(find.text('جديد'), findsOneWidget);
      expect(find.text('صور وفيديو · 21 يناير'), findsNWidgets(2));
      expect(find.text('الدرون عند الباب ممكن؟'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.textContaining('صوتية'), findsNothing);
      expect(find.text('استوديو ضوء صنعاء'), findsNothing);

      await tester.tap(find.byKey(const Key('provider-chat-conversation-1')));
      await tester.pumpAndSettle();
      expect(pumped.opened, ['/conversations/conversation-1']);
    });

    testWidgets('no conversation yet says where they start', (tester) async {
      await _pump(
        tester,
        conversations: const [],
        home: () => const Scaffold(body: ProviderChatsTab()),
      );
      expect(find.byKey(const Key('provider-chats-empty')), findsOneWidget);
      expect(find.text('ما فيه محادثات لسا'), findsOneWidget);
    });
  });

  group('p34 one conversation', () {
    Widget chatScreen() => const ChatScreen(
      conversationId: 'conversation-1',
      providerCase: providerChatCase,
    );

    testWidgets('the offer strip, his teal bubbles on the far side, the '
        'quick replies and no microphone', (tester) async {
      final pumped = await _pump(tester, home: chatScreen);

      expect(find.text('محمد الحمدي'), findsOneWidget);
      expect(find.text('الخميس 21 يناير · صور وفيديو'), findsOneWidget);
      expect(find.byKey(const Key('provider-chat-strip')), findsOneWidget);
      expect(
        find.text('عرضك: صور وفيديو · 550,000 · باقي 8 أيام'),
        findsOneWidget,
      );
      expect(find.text('ردّيت'), findsOneWidget);
      expect(find.byIcon(LucideIcons.mic), findsNothing);
      expect(find.byKey(const Key('chat-composer-bar')), findsOneWidget);

      // His own message sits on the far (left) side, the customer's on the
      // reading side.
      final mine = tester.getRect(find.text('وعليكم السلام. ممكن'));
      final theirs = tester.getRect(
        find.text('السلام عليكم، الدرون عند الباب ممكن؟'),
      );
      expect(mine.left, lessThan(theirs.left));

      // No offer of his own drawn as the customer's card.
      expect(find.text('اقبل العرض'), findsNothing);

      expect(find.text('أرسل عرض'), findsNothing);
      await tester.tap(find.byKey(const Key('provider-chat-reply-place')));
      await tester.pumpAndSettle();
      expect(pumped.api.sent, ['موقع المحل: شارع حدة، جنب جولة المصباحي']);

      await tester.tap(find.byKey(const Key('provider-chat-reply-edit')));
      await tester.pumpAndSettle();
      expect(pumped.opened, ['/provider/requests/quote-1/offer']);
    });

    testWidgets('the strip opens the request', (tester) async {
      final pumped = await _pump(tester, home: chatScreen);
      await tester.tap(find.byKey(const Key('provider-chat-strip')));
      await tester.pumpAndSettle();
      expect(pumped.opened, ['/provider/requests/quote-1']);
    });

    testWidgets('a new request offers «أرسل عرض» and names what he asked', (
      tester,
    ) async {
      final pumped = await _pump(
        tester,
        conversations: [
          _conversationJson(quoteId: 'quote-2', name: 'سلمى السقاف'),
        ],
        home: chatScreen,
      );
      expect(find.text('طلبه: صور وفيديو'), findsOneWidget);
      expect(find.text('جديد'), findsOneWidget);
      expect(find.text('أعدّل العرض'), findsNothing);
      await tester.tap(find.byKey(const Key('provider-chat-reply-offer')));
      await tester.pumpAndSettle();
      expect(pumped.opened, ['/provider/requests/quote-2/offer']);
    });

    testWidgets('the customer\'s side never draws the provider\'s parts', (
      tester,
    ) async {
      await _pump(
        tester,
        conversations: [_conversationJson(canManageProviders: true)],
        home: chatScreen,
      );
      expect(find.byKey(const Key('provider-chat-strip')), findsNothing);
      expect(find.byKey(const Key('provider-chat-reply-place')), findsNothing);
      expect(find.byKey(const Key('chat-composer-bar')), findsNothing);
    });
  });
}
