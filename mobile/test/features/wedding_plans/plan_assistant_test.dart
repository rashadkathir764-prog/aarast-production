import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_plans/data/plan_assistant_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/plan_assistant.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/plan_assistant_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/plan_assistant_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The planning assistant in the app (V1 checklist 4.12).

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the status and the answer read from the server', () {
    final status = PlanAssistantStatus.fromJson({
      'enabled': true,
      'allowed': true,
      'dailyLimit': 10,
      'remainingToday': 4,
    });
    expect(status.available, isTrue);
    expect(PlanAssistantStatus.fromJson({'enabled': true}).available, isFalse);
    final answer = PlanAssistantAnswer.fromJson({
      'answer': 'خطة',
      'declined': false,
      'marketDataAvailable': true,
      'remainingToday': 3,
    });
    expect(answer.answer, 'خطة');
    expect(answer.remainingToday, 3);
    expect(
      PlanAssistantKind.values.map((kind) => kind.apiValue),
      [
        'PLAN',
        'BUDGET_SPLIT',
        'COMPARE_QUOTES',
        'CHEAPER',
        'FORGOTTEN',
        'NEGOTIATION',
        'QUESTION',
      ],
    );
  });

  Widget app(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Directionality(textDirection: TextDirection.rtl, child: child),
  );

  testWidgets('consent comes before the first question, then the answer shows', (
    tester,
  ) async {
    final api = _FakeAssistantApi();
    await tester.pumpWidget(
      app(PlanAssistantScreen(weddingPlanId: 'plan-1', api: api)),
    );
    await tester.pumpAndSettle();
    expect(find.text('باقي لك اليوم 2 من 3 أسئلة'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('assistant-kind-BUDGET_SPLIT')));
    await tester.pumpAndSettle();
    expect(find.text('قبل أن تسأل المساعد'), findsOneWidget);
    expect(api.asked, isEmpty, reason: 'nothing is sent before consent');

    await tester.tap(find.byKey(const ValueKey('assistant-consent-agree')));
    await tester.pumpAndSettle();
    expect(api.asked, [PlanAssistantKind.budgetSplit]);
    expect(find.byKey(const ValueKey('assistant-answer')), findsOneWidget);
    expect(find.text('وزّع 40% للقاعة'), findsOneWidget);
    expect(find.byKey(const ValueKey('assistant-no-market')), findsOneWidget);
    expect(find.text('باقي لك اليوم 1 من 3 أسئلة'), findsOneWidget);

    // Consent is remembered: the next question goes straight out.
    await tester.tap(find.byKey(const ValueKey('assistant-kind-FORGOTTEN')));
    await tester.pumpAndSettle();
    expect(find.text('قبل أن تسأل المساعد'), findsNothing);
    expect(api.asked.last, PlanAssistantKind.forgotten);
  });

  testWidgets('a free question needs its text and is sent with it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'aarast.assistant.consent.v1.device': true,
    });
    final api = _FakeAssistantApi();
    await tester.pumpWidget(
      app(PlanAssistantScreen(weddingPlanId: 'plan-1', api: api)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assistant-send')));
    await tester.pumpAndSettle();
    expect(api.asked, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('assistant-question')),
      'كم أخصص للتصوير؟',
    );
    await tester.tap(find.byKey(const ValueKey('assistant-send')));
    await tester.pumpAndSettle();
    expect(api.asked, [PlanAssistantKind.question]);
    expect(api.questions, ['كم أخصص للتصوير؟']);
  });

  testWidgets('a refusal from the server is shown in Arabic', (tester) async {
    SharedPreferences.setMockInitialValues({
      'aarast.assistant.consent.v1.device': true,
    });
    final api = _FakeAssistantApi(
      failure: const ApiException(
        'انتهت أسئلة اليوم. عد غدًا.',
        statusCode: 429,
        serverCode: 'ASSISTANT_DAILY_LIMIT',
      ),
    );
    await tester.pumpWidget(
      app(PlanAssistantScreen(weddingPlanId: 'plan-1', api: api)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assistant-kind-PLAN')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assistant-error')), findsOneWidget);
    expect(find.text('انتهت أسئلة اليوم. عد غدًا.'), findsOneWidget);
  });

  testWidgets('a relative or a switched-off service sees why, not the tools', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        PlanAssistantScreen(
          weddingPlanId: 'plan-1',
          api: _FakeAssistantApi(allowed: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assistant-not-allowed')), findsOneWidget);
    expect(find.byKey(const ValueKey('assistant-kind-PLAN')), findsNothing);

    await tester.pumpWidget(
      app(
        PlanAssistantScreen(
          weddingPlanId: 'plan-2',
          api: _FakeAssistantApi(enabled: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assistant-off')), findsOneWidget);
  });

  testWidgets('the home door shows only when the assistant is for the reader', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(PlanAssistantEntry(weddingPlanId: 'plan-1', api: _FakeAssistantApi())),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assistant-entry')), findsOneWidget);

    await tester.pumpWidget(
      app(
        PlanAssistantEntry(
          weddingPlanId: 'plan-2',
          api: _FakeAssistantApi(allowed: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assistant-entry')), findsNothing);
  });
}

class _FakeAssistantApi extends PlanAssistantApi {
  _FakeAssistantApi({this.enabled = true, this.allowed = true, this.failure})
    : super(ApiClient(tokenProvider: () async => null));

  final bool enabled;
  final bool allowed;
  final ApiException? failure;
  final List<PlanAssistantKind> asked = [];
  final List<String?> questions = [];
  int _remaining = 2;

  @override
  Future<PlanAssistantStatus> status(String weddingPlanId) async =>
      PlanAssistantStatus(
        enabled: enabled,
        allowed: allowed,
        dailyLimit: 3,
        remainingToday: _remaining,
      );

  @override
  Future<PlanAssistantAnswer> ask(
    String weddingPlanId, {
    required PlanAssistantKind kind,
    String? question,
  }) async {
    if (failure != null) throw failure!;
    asked.add(kind);
    questions.add(question);
    _remaining -= 1;
    return PlanAssistantAnswer(
      answer: 'وزّع 40% للقاعة',
      declined: false,
      marketDataAvailable: false,
      remainingToday: _remaining,
    );
  }
}
