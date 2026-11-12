import 'dart:async';

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
    expect(PlanAssistantKind.values.map((kind) => kind.apiValue), [
      'PLAN',
      'BUDGET_SPLIT',
      'COMPARE_QUOTES',
      'CHEAPER',
      'FORGOTTEN',
      'NEGOTIATION',
      'QUESTION',
    ]);
  });

  Widget app(Widget child) => MaterialApp(
    theme: AppTheme.light(),
    home: Directionality(textDirection: TextDirection.rtl, child: child),
  );

  testWidgets(
    'consent comes before the first question, then the answer shows',
    (tester) async {
      final api = _FakeAssistantApi();
      await tester.pumpWidget(
        app(PlanAssistantScreen(weddingPlanId: 'plan-1', api: api)),
      );
      await tester.pumpAndSettle();
      // b11: the header and the three drawn questions.
      expect(find.text('اسأل اعّرست'), findsOneWidget);
      expect(find.text('ايش نسيت؟'), findsOneWidget);
      expect(find.text('وين أوفر؟'), findsOneWidget);
      expect(find.text('اكتب رسالة تفاوض'), findsOneWidget);
      expect(find.text('باقي لك اليوم سؤالين'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('assistant-kind-CHEAPER')));
      await tester.pumpAndSettle();
      // w36 asks in a journey sheet, with the server's daily limit.
      expect(find.text('المساعد الذكي'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('journey-sheet-handle')),
        findsOneWidget,
      );
      expect(find.text('3 أسئلة في اليوم'), findsOneWidget);
      expect(find.text('ما نرسل أسماء ضيوفك ولا أرقامهم'), findsOneWidget);
      expect(api.asked, isEmpty, reason: 'nothing is sent before consent');

      await tester.tap(find.byKey(const ValueKey('assistant-consent-agree')));
      await tester.pumpAndSettle();
      expect(api.asked, [PlanAssistantKind.cheaper]);
      // The question sits above its answer.
      expect(
        find.byKey(const ValueKey('assistant-question-bubble')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('assistant-answer')), findsOneWidget);
      expect(find.text('وزّع 40% للقاعة'), findsOneWidget);
      expect(find.text('من خطتك'), findsOneWidget);
      expect(find.text('اقتراح، والقرار لك.'), findsOneWidget);
      expect(find.byKey(const ValueKey('assistant-no-market')), findsOneWidget);
      expect(find.text('باقي لك اليوم سؤال واحد'), findsOneWidget);

      // Consent is remembered: the next question goes straight out.
      await tester.tap(find.byKey(const ValueKey('assistant-kind-FORGOTTEN')));
      await tester.pumpAndSettle();
      expect(find.text('المساعد الذكي'), findsNothing);
      expect(api.asked.last, PlanAssistantKind.forgotten);
    },
  );

  testWidgets('«مو الآن» sends nothing', (tester) async {
    final api = _FakeAssistantApi();
    await tester.pumpWidget(
      app(PlanAssistantScreen(weddingPlanId: 'plan-1', api: api)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assistant-kind-FORGOTTEN')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مو الآن'));
    await tester.pumpAndSettle();
    expect(api.asked, isEmpty);
    expect(find.byKey(const ValueKey('assistant-answer')), findsNothing);
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

  // RA-ST-04 (D95): «بلّغ عن الإجابة».
  Future<_FakeAssistantApi> askedOnce(
    WidgetTester tester, {
    _FakeAssistantApi? api,
    String? typed,
  }) async {
    SharedPreferences.setMockInitialValues({
      'aarast.assistant.consent.v1.device': true,
    });
    final fake = api ?? _FakeAssistantApi();
    await tester.pumpWidget(
      app(
        ScaffoldMessenger(
          child: Scaffold(
            body: PlanAssistantScreen(weddingPlanId: 'plan-1', api: fake),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (typed != null) {
      await tester.enterText(
        find.byKey(const ValueKey('assistant-question')),
        typed,
      );
      await tester.tap(find.byKey(const ValueKey('assistant-send')));
    } else {
      await tester.tap(find.byKey(const ValueKey('assistant-kind-FORGOTTEN')));
    }
    await tester.pumpAndSettle();
    return fake;
  }

  testWidgets('RA-ST-04: an answer is reported with what was asked and why', (
    tester,
  ) async {
    final api = await askedOnce(tester, typed: 'كم أخصص للتصوير؟');
    await tester.ensureVisible(find.byKey(const ValueKey('assistant-report')));
    await tester.tap(find.byKey(const ValueKey('assistant-report')));
    await tester.pumpAndSettle();
    expect(find.text('بلّغ عن الإجابة'), findsWidgets);
    expect(
      find.text('فريق اعّرست يقرأ الإجابة وسببك، ويحسّن المساعد.'),
      findsOneWidget,
    );

    // Nothing goes before a reason is picked.
    final send = find.byKey(const ValueKey('assistant-report-send'));
    await tester.tap(send);
    await tester.pump();
    expect(api.reports, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('assistant-report-reason-معلومة غلط أو تضر')),
    );
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(api.reports, [
      ['QUESTION', 'كم أخصص للتصوير؟', 'وزّع 40% للقاعة', 'معلومة غلط أو تضر'],
    ]);
    expect(find.text('وصل بلاغك، وفريق اعّرست بيراجعه.'), findsOneWidget);
    // Once per answer: the action becomes the fact.
    expect(find.byKey(const ValueKey('assistant-report')), findsNothing);
    expect(find.byKey(const ValueKey('assistant-reported')), findsOneWidget);
  });

  testWidgets('RA-ST-04: a ready-made request is reported without a question, '
      'and «شي ثاني» sends the reader\'s words', (tester) async {
    final api = await askedOnce(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('assistant-report')));
    await tester.tap(find.byKey(const ValueKey('assistant-report')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('assistant-report-reason-شي ثاني')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('assistant-report-words')).last,
      '  يقول أشياء ما تناسب  ',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('assistant-report-send')));
    await tester.pumpAndSettle();
    expect(api.reports, [
      ['FORGOTTEN', null, 'وزّع 40% للقاعة', 'يقول أشياء ما تناسب'],
    ]);
  });

  testWidgets('RA-ST-04: too many open reports say why, and the action stays', (
    tester,
  ) async {
    final api = await askedOnce(
      tester,
      api: _FakeAssistantApi(
        reportFailure: const ApiException(
          'Too many reports are waiting for review',
          statusCode: 429,
          serverCode: 'ASSISTANT_REPORT_LIMIT',
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('assistant-report')));
    await tester.tap(find.byKey(const ValueKey('assistant-report')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('assistant-report-reason-كلام مسيء')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('assistant-report-send')));
    await tester.pumpAndSettle();
    expect(api.reports, isEmpty);
    expect(
      find.text('عندك بلاغات كثير ما راجعها الفريق بعد. جرّب بعدين.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('assistant-report')), findsOneWidget);
  });

  testWidgets('RA-ST-04: the assistant\'s own refusal has nothing to report', (
    tester,
  ) async {
    await askedOnce(tester, api: _FakeAssistantApi(declined: true));
    expect(find.byKey(const ValueKey('assistant-answer')), findsOneWidget);
    expect(find.byKey(const ValueKey('assistant-report')), findsNothing);
  });

  test('RA-ST-04: the report carries the kind, the own question, the answer '
      'cut to the server\'s bound, and the reason', () async {
    final client = _RecordingClient();
    final long = 'ا' * (PlanAssistantApi.reportAnswerMax + 50);
    await PlanAssistantApi(client).reportAnswer(
      'plan-1',
      kind: PlanAssistantKind.cheaper,
      question: '  ',
      answer: long,
      reason: 'كلام مسيء',
    );
    expect(
      client.posts.single.$1,
      '/api/v1/wedding-plans/plan-1/assistant/reports',
    );
    final body = client.posts.single.$2;
    expect(body['kind'], 'CHEAPER');
    expect(body.containsKey('question'), isFalse);
    expect((body['answer'] as String).length, PlanAssistantApi.reportAnswerMax);
    expect(body['reason'], 'كلام مسيء');
  });

  testWidgets('a refusal from the server is shown in Arabic', (tester) async {
    SharedPreferences.setMockInitialValues({
      'aarast.assistant.consent.v1.device': true,
    });
    final api = _FakeAssistantApi(
      failure: const ApiException(
        'ما قدرنا نجاوب على هذا السؤال.',
        statusCode: 422,
        serverCode: 'ASSISTANT_DECLINED',
      ),
    );
    await tester.pumpWidget(
      app(PlanAssistantScreen(weddingPlanId: 'plan-1', api: api)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assistant-kind-FORGOTTEN')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assistant-error')), findsOneWidget);
    expect(find.text('ما قدرنا نجاوب على هذا السؤال.'), findsOneWidget);
  });

  // w37: the two reasons the design keeps for no answer.
  testWidgets('today\'s limit and a missing connection say why (w37)', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'aarast.assistant.consent.v1.device': true,
    });
    await tester.pumpWidget(
      app(
        PlanAssistantScreen(
          weddingPlanId: 'plan-1',
          api: _FakeAssistantApi(
            failure: const ApiException(
              'انتهت أسئلة اليوم.',
              statusCode: 429,
              serverCode: 'ASSISTANT_DAILY_LIMIT',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assistant-kind-CHEAPER')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assistant-limit')), findsOneWidget);
    expect(find.text('خلصت أسئلة اليوم'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('assistant-question-bubble')),
      findsNothing,
    );

    await tester.pumpWidget(
      app(
        PlanAssistantScreen(
          weddingPlanId: 'plan-2',
          api: _FakeAssistantApi(
            failure: const ApiException(
              'تعذر الاتصال.',
              isNetworkFailure: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assistant-kind-CHEAPER')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assistant-offline')), findsOneWidget);
    expect(find.text('المساعد يحتاج نت'), findsOneWidget);
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
    expect(
      find.byKey(const ValueKey('assistant-kind-FORGOTTEN')),
      findsNothing,
    );

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
      app(
        PlanAssistantEntry(weddingPlanId: 'plan-1', api: _FakeAssistantApi()),
      ),
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

  // The door sits above the countdown: drawn only when the server answered,
  // it pushed the whole home down on every open, and never showed offline.
  testWidgets('the home door is drawn from the phone\'s last answer, before '
      'the server\'s and when it does not come', (tester) async {
    final waiting = _KnownAssistantApi(serverAnswers: false);
    await tester.pumpWidget(
      app(PlanAssistantEntry(weddingPlanId: 'plan-1', api: waiting)),
    );
    // No server answer yet: one turn of the phone's own read is enough.
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('assistant-entry')), findsOneWidget);

    // The server is out of reach: the door stays as last known.
    waiting.fail();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assistant-entry')), findsOneWidget);
  });

  testWidgets('the server\'s answer is the last word on the home door', (
    tester,
  ) async {
    // The phone remembers an open door; the server now says it is closed.
    final api = _KnownAssistantApi(serverAnswers: true, allowedNow: false);
    await tester.pumpWidget(
      app(PlanAssistantEntry(weddingPlanId: 'plan-1', api: api)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('assistant-entry')), findsNothing);
  });
}

/// An assistant whose last answer the phone kept (open to the reader), and
/// a server that answers, waits or fails.
class _KnownAssistantApi extends PlanAssistantApi {
  _KnownAssistantApi({required this.serverAnswers, this.allowedNow = true})
    : super(ApiClient(tokenProvider: () async => null));

  final bool serverAnswers;
  final bool allowedNow;
  final _server = Completer<PlanAssistantStatus>();

  void fail() => _server.completeError(
    ApiException('الخادم ما يرد', isNetworkFailure: true),
  );

  PlanAssistantStatus _status({required bool allowed}) => PlanAssistantStatus(
    enabled: true,
    allowed: allowed,
    dailyLimit: 3,
    remainingToday: 2,
  );

  @override
  Future<PlanAssistantStatus?> knownStatus(String weddingPlanId) async =>
      _status(allowed: true);

  @override
  Future<PlanAssistantStatus> status(String weddingPlanId) => serverAnswers
      ? Future.value(_status(allowed: allowedNow))
      : _server.future;
}

class _FakeAssistantApi extends PlanAssistantApi {
  _FakeAssistantApi({
    this.enabled = true,
    this.allowed = true,
    this.failure,
    this.declined = false,
    this.reportFailure,
  }) : super(ApiClient(tokenProvider: () async => null));

  final bool enabled;
  final bool allowed;
  final ApiException? failure;
  final bool declined;
  final ApiException? reportFailure;
  final List<PlanAssistantKind> asked = [];
  final List<String?> questions = [];

  /// RA-ST-04: kind, question, answer and reason of each report sent.
  final List<List<String?>> reports = [];

  @override
  Future<void> reportAnswer(
    String weddingPlanId, {
    required PlanAssistantKind kind,
    required String? question,
    required String answer,
    required String reason,
  }) async {
    if (reportFailure != null) throw reportFailure!;
    reports.add([kind.apiValue, question, answer, reason]);
  }

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
      declined: declined,
      marketDataAvailable: false,
      remainingToday: _remaining,
    );
  }
}

/// RA-ST-04: the path and body the report sends to the server.
class _RecordingClient extends ApiClient {
  _RecordingClient() : super(tokenProvider: () async => null);

  final List<(String, Map<String, dynamic>)> posts = [];

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    posts.add((path, data));
    return {'reported': true};
  }
}
