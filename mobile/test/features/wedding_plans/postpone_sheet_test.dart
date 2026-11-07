import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/tasks/tasks_api.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/postpone_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// g03 «تأجيل العرس»: what moves, then two calls (date, then tasks).

final _oldDay = DateTime(2027, 1, 21);

class _Api extends ApiClient {
  _Api() : super(tokenProvider: () async => 'token');

  @override
  Future<List<dynamic>> getJsonList(String path) async => [
    {
      'providerName': 'قاعة السعادة',
      'eventDate': '2027-01-20T21:00:00.000Z',
      'status': 'CONFIRMED',
    },
  ];
}

class _Tasks extends TaskTimelineApi {
  _Tasks(super.apiClient);

  final shifted = <int>[];
  final requestIds = <String>[];
  bool failShift = false;

  @override
  Future<List<WeddingTask>> getTasks(String weddingPlanId) async => [
    _task('t1', due: DateTime(2027, 1, 1)),
    _task('t2', due: DateTime(2027, 1, 10)),
    _task('t3', due: DateTime(2026, 12, 1), status: 'DONE'),
    _task('t4'),
  ];

  @override
  Future<int> shiftOpenDueDates(
    String weddingPlanId,
    int days, {
    required String clientRequestId,
  }) async {
    requestIds.add(clientRequestId);
    if (failShift) throw Exception('offline');
    shifted.add(days);
    return 2;
  }
}

WeddingTask _task(String id, {DateTime? due, String status = 'TODO'}) =>
    WeddingTask(
      id: id,
      weddingPlanId: 'plan-1',
      title: id,
      status: status,
      priority: 'MEDIUM',
      dueDate: due,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

class _Plans extends WeddingPlansProvider {
  _Plans(super.api);

  final saved = <Map<String, dynamic>>[];

  @override
  Future<WeddingPlan?> updateWeddingPlan(
    String id,
    Map<String, dynamic> data,
  ) async {
    saved.add(data);
    return WeddingPlan.fromJson({
      'id': id,
      'ownerUserId': 'u1',
      'title': 'عرس محمد',
      'weddingDate': data['weddingDate'],
      'currency': 'YER',
      'status': 'PLANNING',
      'createdAt': '2026-01-01T00:00:00.000Z',
      'updatedAt': '2026-01-01T00:00:00.000Z',
    });
  }
}

class _Dashboard extends DashboardSummaryProvider {
  _Dashboard(WeddingPlansApi api) : super(weddingPlansApi: api);

  @override
  Future<void> loadDashboard(String weddingPlanId, {sharedMember}) async {}
}

Future<(_Tasks, _Plans)> _open(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 900);
  addTearDown(tester.view.reset);
  final api = _Api();
  final tasks = _Tasks(api);
  final plans = _Plans(WeddingPlansApi(api));
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<TaskTimelineApi>.value(value: tasks),
        ChangeNotifierProvider<WeddingPlansProvider>.value(value: plans),
        ChangeNotifierProvider<DashboardSummaryProvider>.value(
          value: _Dashboard(WeddingPlansApi(api)),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showPostponeSheet(
                  context,
                  planId: 'plan-1',
                  weddingDate: _oldDay,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (tasks, plans);
}

Future<void> _pickApril15(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('postpone-new-day')));
  await tester.pumpAndSettle();
  // The picker opens on the old day plus a month: move to April.
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, '04/15/2027');
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('g03 shows what moves and keeps payments on their dates', (
    tester,
  ) async {
    await _open(tester);

    expect(find.text('تأجيل العرس'), findsOneWidget);
    expect(find.text('21 يناير'), findsOneWidget);
    expect(find.text('اختر اليوم'), findsOneWidget);

    await _pickApril15(tester);

    expect(find.text('15 أبريل'), findsOneWidget);
    // Two open dated tasks; the done one and the undated one stay.
    expect(find.text('مهمتين تنتقل 84 يوم'), findsOneWidget);
    expect(find.text('حجز واحد على اليوم القديم'), findsOneWidget);
    expect(find.text('الدفعات تبقى على مواعيدها'), findsOneWidget);
    expect(find.textContaining('أقساط'), findsNothing);
    expect(find.textContaining('الضيوف'), findsNothing);
  });

  testWidgets('g03 saves the day, then moves the tasks by the same days', (
    tester,
  ) async {
    final (tasks, plans) = await _open(tester);
    await _pickApril15(tester);

    await tester.tap(find.byKey(const ValueKey('postpone-apply')));
    await tester.pumpAndSettle();

    expect(plans.saved, [
      {'weddingDate': '2027-04-15'},
    ]);
    expect(tasks.shifted, [84]);
    expect(find.text('تأجيل العرس'), findsNothing);
  });

  testWidgets('g03 retries only the tasks when they did not move', (
    tester,
  ) async {
    final (tasks, plans) = await _open(tester);
    tasks.failShift = true;
    await _pickApril15(tester);

    await tester.tap(find.byKey(const ValueKey('postpone-apply')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('postpone-error')), findsOneWidget);
    expect(find.text('انقل المهام'), findsOneWidget);

    tasks.failShift = false;
    await tester.tap(find.byKey(const ValueKey('postpone-apply')));
    await tester.pumpAndSettle();

    expect(plans.saved, hasLength(1));
    expect(tasks.shifted, [84]);
    // RA-BE-71: the move is relative; a retry after a lost answer is the
    // same request, so the server answers it once and the tasks move once.
    expect(tasks.requestIds, hasLength(2));
    expect(tasks.requestIds.toSet(), hasLength(1));
  });
}
