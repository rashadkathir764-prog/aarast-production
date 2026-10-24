import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/diagnostics/app_logger.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/features/chat/data/chat_api.dart';
import 'package:aarast_mobile/features/chat/data/chat_realtime_client.dart';
import 'package:aarast_mobile/features/chat/models/chat_models.dart';
import 'package:aarast_mobile/features/chat/providers/chat_provider.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_portal_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/library_source.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('app provider tree wires chat and media dependencies', () {
    final source = File('lib/main.dart').readAsStringSync();

    expect(source, contains('Provider<MediaUploadApi>'));
    expect(source, contains('Provider<ChatApi>'));
    expect(source, contains('Provider<ChatRealtimeClient>'));
    expect(source, contains('AarastSessionBoundary('));
    expect(source, contains('ChangeNotifierProvider('));
    expect(source, contains('sessionUserId: sessionUserId'));
    expect(source, contains('ChatProvider('));
  });

  test('user chat surfaces initialize the realtime session', () {
    final listSource = File(
      'lib/features/chat/widgets/conversation_list_view.dart',
    ).readAsStringSync();
    final quoteEntrySource = File(
      'lib/features/chat/screens/quote_conversation_entry_screen.dart',
    ).readAsStringSync();

    expect(listSource, contains('.initialize()'));
    expect(listSource, contains('onRefresh: chat.initialize'));
    expect(quoteEntrySource, contains('.openQuote('));
  });

  test('direct conversation routes require an authenticated account', () {
    // The router's route trees live in per-area part files of the router
    // library (spec M6); the contract reads the whole library.
    final source = readLibrarySource('lib/core/routing/app_router.dart');

    expect(
      source,
      matches(
        RegExp(r"path: '/conversations/:id',[\s\S]{0,450}ProviderAuthGate\("),
      ),
    );
    expect(
      source,
      matches(
        RegExp(
          r"path: '/quotes/:id/conversation',[\s\S]{0,450}ProviderAuthGate\(",
        ),
      ),
    );
  });

  test(
    'chat initialization connects realtime once and refreshes REST',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final storage = AuthStorage(preferences);
      await storage.saveSession(
        accessToken: 'access-token',
        user: const SafeUser(
          id: 'user-1',
          name: 'المستخدم',
          role: 'USER',
          status: 'ACTIVE',
        ),
      );
      final api = _CountingChatApi();
      final realtime = _CountingRealtimeClient(storage);
      final chat = ChatProvider(
        api: api,
        realtime: realtime,
        authStorage: storage,
      );

      await chat.initialize();
      await chat.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(realtime.connectCalls, 1);
      expect(api.listCalls, 2);
      chat.dispose();
    },
  );

  test(
    'home entry stays account-context driven instead of legacy role driven',
    () {
      final source = File(
        'lib/features/home/screens/dashboard_entry_screen.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('isProviderAccount')));
      expect(source, isNot(contains('ProviderPortalScreen')));
      expect(source, contains('AccountContextEntryGate'));
    },
  );

  test('provider portal keeps the five approved Arabic destinations', () {
    final portalSource = File(
      'lib/features/provider_portal/screens/provider_portal_screen.dart',
    ).readAsStringSync();
    final navigationSource = File(
      'lib/features/provider_portal/widgets/provider_portal_bottom_nav.dart',
    ).readAsStringSync();
    final source = '$portalSource\n$navigationSource';
    // p28 (D39): the calendar takes the services' place, as drawn.
    for (final label in ['الرئيسية', 'الطلبات', 'التقويم', 'الرسائل', 'ملفي']) {
      expect(source, contains(label));
    }
    expect(source, contains('IndexedStack'));
    expect(source, contains('ProviderPortalBottomNav'));
    expect(source, isNot(contains('حجز مؤكد')));
    expect(source, isNot(contains('دفع')));
  });

  test('chat conversation parses unified provider and plan context', () {
    final conversation = ChatConversation.fromJson({
      'id': 'conversation-1',
      'scope': 'PLAN',
      'weddingPlan': {'id': 'plan-1', 'title': 'خطة رشا ومحمد'},
      'provider': {
        'id': 'provider-1',
        'businessName': 'قاعة الياسمين',
        'logoUrl': 'https://cdn.example/logo.webp',
      },
      'quoteRequestCount': 2,
      'unreadMessageCount': 2,
      'muted': false,
      'blocked': true,
      'blockedByMe': false,
      'blockedByCounterpart': true,
      'counterpart': {
        'id': 'provider-user-1',
        'name': 'قاعة الياسمين',
        'avatarUrl': 'https://cdn.example/logo.webp',
      },
      'latestQuoteRequest': {
        'id': 'quote-1',
        'status': 'SENT',
        'service': {'id': 'service-1', 'title': 'تنسيق القاعة'},
        'createdAt': '2026-07-05T09:00:00.000Z',
      },
      'lastMessage': {
        'id': 'message-1',
        'conversationId': 'conversation-1',
        'senderUserId': 'provider-user-1',
        'body': 'مرحبًا، وصل طلبكم',
        'createdAt': '2026-07-05T10:00:00.000Z',
        'attachments': <Object?>[],
      },
      'providerJoined': true,
      'canSend': false,
      'permissions': {
        'canManageProviders': true,
        'canViewMoney': false,
        'canManageMoney': false,
        'canViewContact': true,
      },
      'lastActivityAt': '2026-07-05T10:00:00.000Z',
      'createdAt': '2026-07-05T09:00:00.000Z',
      'updatedAt': '2026-07-05T10:00:00.000Z',
    });

    expect(conversation.unreadMessageCount, 2);
    expect(conversation.blockedByMe, isFalse);
    expect(conversation.blockedByCounterpart, isTrue);
    expect(conversation.provider.businessName, 'قاعة الياسمين');
    expect(conversation.weddingPlan?.title, 'خطة رشا ومحمد');
    expect(conversation.latestQuoteRequest?.service?.title, 'تنسيق القاعة');
    expect(conversation.lastMessage?.body, 'مرحبًا، وصل طلبكم');
  });

  test('timeline page preserves message activity and cursor', () {
    final page = ChatTimelinePage.fromJson({
      'items': [
        {
          'kind': 'MESSAGE',
          'occurredAt': '2026-07-05T10:00:00.000Z',
          'message': {
            'id': 'message-1',
            'conversationId': 'conversation-1',
            'senderUserId': 'user-1',
            'body': 'الرسالة الأولى',
            'createdAt': '2026-07-05T10:00:00.000Z',
            'attachments': <Object?>[],
          },
        },
      ],
      'nextCursor': 'message-0',
    });
    expect(page.items.single.message?.id, 'message-1');
    expect(page.nextCursor, 'message-0');
  });

  testWidgets('provider portal is usable at 320px and switches tabs', (
    tester,
  ) async {
    final logSink = _CollectingLogSink();
    AppLogger.installGlobal(
      AppLogger(
        redactor: LogRedactor(installationSalt: 'provider-portal-test'),
        sinks: [logSink],
      ),
    );
    addTearDown(AppLogger.clearGlobal);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 760);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ProviderDashboardProvider>.value(
            value: _FakeProviderDashboardProvider(),
          ),
          ChangeNotifierProvider<ChatProvider>.value(
            value: _FakeChatProvider(authStorage),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ProviderPortalScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('استديو اعّرست'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsLabel('الطلبات'));
    await tester.pumpAndSettle();
    // p15's lists (D37): the last one stays on screen, each label one line.
    final endedFilterRect = tester.getRect(
      find.byKey(const Key('provider-requests-tab-ended')),
    );
    expect(endedFilterRect.left, greaterThanOrEqualTo(0));
    expect(endedFilterRect.right, lessThanOrEqualTo(320));
    expect(tester.getSize(find.text('جديد')).height, lessThanOrEqualTo(24));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('التقويم'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('provider-calendar-close-days')), findsOne);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('الرسائل'));
    await tester.pumpAndSettle();
    // The shared conversations list speaks the journey's words (f08).
    expect(find.text('ما في محادثات بعد'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ملفي'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('provider-settings-action')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('الحساب والتطبيق'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('مزامنة الآن'), findsOneWidget);
    expect(find.text('تسجيل الخروج'), findsOneWidget);
    expect(tester.takeException(), isNull);

    expect(
      logSink.events.where(
        (event) =>
            event.name == 'dashboard_built' &&
            event.category == AppLogCategory.provider,
      ),
      hasLength(1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    expect(
      logSink.events.where(
        (event) =>
            event.name == 'dashboard_disposed' &&
            event.category == AppLogCategory.provider,
      ),
      hasLength(1),
    );
  });
}

class _CollectingLogSink implements AppLogSink {
  final List<AppLogEvent> events = [];

  @override
  void add(AppLogEvent event) => events.add(event);
}

class _FakeProviderDashboardProvider extends ProviderDashboardProvider {
  _FakeProviderDashboardProvider()
    : super(ProviderDashboardApi(ApiClient(tokenProvider: () async => null)));

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  ProviderDashboardProfile? get profile => const ProviderDashboardProfile(
    id: 'provider-1',
    businessName: 'استديو اعّرست',
    status: 'ACTIVE',
    ratingAverage: 4.8,
    ratingCount: 12,
    phone: '+967777000111',
    cityId: 'city-1',
    city: MarketplaceCity(id: 'city-1', nameAr: 'صنعاء'),
  );

  @override
  ProviderDashboardSummary get summary => const ProviderDashboardSummary(
    servicesCount: 2,
    activeServicesCount: 2,
    quoteRequestsCount: 1,
    newQuoteRequestsCount: 1,
    averageRating: 4.8,
    ratingCount: 12,
  );

  @override
  List<MarketplaceService> get services => const [];

  @override
  List<ProviderPackage> get packages => const [];

  @override
  List<QuoteRequest> get quoteRequests => const [];

  @override
  Future<void> loadDashboard() async {}
}

class _FakeChatProvider extends ChatProvider {
  _FakeChatProvider(AuthStorage storage)
    : super(
        api: ChatApi(ApiClient(tokenProvider: () async => null)),
        realtime: ChatRealtimeClient(storage),
        authStorage: storage,
      );

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => null;

  @override
  List<ChatConversation> get conversations => const [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> loadConversations() async {}
}

class _CountingChatApi extends ChatApi {
  _CountingChatApi() : super(ApiClient(tokenProvider: () async => null));

  int listCalls = 0;

  @override
  Future<ChatConversationPage> listConversations({String? cursor}) async {
    listCalls += 1;
    return const ChatConversationPage(items: []);
  }
}

class _CountingRealtimeClient extends ChatRealtimeClient {
  _CountingRealtimeClient(super.storage);

  int connectCalls = 0;

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
  }
}
