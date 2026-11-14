import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/tasks/data/task_timeline_api.dart';
import 'package:aarast_mobile/features/tasks/models/task_summary.dart';
import 'package:aarast_mobile/features/tasks/models/timeline.dart';
import 'package:aarast_mobile/features/tasks/models/wedding_task.dart';
import 'package:aarast_mobile/features/tasks/providers/task_timeline_provider.dart';
import 'package:aarast_mobile/features/tasks/screens/create_task_screen.dart';
import 'package:aarast_mobile/features/tasks/screens/task_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// d04: the task's person is reached with the task already written, on
// WhatsApp or as a text; with no number the page says so and leads to
// where the number is written.

const _plan = 'guest-plan-details';

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

  testWidgets('WhatsApp opens the chat with the task written', (tester) async {
    await _pump(tester, _task(phone: '+967777123456'));

    await tester.tap(find.byKey(const ValueKey('task-contact-whatsapp')));
    await tester.pumpAndSettle();

    final uri = Uri.parse(launched.single);
    expect(uri.host, 'wa.me');
    expect(uri.path, '/967777123456');
    final text = uri.queryParameters['text']!;
    expect(text, contains('حجز القاعة'));
    expect(text, contains('ملاحظة: قاعة سبأ'));
    expect(text, contains('الموعد: '));
  });

  testWidgets('«رسالة نصية» sends the same words to the same number', (
    tester,
  ) async {
    await _pump(tester, _task(phone: '+967777123456'));

    expect(
      find.bySemanticsLabel('أرسل المهمة لـمحمد برسالة نصية'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('task-contact-sms')));
    await tester.pumpAndSettle();

    final uri = Uri.parse(launched.single);
    expect(uri.scheme, 'sms');
    expect(uri.path, '+967777123456');
    expect(uri.queryParameters['body'], contains('حجز القاعة'));
  });

  testWidgets('the send buttons are full touch targets', (tester) async {
    await _pump(tester, _task(phone: '+967777123456'));

    for (final key in ['task-contact-whatsapp', 'task-contact-sms']) {
      expect(
        tester.getSize(find.byKey(ValueKey(key))).height,
        greaterThanOrEqualTo(48),
        reason: key,
      );
    }
  });

  testWidgets('no number: said plainly, and «أضف الرقم» opens where it goes', (
    tester,
  ) async {
    await _pump(tester, _task());

    expect(find.byKey(const ValueKey('task-contact')), findsNothing);
    expect(find.byKey(const ValueKey('task-contact-no-phone')), findsOneWidget);
    expect(find.textContaining('ما عندنا رقم لـمحمد'), findsOneWidget);

    final add = find.byKey(const ValueKey('task-contact-add-phone'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();

    // The edit opens on «شخص ثاني» with the name typed and the number's
    // field waiting.
    expect(find.byType(CreateTaskScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('task-other-phone')), findsOneWidget);
    final name = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('task-other-name')),
        matching: find.byType(EditableText),
      ),
    );
    expect(name.controller.text, 'محمد');
  });

  testWidgets('the reader\'s own task shows no send at all', (tester) async {
    await _pump(
      tester,
      _task(phone: '+967777123456').copyWith(responsibleName: 'أنا'),
    );

    expect(find.byKey(const ValueKey('task-contact')), findsNothing);
    expect(find.byKey(const ValueKey('task-contact-no-phone')), findsNothing);
  });
}

WeddingTask _task({String? phone}) => WeddingTask(
  id: 'task-1',
  weddingPlanId: _plan,
  title: 'حجز القاعة',
  description: 'قاعة سبأ',
  dueDate: DateTime(2027, 1, 14),
  responsibleName: 'محمد',
  responsiblePhone: phone,
  responsibleSource: 'MANUAL',
  status: 'TODO',
  priority: 'MEDIUM',
  createdAt: DateTime.utc(2026, 11, 1),
  updatedAt: DateTime.utc(2026, 11, 1),
);

Future<void> _pump(WidgetTester tester, WeddingTask task) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1400);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final stored = await SharedPreferences.getInstance();
  final provider = TaskTimelineProvider(_OneTask(task));
  await provider.load(_plan);
  final router = GoRouter(
    initialLocation: '/wedding-plans/$_plan/tasks/${task.id}',
    routes: [
      GoRoute(
        path: '/wedding-plans/:id/tasks',
        builder: (context, state) => const Scaffold(body: Text('tasks')),
        routes: [
          GoRoute(
            path: ':taskId',
            builder: (context, state) => TaskDetailsScreen(
              weddingPlanId: _plan,
              taskId: state.pathParameters['taskId']!,
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => CreateTaskScreen(
                  weddingPlanId: _plan,
                  taskId: state.pathParameters['taskId'],
                  initialTask: state.extra as WeddingTask?,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: AuthStorage(stored)),
        ChangeNotifierProvider<TaskTimelineProvider>.value(value: provider),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _OneTask extends TaskTimelineApi {
  _OneTask(this.task) : super(ApiClient(tokenProvider: () async => null));

  final WeddingTask task;

  @override
  Future<List<WeddingTask>> getTasks(String weddingPlanId) async => [task];

  @override
  Future<Timeline> getTimeline(String weddingPlanId) async => Timeline.empty();

  @override
  Future<TaskSummary> getTaskSummary(String weddingPlanId) async =>
      TaskSummary.empty(weddingPlanId);
}
