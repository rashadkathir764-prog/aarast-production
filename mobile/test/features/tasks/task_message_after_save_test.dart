import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/preferences/device_preferences.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/screens/create_task_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../support/app_route_table.dart';

// A task given to someone with a number: right after it is saved, the phone
// offers to send it to them (WhatsApp or a text), as the reader chose in
// «التنبيهات». Never for the reader's own task, never without a number.

const _localPlan = 'guest-plan-message';
const _accountPlan = 'account-plan';

void main() {
  late List<String> launched;

  setUp(() {
    launched = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (call) async {
            if (call.method == 'launch') {
              launched.add((call.arguments as Map)['url'] as String);
              return true;
            }
            return true;
          },
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        );
  });

  testWidgets('«اسألني» offers WhatsApp with the task written', (tester) async {
    final provider = await _pumpNew(tester);
    await _fillAndSave(tester, name: 'محمد', phone: '777123456');

    expect(provider.saves, 1);
    expect(find.text('tasks-target'), findsOneWidget, reason: 'saved, back');
    expect(find.byKey(const ValueKey('task-message-sheet')), findsOneWidget);
    expect(find.text('ترسل المهمة لـمحمد؟'), findsOneWidget);
    expect(launched, isEmpty, reason: 'nothing leaves before a choice');

    await tester.tap(find.byKey(const ValueKey('task-message-whatsapp')));
    await tester.pumpAndSettle();

    final uri = Uri.parse(launched.single);
    expect(uri.host, 'wa.me');
    expect(uri.path, '/967777123456');
    expect(uri.queryParameters['text'], contains('حجز القاعة'));
    expect(uri.queryParameters['text'], contains('الموعد: '));
    expect(find.byKey(const ValueKey('task-message-sheet')), findsNothing);
  });

  testWidgets('«رسالة نصية» opens the messages app with the same words', (
    tester,
  ) async {
    await _pumpNew(tester);
    await _fillAndSave(tester, name: 'محمد', phone: '777123456');

    await tester.tap(find.byKey(const ValueKey('task-message-sms')));
    await tester.pumpAndSettle();

    final uri = Uri.parse(launched.single);
    expect(uri.scheme, 'sms');
    expect(uri.path, '+967777123456');
    expect(uri.queryParameters['body'], contains('حجز القاعة'));
  });

  testWidgets('«مش الحين» sends nothing', (tester) async {
    await _pumpNew(tester);
    await _fillAndSave(tester, name: 'محمد', phone: '777123456');

    await tester.tap(find.byKey(const ValueKey('task-message-later')));
    await tester.pumpAndSettle();

    expect(launched, isEmpty);
    expect(find.byKey(const ValueKey('task-message-sheet')), findsNothing);
    expect(find.text('tasks-target'), findsOneWidget);
  });

  testWidgets('«افتح واتساب مباشرة» opens the chat without asking', (
    tester,
  ) async {
    await _pumpNew(tester, mode: TaskMessageMode.whatsApp);
    await _fillAndSave(tester, name: 'محمد', phone: '777123456');

    expect(find.byKey(const ValueKey('task-message-sheet')), findsNothing);
    expect(Uri.parse(launched.single).host, 'wa.me');
  });

  testWidgets('«لا ترسل» offers nothing', (tester) async {
    final provider = await _pumpNew(tester, mode: TaskMessageMode.off);
    await _fillAndSave(tester, name: 'محمد', phone: '777123456');

    expect(provider.saves, 1);
    expect(find.byKey(const ValueKey('task-message-sheet')), findsNothing);
    expect(launched, isEmpty);
  });

  testWidgets('no number, nothing offered', (tester) async {
    final provider = await _pumpNew(tester);
    await _fillAndSave(tester, name: 'محمد');

    expect(provider.saves, 1);
    expect(find.byKey(const ValueKey('task-message-sheet')), findsNothing);
    expect(launched, isEmpty);
  });

  testWidgets('a task kept for the reader offers nothing', (tester) async {
    final provider = await _pumpNew(tester);
    await tester.enterText(
      find.byKey(const ValueKey('task-title')),
      'حجز القاعة',
    );
    await _save(tester);

    expect(provider.saves, 1);
    expect(find.byKey(const ValueKey('task-message-sheet')), findsNothing);
  });

  testWidgets('a member gets it on their account number; the reader never', (
    tester,
  ) async {
    final provider = await _pumpAccount(tester);
    await tester.enterText(
      find.byKey(const ValueKey('task-title')),
      'حجز القاعة',
    );
    await tester.tap(find.byKey(const ValueKey('task-who-member:user-saleh')));
    await tester.pumpAndSettle();
    await _save(tester);

    expect(provider.saves, 1);
    expect(find.byKey(const ValueKey('task-message-sheet')), findsOneWidget);
    expect(find.text('ترسل المهمة لـصالح؟'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('task-message-whatsapp')));
    await tester.pumpAndSettle();
    final text = Uri.parse(launched.single).queryParameters['text']!;
    expect(Uri.parse(launched.single).path, '/967777000222');
    expect(text, startsWith('السلام عليكم، معك رشاد.'));
    // No chosen plan here, so its name is left out, not guessed.
    expect(text, contains('هذي مهمتك:\nحجز القاعة'));

    // «أنا» on an account plan is the reader's own account.
    final again = await _pumpAccount(tester);
    await tester.enterText(
      find.byKey(const ValueKey('task-title')),
      'حجز القاعة',
    );
    await _save(tester);
    expect(again.saves, 1);
    expect(find.byKey(const ValueKey('task-message-sheet')), findsNothing);
  });

  // From the review of this branch: a member whose number the phone does
  // not have fell back to the number of whoever had the task before, so the
  // offer named the new person and opened the old one's chat.
  testWidgets('a task moved to a member without a number goes to nobody else', (
    tester,
  ) async {
    final task = WeddingTask(
      id: 'task-1',
      weddingPlanId: _accountPlan,
      title: 'حجز القاعة',
      assigneeUserId: 'user-saleh',
      assigneeName: 'صالح',
      assigneePhone: '+967777000222',
      status: 'TODO',
      priority: 'MEDIUM',
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, 1),
    );
    final provider = await _pumpAccount(
      tester,
      editing: task,
      more: [
        SharedMember(
          id: 'member-user-ali',
          weddingPlanId: _accountPlan,
          userId: 'user-ali',
          role: 'HELPER',
          canViewMoney: false,
          canManageTasks: true,
          canManageMoney: false,
          isOwner: false,
          createdAt: DateTime(2026, 11, 1),
          updatedAt: DateTime(2026, 11, 1),
        ),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('task-who-member:user-ali')));
    await tester.pumpAndSettle();
    await _save(tester);

    expect(provider.updates, 1);
    expect(find.byKey(const ValueKey('task-message-sheet')), findsNothing);
    expect(launched, isEmpty);
  });

  testWidgets('an edit offers it only when the person changed', (tester) async {
    final task = WeddingTask(
      id: 'task-1',
      weddingPlanId: _localPlan,
      title: 'حجز القاعة',
      responsibleName: 'محمد',
      responsiblePhone: '+967777123456',
      responsibleSource: 'MANUAL',
      status: 'TODO',
      priority: 'MEDIUM',
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, 1),
    );

    final same = await _pumpNew(tester, editing: task);
    await tester.enterText(
      find.byKey(const ValueKey('task-title')),
      'حجز القاعة الكبيرة',
    );
    await _save(tester);
    expect(same.updates, 1);
    expect(find.byKey(const ValueKey('task-message-sheet')), findsNothing);

    final other = await _pumpNew(tester, editing: task);
    await _chooseOther(tester, name: 'علي', phone: '777000333');
    await _save(tester);
    expect(other.updates, 1);
    expect(find.byKey(const ValueKey('task-message-sheet')), findsOneWidget);
    expect(find.text('ترسل المهمة لـعلي؟'), findsOneWidget);
  });
}

