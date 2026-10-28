import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/wedding_day/data/plan_events_api.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:aarast_mobile/features/wedding_day/providers/plan_events_provider.dart';
import 'package:aarast_mobile/features/wedding_day/screens/plan_events_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// D65: b12 «مناسبات عرسك», b13 «تعديل مناسبة», and the week and day the
// home builds from them.

PlanEventsView _view({bool canEdit = true}) => PlanEventsView.fromJson({
  'weddingPlanId': 'plan-1',
  'canEdit': canEdit,
  'party': 'GROOM',
  'items': [
    {
      'id': 'samra',
      'type': 'SAMRA',
      'date': '2027-01-19',
      'timeSlot': 'AFTER_ISHA',
      'placeLabel': 'الديوان',
    },
    {
      'id': 'maqeel',
      'type': 'MAQEEL',
      'date': '2027-01-20',
      'timeSlot': 'AFTER_DHUHR',
      'placeLabel': 'بيت الوالد',
      'note': 'القات عند صالح',
    },
    {
      'id': null,
      'type': 'WEDDING',
      'date': '2027-01-21',
      'timeSlot': null,
      'isMain': true,
    },
  ],
  'suggestions': ['AQD', 'LUNCH', 'DINNER', 'CUSTOM'],
});

class _Api extends PlanEventsApi {
  _Api(this.view) : super(ApiClient(tokenProvider: () async => null));

  PlanEventsView view;
  final created = <(PlanEventType, Map<String, dynamic>)>[];
  final updated = <(String, Map<String, dynamic>)>[];

  @override
  Future<PlanEventsView> list(String weddingPlanId) async => view;

  @override
  Future<PlanEvent> create(
    String weddingPlanId,
    PlanEventType type,
    PlanEventDraft draft,
  ) async {
    created.add((type, draft.toJson(isMain: type == PlanEventType.wedding)));
    return PlanEvent(id: 'new', type: type);
  }

  @override
  Future<PlanEvent> update(
    String weddingPlanId,
    PlanEvent event,
    PlanEventDraft draft,
  ) async {
    updated.add((event.id!, draft.toJson(isMain: event.isMain)));
    return event;
  }
}

