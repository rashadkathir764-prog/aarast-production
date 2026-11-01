import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/chat/data/chat_api.dart';
import 'package:aarast_mobile/features/chat/data/chat_realtime_client.dart';
import 'package:aarast_mobile/features/chat/models/chat_models.dart';
import 'package:aarast_mobile/features/chat/providers/chat_provider.dart';
import 'package:aarast_mobile/features/chat/screens/chat_screen.dart';
import 'package:aarast_mobile/features/chat/widgets/conversation_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The provider's side of a conversation (provider/admin audit, D35): he reads
// the customer's name, no line about himself, options about the customer,
// and a quote event opens his own requests tab, never the groom's pages.

const _providerPermissions = ChatConversationPermissions(
  canManageProviders: false,
  canViewMoney: true,
  canManageMoney: false,
  canViewContact: true,
);

const _customerPermissions = ChatConversationPermissions(
  canManageProviders: true,
  canViewMoney: true,
  canManageMoney: true,
  canViewContact: true,
);

ChatConversation _conversation({
  ChatConversationPermissions permissions = _providerPermissions,
  ChatUser? counterpart,
  String? contactName = 'أحمد العريس',
}) => ChatConversation(
  id: 'conversation-1',
  scope: ChatConversationScope.plan,
  weddingPlan: const ChatWeddingPlan(id: 'plan-1', title: 'عرس أحمد'),
  provider: const ChatProviderSummary(
    id: 'provider-1',
    businessName: 'استديو الفن',
  ),
  counterpart: counterpart,
  latestQuoteRequest: ChatQuoteRequestSummary(
    id: 'quote-1',
    status: 'SENT',
    createdAt: DateTime.utc(2026, 10, 1),
    contactName: contactName,
    service: const ChatQuoteService(id: 'service-1', title: 'تصوير'),
  ),
  quoteRequestCount: 1,
  unreadMessageCount: 0,
  muted: false,
  blocked: false,
  providerJoined: true,
  canSend: true,
  permissions: permissions,
  lastActivityAt: DateTime.utc(2026, 10, 1),
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
);