Future<_SavingProvider> _pumpNew(
  WidgetTester tester, {
  TaskMessageMode? mode,
  WeddingTask? editing,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1400);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final stored = await SharedPreferences.getInstance();
  final preferences = DevicePreferences(stored);
  if (mode != null) await preferences.setTaskMessageMode(mode);
  final provider = _SavingProvider();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: AuthStorage(stored)),
        ChangeNotifierProvider<TaskTimelineProvider>.value(value: provider),
        ChangeNotifierProvider<DevicePreferences>.value(value: preferences),
      ],
      child: MaterialApp.router(
        routerConfig: _router(
          editing == null
              ? const CreateTaskScreen(weddingPlanId: _localPlan)
              : CreateTaskScreen(
                  weddingPlanId: _localPlan,
                  taskId: editing.id,
                  initialTask: editing,
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return provider;
}

Future<_SavingProvider> _pumpAccount(
  WidgetTester tester, {
  WeddingTask? editing,
  List<SharedMember> more = const [],
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1400);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final stored = await SharedPreferences.getInstance();
  final storage = AuthStorage(stored);
  const user = SafeUser(
    id: 'user-1',
    name: 'رشاد',
    phone: '+967777000111',
    role: 'USER',
    status: 'ACTIVE',
  );
  await storage.saveSession(accessToken: 'token', user: user);
  final api = ApiClient(tokenProvider: storage.readAccessToken);
  final provider = _SavingProvider();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: storage),
        ChangeNotifierProvider<TaskTimelineProvider>.value(value: provider),
        ChangeNotifierProvider<DevicePreferences>.value(
          value: DevicePreferences(stored),
        ),
        ChangeNotifierProvider<AuthController>.value(
          value: _SignedIn(AuthRepository(api, storage), user),
        ),
        ChangeNotifierProvider<SharingProvider>.value(
          value: _Members(api, [
            _member('user-1', 'رشاد', '+967777000111'),
            _member('user-saleh', 'صالح', '+967777000222'),
            ...more,
          ]),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: _router(
          editing == null
              ? const CreateTaskScreen(weddingPlanId: _accountPlan)
              : CreateTaskScreen(
                  weddingPlanId: _accountPlan,
                  taskId: editing.id,
                  initialTask: editing,
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return provider;
}

GoRouter _router(Widget start) => GoRouter(
  initialLocation: '/start',
  routes: [
    GoRoute(path: '/start', builder: (context, state) => start),
    GoRoute(
      path: appRoute('/wedding-plans/:id/tasks'),
      builder: (context, state) => const Scaffold(body: Text('tasks-target')),
    ),
  ],
);

Future<void> _fillAndSave(
  WidgetTester tester, {
  required String name,
  String? phone,
}) async {
  await tester.enterText(
    find.byKey(const ValueKey('task-title')),
    'حجز القاعة',
  );
  await _chooseOther(tester, name: name, phone: phone);
  await _save(tester);
}

Future<void> _chooseOther(
  WidgetTester tester, {
  required String name,
  String? phone,
}) async {
  final other = find.byKey(const ValueKey('task-who-other'));
  await tester.ensureVisible(other);
  await tester.tap(other);
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('task-other-name')), name);
  if (phone != null) {
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('task-other-phone')),
        matching: find.byType(EditableText),
      ),
      phone,
    );
  }
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('task-save')));
  await tester.pumpAndSettle();
}

