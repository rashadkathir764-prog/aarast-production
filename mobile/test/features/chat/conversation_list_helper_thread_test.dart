import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/chat/data/chat_api.dart';
import 'package:aarast_mobile/features/chat/data/chat_realtime_client.dart';
import 'package:aarast_mobile/features/chat/models/chat_models.dart';
import 'package:aarast_mobile/features/chat/providers/chat_provider.dart';
import 'package:aarast_mobile/features/chat/widgets/conversation_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// RA-BE-139: the plan's owner reads one thread with the provider for himself
// and his partner, and one for each helper who asked the same provider. A
// helper's thread says whose request it is; the shared one says nothing more.

const _customerPermissions = ChatConversationPermissions(
  canManageProviders: true,
  canViewMoney: true,
  canManageMoney: true,
  canViewContact: true,
);

ChatConversation _thread(String id, {ChatThroughHelper? throughHelper}) =>
    ChatConversation(
      id: id,
      scope: ChatConversationScope.plan,
      weddingPlan: const ChatWeddingPlan(id: 'plan-1', title: 'عرس أحمد'),
      provider: const ChatProviderSummary(
        id: 'provider-1',
        businessName: 'قاعة الريان',
      ),
      throughHelper: throughHelper,
      quoteRequestCount: 1,
      unreadMessageCount: 0,
      muted: false,
      blocked: false,
      providerJoined: true,
      canSend: true,
      permissions: _customerPermissions,
      lastActivityAt: DateTime.utc(2026, 10, 1),
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    );

void main() {
  late AuthStorage storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = AuthStorage(await SharedPreferences.getInstance());
    await storage.saveSession(
      accessToken: 'access-token',
      user: const SafeUser(
        id: 'owner-1',
        name: 'أحمد',
        role: 'USER',
        status: 'ACTIVE',
      ),
    );
  });

  test('the server says whose request a helper thread is, or a former member', () {
    final named = ChatConversation.fromJson({
      'id': 'c-1',
      'provider': {'id': 'p-1', 'businessName': 'قاعة الريان'},
      'throughHelper': {'name': 'سالم أحمد'},
    });
    expect(named.throughHelper?.label, 'عن طريق سالم أحمد');
    final erased = ChatConversation.fromJson({
      'id': 'c-2',
      'provider': {'id': 'p-1', 'businessName': 'قاعة الريان'},
      'throughHelper': {'name': null},
    });
    expect(erased.throughHelper?.label, 'عن طريق عضو سابق');
    final shared = ChatConversation.fromJson({
      'id': 'c-3',
      'provider': {'id': 'p-1', 'businessName': 'قاعة الريان'},
      'throughHelper': null,
    });
    expect(shared.throughHelper, isNull);
    expect(named.copyWith(muted: true).throughHelper?.name, 'سالم أحمد');
  });

  testWidgets('the owner tells his thread from the helpers\' with the same provider', (
    tester,
  ) async {
    final chat = ChatProvider(
      api: _Api([
        _thread('shared'),
        _thread('helper', throughHelper: const ChatThroughHelper(name: 'سالم أحمد')),
        _thread('erased', throughHelper: const ChatThroughHelper()),
      ]),
      realtime: _QuietRealtimeClient(storage),
      authStorage: storage,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider<ChatProvider>.value(
        value: chat,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ConversationListView(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('قاعة الريان'), findsNWidgets(3));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('conversation-helper')),
        matching: find.text('عن طريق سالم أحمد'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('conversation-erased')),
        matching: find.text('عن طريق عضو سابق'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('conversation-shared')),
        matching: find.textContaining('عن طريق'),
      ),
      findsNothing,
    );
    chat.dispose();
  });
}

class _Api extends ChatApi {
  _Api(this.items) : super(ApiClient(tokenProvider: () async => null));

  final List<ChatConversation> items;

  @override
  Future<ChatConversationPage> listConversations({String? cursor}) async =>
      ChatConversationPage(items: items);
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