void main() {
  late AuthStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    storage = AuthStorage(preferences);
    await storage.saveSession(
      accessToken: 'access-token',
      user: const SafeUser(
        id: 'provider-user-1',
        name: 'صاحب الاستديو',
        role: 'USER',
        status: 'ACTIVE',
      ),
    );
  });

  test('the request summary keeps the contact name the server sends', () {
    final summary = ChatQuoteRequestSummary.fromJson({
      'id': 'quote-1',
      'status': 'SENT',
      'createdAt': '2026-10-01T00:00:00.000Z',
      'contactName': 'أحمد العريس',
    });
    expect(summary.contactName, 'أحمد العريس');
  });

  test('each side reads the other side\'s name', () {
    expect(_conversation().viewerIsProvider, isTrue);
    expect(_conversation().counterpartName, 'أحمد العريس');
    // The name on the request, as the requests tab reads it; the account's
    // first name only stands in without one.
    expect(
      _conversation(
        counterpart: const ChatUser(id: 'user-2', name: 'أحمد'),
      ).counterpartName,
      'أحمد العريس',
    );
    expect(
      _conversation(
        contactName: null,
        counterpart: const ChatUser(id: 'user-2', name: 'سالم'),
      ).counterpartName,
      'سالم',
    );
    expect(_conversation(contactName: null).counterpartName, 'العميل');

    final customer = _conversation(permissions: _customerPermissions);
    expect(customer.viewerIsProvider, isFalse);
    expect(customer.counterpartName, 'استديو الفن');
  });

  testWidgets('the provider reads the customer on top and no line about '
      'himself', (tester) async {
    var providerLineAsked = false;
    final chat = _chat(storage);
    await tester.pumpWidget(
      _app(
        chat,
        ChatScreen(
          conversationId: 'conversation-1',
          providerLine: (_, _) async {
            providerLineAsked = true;
            return 'يرد عادة خلال ساعتين';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('أحمد العريس'), findsOneWidget);
    expect(find.text('استديو الفن'), findsNothing);
    expect(find.text('يرد عادة خلال ساعتين'), findsNothing);
    expect(providerLineAsked, isFalse);

    await tester.tap(find.text('أحمد العريس'));
    await tester.pumpAndSettle();
    expect(find.text('احظر العميل'), findsOneWidget);
    expect(find.text('احظر المزود'), findsNothing);
    expect(
      find.text(
        'الحظر ما يلغي حجز العميل المؤكد. ألغه من "حجوزاتك" في الرئيسية لو تشتي.',
      ),
      findsOneWidget,
    );
    chat.dispose();
  });

  testWidgets('a quote event opens the provider\'s requests tab', (
    tester,
  ) async {
    final chat = _chat(storage);
    String? opened;
    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(
          path: '/chat',
          builder: (_, _) => const ChatScreen(conversationId: 'conversation-1'),
        ),
        GoRoute(
          path: AppRouter.providerDashboard,
          builder: (_, state) {
            opened = state.uri.toString();
            return const Text('بوابة المزود');
          },
        ),
        GoRoute(
          path: '/wedding-plans/:id/providers',
          builder: (_, _) => const Text('مزودي الخطة'),
        ),
        GoRoute(
          path: AppRouter.providerMarketplace,
          builder: (_, _) => const Text('سوق المزودين'),
        ),
      ],
    );
    addTearDown(router.dispose);
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
      find.byKey(const Key('conversation-event-quote_request_rejected')),
    );
    await tester.pumpAndSettle();

    expect(opened, AppRouter.providerRequestsTab);
    expect(find.text('بوابة المزود'), findsOneWidget);
    expect(find.text('مزودي الخطة'), findsNothing);
    expect(find.text('سوق المزودين'), findsNothing);
    chat.dispose();
  });

  testWidgets('the provider\'s conversation list names the customer', (
    tester,
  ) async {
    final chat = _chat(storage);
    await tester.pumpWidget(_app(chat, const ConversationListView()));
    await tester.pumpAndSettle();

    expect(find.text('أحمد العريس'), findsOneWidget);
    expect(find.text('استديو الفن'), findsNothing);
    expect(find.text('طلب: تصوير'), findsOneWidget);
    chat.dispose();
  });
}

ChatProvider _chat(AuthStorage storage) => ChatProvider(
  api: _ProviderChatApi(),
  realtime: _QuietRealtimeClient(storage),
  authStorage: storage,
);

Widget _app(ChatProvider chat, Widget home) =>
    ChangeNotifierProvider<ChatProvider>.value(
      value: chat,
      child: MaterialApp(theme: AppTheme.light(), home: home),
    );

class _ProviderChatApi extends ChatApi {
  _ProviderChatApi() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<ChatConversationPage> listConversations({String? cursor}) async =>
      ChatConversationPage(items: [_conversation()]);

  @override
  Future<ChatConversation> getConversation(String conversationId) async =>
      _conversation();

  @override
  Future<ChatTimelinePage> timeline(
    String conversationId, {
    String? cursor,
  }) async => ChatTimelinePage(
    items: [
      ChatTimelineItem.fromJson({
        'kind': 'EVENT',
        'occurredAt': '2026-10-01T10:00:00.000Z',
        'event': {
          'id': 'event-rejected',
          'conversationId': 'conversation-1',
          'quoteRequestId': 'quote-1',
          'type': 'QUOTE_REQUEST_REJECTED',
          'occurredAt': '2026-10-01T10:00:00.000Z',
        },
      }),
    ],
  );

  @override
  Future<ChatQuoteRequestPage> quoteRequests(String conversationId) async =>
      const ChatQuoteRequestPage(items: []);

  @override
  Future<void> markRead(String conversationId) async {}
}

class _QuietRealtimeClient extends ChatRealtimeClient {
  _QuietRealtimeClient(super.authStorage);

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
