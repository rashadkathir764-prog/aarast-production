import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/chat/data/chat_api.dart';
import 'package:aarast_mobile/features/chat/data/chat_realtime_client.dart';
import 'package:aarast_mobile/features/chat/models/chat_models.dart';
import 'package:aarast_mobile/features/chat/providers/chat_provider.dart';
import 'package:aarast_mobile/features/chat/screens/chat_screen.dart';
import 'package:aarast_mobile/features/chat/screens/quote_conversation_entry_screen.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/providers/marketplace_provider.dart';
import 'package:aarast_mobile/features/marketplace/screens/edit_provider_profile_screen.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/data/local_plan_migration.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/onboarding/screens/local_plan_migration_screen.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/plan_access_permissions.dart';
import 'package:aarast_mobile/features/sharing/models/plan_role_permissions.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/sharing/screens/edit_shared_member_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/onboarding_complete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('QuoteConversationEntryScreen at 320px RTL', () {
    testWidgets('shows loading then opens real chat content without overflow', (
      tester,
    ) async {
      final authStorage = await _authStorage();
      final gate = Completer<void>();
      final provider = _FakeChatProvider(
        authStorage,
        conversation: _conversation,
        openGate: gate,
      );

      await _pump320(
        tester,
        providers: [
          ChangeNotifierProvider<ChatProvider>.value(value: provider),
        ],
        child: const QuoteConversationEntryScreen(quoteRequestId: 'quote-1'),
      );
      await tester.pump();

      expect(find.text('جارٍ فتح المحادثة الآمنة...'), findsOneWidget);
      expect(tester.takeException(), isNull);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(ChatScreen), findsOneWidget);
      expect(find.text('لا يوجد نشاط بعد'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unexpected open failure becomes a retryable error state', (
      tester,
    ) async {
      final authStorage = await _authStorage();
      final provider = _FakeChatProvider(
        authStorage,
        openError: StateError('transport failed'),
      );

      await _pump320(
        tester,
        providers: [
          ChangeNotifierProvider<ChatProvider>.value(value: provider),
        ],
        child: const QuoteConversationEntryScreen(quoteRequestId: 'quote-1'),
      );
      await tester.pumpAndSettle();

      expect(find.text('تعذر فتح المحادثة'), findsOneWidget);
      expect(find.text('حاول مرة أخرى'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('EditProviderProfileScreen at 320px RTL', () {
    testWidgets('renders loading and empty states without overflow', (
      tester,
    ) async {
      final marketplace = _FakeMarketplaceProvider();

      await _pumpProviderProfile(
        tester,
        marketplace: marketplace,
        dashboard: _FakeProviderDashboardProvider(isLoading: true),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(EditProviderProfileScreen), findsOneWidget);
      expect(find.text('لا يوجد ملف مزود'), findsNothing);
      expect(tester.takeException(), isNull);

      await _pumpProviderProfile(
        tester,
        marketplace: marketplace,
        dashboard: _FakeProviderDashboardProvider(),
      );
      await tester.pumpAndSettle();
      expect(find.text('لا يوجد ملف مزود'), findsOneWidget);
      expect(find.text('طلب الانضمام كمزود'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'load failure is truthful and retryable instead of looking empty',
      (tester) async {
        final dashboard = _FakeProviderDashboardProvider(
          errorMessage: 'تعذر تحميل ملف المزود.',
        );
        await _pumpProviderProfile(
          tester,
          marketplace: _FakeMarketplaceProvider(),
          dashboard: dashboard,
        );
        await tester.pumpAndSettle();

        expect(find.text('تعذر تحميل ملف المزود'), findsOneWidget);
        expect(find.text('تعذر تحميل ملف المزود.'), findsOneWidget);
        expect(find.text('لا يوجد ملف مزود'), findsNothing);
        await tester.tap(find.text('حاول مرة أخرى'));
        await tester.pump();
        expect(dashboard.loadCalls, 2);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'long profile content remains usable with enlarged Arabic text',
      (tester) async {
        await _pumpProviderProfile(
          tester,
          marketplace: _FakeMarketplaceProvider(
            cities: const [
              MarketplaceCity(id: 'city-1', nameAr: 'أمانة العاصمة'),
            ],
          ),
          dashboard: _FakeProviderDashboardProvider(profile: _providerProfile),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'حالة الحساب: نشط. تعديل البيانات لا يعني اعتماد المزود تلقائياً.',
          ),
          findsOneWidget,
        );
        final firstField = tester.widget<TextFormField>(
          find.byType(TextFormField).first,
        );
        expect(firstField.controller?.text, _providerProfile.businessName);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('LocalPlanMigrationScreen at 320px RTL', () {
    testWidgets(
      'renders content, upload loading, and API error without overflow',
      (tester) async {
        final preferences = await _preferences();
        final gate = Completer<OnboardingCompleteResponse>();
        final service = _FakeLocalPlanMigrationService(
          GuestOnboardingStorage(preferences),
          onMigrate: () => gate.future,
        );

        await _pump320(
          tester,
          child: LocalPlanMigrationScreen(
            snapshot: _localSnapshot,
            migrationService: service,
            onFinished: () {},
          ),
        );

        expect(find.text('وجدنا خطتك المحفوظة على هذا الجهاز'), findsOneWidget);
        expect(find.text('المصاريف: 1'), findsOneWidget);
        expect(find.text('المهام: 1'), findsOneWidget);
        expect(find.text('الضيوف: 1'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.scrollUntilVisible(
          find.text('رفع الخطة إلى حسابي'),
          240,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
        await tester.pump();
        await tester.tap(find.text('رفع الخطة إلى حسابي'));
        await tester.pump();
        expect(service.migrateCalls, 1);
        expect(find.text('تجاهل الخطة المحلية'), findsOneWidget);
        expect(tester.takeException(), isNull);

        gate.completeError(const ApiException('تعذر استيراد الخطة المحلية.'));
        await tester.pumpAndSettle();

        expect(find.text('تعذر استيراد الخطة المحلية.'), findsOneWidget);
        expect(find.text('رفع الخطة إلى حسابي'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('EditSharedMemberScreen at 320px RTL', () {
    testWidgets('missing member shows the honest empty state', (tester) async {
      await _pump320(
        tester,
        providers: [
          ChangeNotifierProvider<SharingProvider>.value(
            value: _FakeSharingProvider(),
          ),
        ],
        child: const EditSharedMemberScreen(sharedMemberId: 'missing'),
      );

      expect(find.text('لا يمكن تعديل العضو الآن'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'long member content and submitting error remain overflow-safe',
      (tester) async {
        final gate = Completer<void>();
        final provider = _FakeSharingProvider(
          member: _sharedMember,
          updateGate: gate,
          updateError: 'تعذر تحديث صلاحيات العضو.',
        );
        await _pump320(
          tester,
          providers: [
            ChangeNotifierProvider<SharingProvider>.value(value: provider),
          ],
          child: const EditSharedMemberScreen(sharedMemberId: 'member-1'),
        );

        expect(find.textContaining('اسم عضو طويل'), findsOneWidget);
        expect(find.text('إدارة المال'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.scrollUntilVisible(
          find.text('حفظ التغييرات'),
          280,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
        await tester.pump();
        await tester.tap(find.text('حفظ التغييرات'));
        await tester.pump();
        expect(provider.isSubmitting, isTrue);
        expect(tester.takeException(), isNull);

        gate.complete();
        await tester.pumpAndSettle();
        expect(find.text('تعذر تحديث صلاحيات العضو.'), findsOneWidget);
        expect(provider.updateCalls, 1);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Future<void> _pumpProviderProfile(
  WidgetTester tester, {
  required _FakeMarketplaceProvider marketplace,
  required _FakeProviderDashboardProvider dashboard,
}) {
  return _pump320(
    tester,
    providers: [
      ChangeNotifierProvider<ProviderMarketplaceProvider>.value(
        value: marketplace,
      ),
      ChangeNotifierProvider<ProviderDashboardProvider>.value(value: dashboard),
    ],
    child: const EditProviderProfileScreen(),
  );
}

Future<void> _pump320(
  WidgetTester tester, {
  List<SingleChildWidget> providers = const [],
  required Widget child,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 760);
  addTearDown(tester.view.reset);

  final app = MaterialApp(
    theme: AppTheme.light(),
    builder: (context, appChild) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(1.3)),
      child: Directionality(textDirection: TextDirection.rtl, child: appChild!),
    ),
    home: child,
  );
  await tester.pumpWidget(
    providers.isEmpty ? app : MultiProvider(providers: providers, child: app),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));
}

Future<SharedPreferences> _preferences() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

Future<AuthStorage> _authStorage() async => AuthStorage(await _preferences());

final _conversation = ChatConversation(
  id: 'conversation-1',
  scope: ChatConversationScope.plan,
  weddingPlan: const ChatWeddingPlan(id: 'plan-1', title: 'خطة الزفاف'),
  provider: const ChatProviderSummary(
    id: 'provider-1',
    businessName: 'مزود بخدمات وتجهيزات حفلات طويلة الاسم',
  ),
  counterpart: ChatUser(
    id: 'provider-user-1',
    name: 'مزود بخدمات وتجهيزات حفلات طويلة الاسم',
  ),
  quoteRequestCount: 1,
  unreadMessageCount: 0,
  muted: false,
  blocked: false,
  providerJoined: true,
  canSend: true,
  permissions: ChatConversationPermissions.none,
  lastActivityAt: _fixedDate,
  createdAt: _fixedDate,
  updatedAt: _fixedDate,
);

final _fixedDate = DateTime(2026, 7, 10);

class _FakeChatProvider extends ChatProvider {
  _FakeChatProvider(
    AuthStorage authStorage, {
    this.conversation,
    this.openGate,
    this.openError,
  }) : super(
         api: ChatApi(ApiClient(tokenProvider: () async => null)),
         realtime: ChatRealtimeClient(authStorage),
         authStorage: authStorage,
         sessionUserId: 'user-1',
       );

  final ChatConversation? conversation;
  final Completer<void>? openGate;
  final Object? openError;

  @override
  Future<void> initialize() async {}

  @override
  Future<ChatConversation?> openQuote(String quoteRequestId) async {
    await openGate?.future;
    if (openError != null) throw openError!;
    return conversation;
  }

  @override
  Future<void> openConversation(String conversationId) async {}

  @override
  List<ChatConversation> get conversations => [?conversation];

  @override
  bool get isLoading => false;

  @override
  bool get isSending => false;

  @override
  String? get errorMessage => 'تعذر فتح المحادثة الآن.';
}

class _FakeMarketplaceProvider extends ProviderMarketplaceProvider {
  _FakeMarketplaceProvider({this.cities = const []})
    : super(MarketplaceApi(ApiClient(tokenProvider: () async => null)));

  @override
  final List<MarketplaceCity> cities;

  @override
  Future<void> loadReferenceData() async {}
}

class _FakeProviderDashboardProvider extends ProviderDashboardProvider {
  _FakeProviderDashboardProvider({
    this.profile,
    this.isLoading = false,
    this.errorMessage,
  }) : super(ProviderDashboardApi(ApiClient(tokenProvider: () async => null)));

  @override
  final ProviderDashboardProfile? profile;

  @override
  final bool isLoading;

  @override
  final String? errorMessage;

  int loadCalls = 0;

  @override
  bool get isSubmitting => false;

  @override
  Future<void> loadDashboard() async {
    loadCalls += 1;
  }
}

const _providerProfile = ProviderDashboardProfile(
  id: 'provider-1',
  businessName: 'استديو أعرست للتصوير والتوثيق وصناعة الذكريات الجميلة',
  status: 'ACTIVE',
  ratingAverage: 4.8,
  ratingCount: 12,
  phone: '+967777000111',
  cityId: 'city-1',
  description: 'وصف طويل لخدمات التصوير والتجهيز في مختلف مناطق المدينة.',
  city: MarketplaceCity(id: 'city-1', nameAr: 'أمانة العاصمة'),
  primaryCategory: ProviderCategory(
    id: 'category-1',
    nameAr: 'التصوير والتوثيق الاحترافي للحفلات والمناسبات',
  ),
);

class _FakeLocalPlanMigrationService extends LocalPlanMigrationService {
  _FakeLocalPlanMigrationService(
    GuestOnboardingStorage storage, {
    required this.onMigrate,
  }) : super(
         guestStorage: storage,
         weddingPlansApi: WeddingPlansApi(
           ApiClient(tokenProvider: () async => null),
         ),
       );

  final Future<OnboardingCompleteResponse> Function() onMigrate;
  int migrateCalls = 0;

  @override
  Future<OnboardingCompleteResponse> migrate(LocalPlanSnapshot snapshot) {
    migrateCalls += 1;
    return onMigrate();
  }
}

final _localSnapshot = LocalPlanSnapshot(
  draft: GuestOnboardingDraft(
    guestPlanId: 'guest-plan-1',
    planName: 'خطة زفاف طويلة الاسم محفوظة على هذا الجهاز بأمان',
    createdAt: _fixedDate,
    isGuestPlan: true,
    needsSync: true,
    selectedPath: GuestOnboardingPath.weddingUser,
    persona: GuestPersona.groom,
    governorate: 'أمانة العاصمة',
    city: 'صنعاء',
    district: null,
    neighborhood: null,
    street: null,
    addressNote: null,
    weddingDate: DateTime(2026, 12, 20),
    weddingDateUnknown: false,
    priorities: const [],
    currency: 'YER',
    estimatedBudget: '1000000',
    selectedCategoryKeys: const ['التصوير'],
  ),
  costs: const [
    {'id': 'cost-1'},
  ],
  costPayments: const [],
  paymentSchedules: const [],
  tasks: const [
    {'id': 'task-1'},
  ],
  guests: const [
    {'id': 'guest-1'},
  ],
  categoryNameById: const {},
);

class _FakeSharingProvider extends SharingProvider {
  _FakeSharingProvider({this.member, this.updateGate, this.updateError})
    : super(SharingApi(ApiClient(tokenProvider: () async => null)));

  final SharedMember? member;
  final Completer<void>? updateGate;
  final String? updateError;
  bool _submitting = false;
  String? _error;
  int updateCalls = 0;

  @override
  SharedMember? get selectedMember => member;

  @override
  SharedMember? findMember(String id) => member?.id == id ? member : null;

  @override
  PlanAccessPermissions get access =>
      const PlanAccessPermissions.owner(weddingPlanId: 'plan-1');

  @override
  Future<bool> loadAccess(
    String weddingPlanId, {
    bool preserveCurrentState = false,
  }) async => true;

  @override
  Future<void> loadMembers(
    String weddingPlanId, {
    bool preserveCurrentState = false,
  }) async {}

  @override
  bool get isSubmitting => _submitting;

  @override
  String? get errorMessage => _error;

  @override
  Future<bool> updateMember({
    required String weddingPlanId,
    required String id,
    required String role,
    required PlanRolePermissions permissions,
  }) async {
    updateCalls += 1;
    _submitting = true;
    _error = null;
    notifyListeners();
    await updateGate?.future;
    _submitting = false;
    _error = updateError;
    notifyListeners();
    return false;
  }
}

final _sharedMember = SharedMember(
  id: 'member-1',
  weddingPlanId: 'plan-1',
  userId: 'user-member-1',
  user: const SharedMemberUser(
    id: 'user-member-1',
    name: 'اسم عضو طويل لاختبار واجهة الصلاحيات على الهاتف الصغير',
    phone: '+967777123456',
  ),
  role: 'CONTRIBUTOR',
  canViewMoney: true,
  canManageTasks: true,
  canManageMoney: false,
  createdAt: _fixedDate,
  updatedAt: _fixedDate,
);
