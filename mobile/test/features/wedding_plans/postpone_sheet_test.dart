import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/utils/app_clock.dart';
import 'package:aarast_mobile/features/tasks/tasks_api.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/postpone_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// g03 «تأجيل العرس»: what moves, then one save: the day and its open tasks
// (RA-BE-116).

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

  @override
  Future<List<WeddingTask>> getTasks(String weddingPlanId) async => [
    _task('t1', due: DateTime(2027, 1, 1)),
    _task('t2', due: DateTime(2027, 1, 10)),
    _task('t3', due: DateTime(2026, 12, 1), status: 'DONE'),
    // RA-MO-58: a cancelled task stays where it is, as on the server.
    _task('t5', due: DateTime(2026, 12, 20), status: 'CANCELLED'),
    _task('t4'),
  ];
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
  bool fail = false;

  @override
  String? get errorMessage => fail ? 'ما وصلنا للخادم.' : null;

  @override
  Future<WeddingPlan?> updateWeddingPlan(
    String id,
    Map<String, dynamic> data,
  ) async {
    saved.add(data);
    if (fail) return null;
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

Future<(_Tasks, _Plans)> _open(
  WidgetTester tester, {
  DateTime? weddingDate,
}) async {
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
                  weddingDate: weddingDate ?? _oldDay,
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

Future<void> _pickApril15(WidgetTester tester) => _pick(tester, '04/15/2027');

Future<void> _pick(WidgetTester tester, String day) async {
  await tester.tap(find.byKey(const ValueKey('postpone-new-day')));
  await tester.pumpAndSettle();
  // The picker opens on the old day plus a month: move to the day.
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, day);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  // RA-MO-351: the picker's day was the phone's; its clock is pinned, so
  // the sheet reads the same day every year (it broke alone after
  // 2027-02-20, when the old day plus a month fell before today).
  setUp(() => pinAppClock(DateTime.utc(2026, 11, 24, 9)));
  tearDown(resetAppClock);

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

  testWidgets('g03 saves the day and its open tasks in one save', (
    tester,
  ) async {
    final (_, plans) = await _open(tester);
    await _pickApril15(tester);

    await tester.tap(find.byKey(const ValueKey('postpone-apply')));
    await tester.pumpAndSettle();

    // The server moves the open tasks by the day's own difference (84).
    expect(plans.saved, [
      {'weddingDate': '2027-04-15', 'moveOpenTasks': true},
    ]);
    expect(find.text('تأجيل العرس'), findsNothing);
  });

  testWidgets('g03 a save that did not go through says so and is tried as it '
      'was', (tester) async {
    final (_, plans) = await _open(tester);
    plans.fail = true;
    await _pickApril15(tester);

    await tester.tap(find.byKey(const ValueKey('postpone-apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('postpone-error')), findsOneWidget);
    expect(find.text('ما وصلنا للخادم.'), findsOneWidget);

    plans.fail = false;
    await tester.tap(find.byKey(const ValueKey('postpone-apply')));
    await tester.pumpAndSettle();
    // RA-BE-71, RA-BE-116: the same save again; the server finds the day
    // moved already and moves nothing twice.
    expect(plans.saved, [
      {'weddingDate': '2027-04-15', 'moveOpenTasks': true},
      {'weddingDate': '2027-04-15', 'moveOpenTasks': true},
    ]);
    expect(find.text('تأجيل العرس'), findsNothing);
  });

  // RA-MO-351: more than a month after the wedding, the old day plus a
  // month is before today, the first day the picker allows: it failed its
  // own assertion. RA-MO-354: and today is Sana'a's (01:00 on the 30th
  // there, still the 29th on this phone).
  testWidgets('after the wedding the picker opens on today in Sana\'a', (
    tester,
  ) async {
    pinAppClock(DateTime.utc(2027, 3, 29, 22));
    await _open(tester);

    // After the day it is no postponing: the day is put right.
    expect(find.text('تعديل تاريخ العرس'), findsOneWidget);
    expect(find.text('تأجيل العرس'), findsNothing);
    expect(find.byKey(const ValueKey('postpone-no-date')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('postpone-new-day')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(find.text('Tue, Mar 30'), findsOneWidget);
  });

  testWidgets('the picker never opens past the last day it allows', (
    tester,
  ) async {
    await _open(tester, weddingDate: DateTime(2030, 12, 20));

    await tester.tap(find.byKey(const ValueKey('postpone-new-day')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Wed, Jan 1'), findsOneWidget);
  });

  // RA-BE-183 (Q-47): a wedding put off with no new day yet has none.
  testWidgets('«تأجل وما حددنا موعد» clears the day', (tester) async {
    final (_, plans) = await _open(tester);

    final noDate = find.byKey(const ValueKey('postpone-no-date'));
    await tester.ensureVisible(noDate);
    await tester.tap(noDate);
    await tester.pumpAndSettle();

    expect(plans.saved, [
      {'weddingDate': null},
    ]);
    expect(find.text('تأجيل العرس'), findsNothing);
  });

  // RA-MO-356: «بعد عيد الأضحى» was said on the Eid itself.
  testWidgets('the Eid is named on its own day', (tester) async {
    await _open(tester);

    await _pick(tester, '05/16/2027');
    expect(find.text('يوم عيد الأضحى · 10 ذو الحجة'), findsOneWidget);

    await _pick(tester, '03/09/2027');
    expect(find.text('يوم عيد الفطر · 1 شوال'), findsOneWidget);

    await _pick(tester, '05/17/2027');
    expect(find.text('بعد عيد الأضحى · 11 ذو الحجة'), findsOneWidget);
  });
}