SharedMember _member(String userId, String name, String phone) => SharedMember(
  id: 'member-$userId',
  weddingPlanId: _accountPlan,
  userId: userId,
  user: SharedMemberUser(id: userId, name: name, phone: phone),
  role: userId == 'user-1' ? 'OWNER' : 'HELPER',
  canViewMoney: false,
  canManageTasks: true,
  canManageMoney: false,
  isOwner: userId == 'user-1',
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
);

/// Saves every task at once, as the phone does with no connection.
class _SavingProvider extends TaskTimelineProvider {
  _SavingProvider()
    : super(TaskTimelineApi(ApiClient(tokenProvider: () async => null)));

  int saves = 0;
  int updates = 0;

  @override
  Future<void> load(String weddingPlanId) async {}

  @override
  Future<bool> createTask({
    required String weddingPlanId,
    required String title,
    String? description,
    DateTime? dueDate,
    String? taskCategory,
    String? assigneeUserId,
    String? assigneeName,
    String? assigneePhone,
    String? assigneeRole,
    String? responsibleName,
    String? responsiblePhone,
    String? responsibleSource,
    String status = 'TODO',
    String priority = 'MEDIUM',
    bool isPrivate = false,
  }) async {
    saves += 1;
    return true;
  }

  @override
  Future<bool> updateTask({
    required String weddingPlanId,
    required WeddingTask task,
    required String title,
    String? description,
    DateTime? dueDate,
    String? taskCategory,
    String? assigneeUserId,
    String? assigneeName,
    String? assigneePhone,
    String? assigneeRole,
    String? responsibleName,
    String? responsiblePhone,
    String? responsibleSource,
    required String status,
    required String priority,
  }) async {
    updates += 1;
    return true;
  }
}

class _SignedIn extends AuthController {
  _SignedIn(super.repository, this._user);

  final SafeUser _user;

  @override
  SafeUser? get user => _user;
}

class _Members extends SharingProvider {
  _Members(ApiClient api, this._members) : super(SharingApi(api));

  final List<SharedMember> _members;

  @override
  List<SharedMember> get members => _members;

  @override
  Future<void> loadMembers(
    String weddingPlanId, {
    bool preserveCurrentState = false,
  }) async {}
}