Future<void> _pump(
  WidgetTester tester,
  PlanEventsProvider provider, {
  JourneyProfile profile = JourneyProfile.groom,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(400, 1600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<PlanEventsProvider>.value(
      value: provider,
      child: MaterialApp(
        home: JourneyProfileScope(
          profile: profile,
          child: const Directionality(
            textDirection: TextDirection.rtl,
            child: PlanEventsScreen(weddingPlanId: 'plan-1'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('the week is the six days before the wedding and its day', () {
    final view = _view();
    final wedding = DateTime(2027, 1, 21);
    expect(view.weekOf(wedding).map((event) => event.type), [
      PlanEventType.samra,
      PlanEventType.maqeel,
      PlanEventType.wedding,
    ]);
    expect(view.weekOf(DateTime(2027, 2, 21)), isEmpty);
    expect(view.dayOf(wedding).single.isMain, isTrue);
  });

  test('on the day, the item that started last is «الآن» (b05)', () {
    final program = [
      const PlanEvent(
        id: 'a',
        type: PlanEventType.lunch,
        slot: PlanEventSlot.dhuhr,
      ),
      const PlanEvent(
        id: 'b',
        type: PlanEventType.wedding,
        slot: PlanEventSlot.afterAsr,
      ),
      const PlanEvent(
        id: 'c',
        type: PlanEventType.dinner,
        slot: PlanEventSlot.afterIsha,
      ),
    ];
    expect(programMoments(program, DateTime(2027, 1, 21, 10)), [
      PlanEventMoment.next,
      PlanEventMoment.next,
      PlanEventMoment.next,
    ]);
    expect(programMoments(program, DateTime(2027, 1, 21, 16)), [
      PlanEventMoment.done,
      PlanEventMoment.now,
      PlanEventMoment.next,
    ]);
    expect(programMoments(program, DateTime(2027, 1, 21, 23)), [
      PlanEventMoment.done,
      PlanEventMoment.done,
      PlanEventMoment.now,
    ]);
  });

  test('the wedding is «الزفاف» in his plan and «الزفة» in hers', () {
    expect(PlanEventType.wedding.label(JourneyProfile.groom), 'الزفاف');
    expect(PlanEventType.wedding.label(JourneyProfile.bride), 'الزفة');
    expect(PlanEventType.nashma.label(JourneyProfile.bride), 'النسمة');
  });

  test('b13 sends every field; the wedding never sends a day', () {
    final draft = PlanEventDraft(
      date: DateTime(2027, 1, 20),
      slot: PlanEventSlot.afterAsr,
      exactTime: '16:00',
      placeLabel: ' بيت الوالد ',
      responsibleName: '',
    );
    expect(draft.toJson(isMain: false), {
      'title': null,
      'date': '2027-01-20',
      'timeSlot': 'AFTER_ASR',
      'exactTime': null,
      'placeLabel': 'بيت الوالد',
      'responsibleName': null,
      'note': null,
    });
    expect(draft.toJson(isMain: true).containsKey('date'), isFalse);
  });

  testWidgets('b12 lists the events with their tags and the suggestions', (
    tester,
  ) async {
    final provider = PlanEventsProvider(api: _Api(_view()));
    await _pump(tester, provider);

    expect(find.text('مناسبات عرسك'), findsOneWidget);
    expect(find.text('منها يتبنى أسبوع العرس ويوم العرس'), findsOneWidget);
    expect(find.text('السمرة'), findsOneWidget);
    expect(find.text('الثلاثاء 19 يناير · بعد العشاء'), findsOneWidget);
    expect(find.text('الديوان'), findsOneWidget);
    expect(find.text('القات عند صالح'), findsOneWidget);
    expect(find.text('الزفاف'), findsOneWidget);
    expect(find.text('المناسبة الرئيسية'), findsOneWidget);
    expect(find.text('اقتراحات'), findsOneWidget);
    expect(find.text('عقد القران'), findsOneWidget);
    expect(find.text('مناسبة ثانية'), findsOneWidget);
    expect(find.byTooltip('تعديل السمرة'), findsOneWidget);
  });

  testWidgets('a member who only follows reads them without a control (D52)', (
    tester,
  ) async {
    final provider = PlanEventsProvider(api: _Api(_view(canEdit: false)));
    await _pump(tester, provider);

    expect(find.text('السمرة'), findsOneWidget);
    expect(find.text('اقتراحات'), findsNothing);
    expect(find.byTooltip('تعديل السمرة'), findsNothing);
  });

  testWidgets('b13 saves an edit with its time and place', (tester) async {
    final api = _Api(_view());
    final provider = PlanEventsProvider(api: api);
    await _pump(tester, provider);

    await tester.tap(find.byTooltip('تعديل المقيل'));
    await tester.pumpAndSettle();
    expect(find.text('يظهر في برنامج الأسبوع ويوم العرس'), findsOneWidget);
    expect(find.text('الأربعاء 20'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-event-slot-AFTER_ASR')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-event-save')));
    await tester.pumpAndSettle();

    expect(api.updated.single.$1, 'maqeel');
    expect(api.updated.single.$2['timeSlot'], 'AFTER_ASR');
    expect(api.updated.single.$2['date'], '2027-01-20');
    expect(api.updated.single.$2['note'], 'القات عند صالح');
  });

  testWidgets('a new custom event asks for its name first', (tester) async {
    final api = _Api(_view());
    final provider = PlanEventsProvider(api: api);
    await _pump(tester, provider);

    await tester.tap(find.byKey(const ValueKey('plan-event-suggest-CUSTOM')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('plan-event-save')));
    await tester.pumpAndSettle();
    expect(find.text('اكتب اسم المناسبة'), findsOneWidget);
    expect(api.created, isEmpty);

    await tester.enterText(find.byType(TextField).first, 'الحناء');
    await tester.tap(find.byKey(const ValueKey('plan-event-save')));
    await tester.pumpAndSettle();
    expect(api.created.single.$1, PlanEventType.custom);
    expect(api.created.single.$2['title'], 'الحناء');
  });

  testWidgets('the wedding day is the plan date and is not picked here', (
    tester,
  ) async {
    final provider = PlanEventsProvider(api: _Api(_view()));
    await _pump(tester, provider);

    await tester.tap(find.byTooltip('تعديل الزفاف'));
    await tester.pumpAndSettle();
    expect(find.text('يتغير من «أجّل العرس»'), findsOneWidget);
    expect(find.text('احذف المناسبة'), findsNothing);
  });
}
