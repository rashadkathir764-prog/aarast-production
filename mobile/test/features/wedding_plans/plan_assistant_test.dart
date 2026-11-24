import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_plans/data/plan_assistant_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/plan_assistant.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/plan_assistant_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/utils/assistant_consent.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/plan_assistant_entry.dart';
import 'package:dio/dio.dart';
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
    expect(status.consentedAt, isNull);
    expect(PlanAssistantStatus.fromJson({'enabled': true}).available, isFalse);
    // RA-BE-161: the server's stored consent, with its date.
    expect(
      PlanAssistantStatus.fromJson({
        'enabled': true,
        'allowed': true,
        'consentedAt': '2026-11-24T09:00:00.000Z',
      }).consentedAt,
      DateTime.utc(2026, 11, 24, 9),
    );
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

  testWidgets('consent comes before the first question, then the answer shows', (
    tester,
  ) async {
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
    expect(find.byKey(const ValueKey('journey-sheet-handle')), findsOneWidget);
    expect(find.text('3 أسئلة في اليوم'), findsOneWidget);
    // RA-BE-160: the sheet says what the server sends and keeps.
    expect(
      find.text(
        'سؤالك وملخص خطتك يروحون لخدمة Claude من Anthropic تفهمه: المدينة والموعد، والميزانية وبنودها، والعروض، وعدد الضيوف والمهام',
      ),
      findsOneWidget,
    );
    // Item 8 (RA-BE-160): item names go as written, so «no name» was
    // not true.
    expect(
      find.text(
        'ما نرسل أسماء الأشخاص، وأسماء البنود تروح كما كتبتها. ولا رقم جوال، ولا اسم الخطة ولا مهامها',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('أي اسم'), findsNothing);
    expect(
      find.text(
        'أرقام مال الخطة ما تروح مع سؤال الشريك إلا بموافقة صاحب الخطة',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'ما نحفظ أسئلتك ولا الإجابات، بس تاريخ موافقتك، وما يتغيّر شيء في خطتك',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'عند Anthropic تنحفظ حسب سياسة خدمتها، وما تدرّب عليها نماذجها',
      ),
      findsOneWidget,
    );
    expect(api.asked, isEmpty, reason: 'nothing is sent before consent');

    await tester.tap(find.byKey(const ValueKey('assistant-consent-agree')));
    await tester.pumpAndSettle();
    // RA-BE-161: the consent is recorded on the server before the question.
    expect(api.consentsRecorded, ['plan-1']);
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
    expect(api.consentsRecorded, ['plan-1'], reason: 'recorded once');
  });

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
    expect(api.consentsRecorded, isEmpty);
    expect(find.byKey(const ValueKey('assistant-answer')), findsNothing);
  });

  // RA-BE-161: the server keeps the consent; one it never received opens
  // nothing, and the question waits.
  testWidgets('RA-BE-161: a consent the server did not receive sends no '
      'question and says why', (tester) async {
    final api = _FakeAssistantApi(
      consentFailure: const ApiException(
        'تعذر الاتصال. الموافقة تنحفظ عند اعّرست، فتحتاج النت.',
        isNetworkFailure: true,
      ),
    );
    await tester.pumpWidget(
      app(
        ScaffoldMessenger(
          child: Scaffold(
            body: PlanAssistantScreen(weddingPlanId: 'plan-1', api: api),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assistant-kind-CHEAPER')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assistant-consent-agree')));
    await tester.pumpAndSettle();
    expect(api.asked, isEmpty);
    expect(
      find.text('تعذر الاتصال. الموافقة تنحفظ عند اعّرست، فتحتاج النت.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('assistant-answer')), findsNothing);
  });

  test('RA-BE-161: the question carries no consent flag; consent is '
      'recorded and taken back on the server', () async {
    final client = _RecordingClient();
    final api = PlanAssistantApi(client);
    await api.ask('plan-1', kind: PlanAssistantKind.plan);
    final (path, body) = client.posts.single;
    expect(path, '/api/v1/wedding-plans/plan-1/assistant/questions');
    expect(body, {'kind': 'PLAN'});

    expect(await api.recordConsent('plan-1'), DateTime.utc(2026, 11, 24, 9));
    // Item 9: the consent is the account's; taking it back needs no plan.
    await api.withdrawConsent();
    expect(client.writes, [
      ('PUT', '/api/v1/wedding-plans/plan-1/assistant/consent'),
      ('DELETE', '/api/v1/me/assistant/consent'),
    ]);
  });

  test('RA-BE-161: w40 reads and changes the consent on the server', () async {
    final client = _RecordingClient();
    final read = await AssistantConsent.read(client, 'plan-1');
    expect(read?.dailyLimit, 3);
    expect(read?.consentedAt, isNull);
    expect(await AssistantConsent.set(client, 'plan-1', true), isTrue);
    expect(await AssistantConsent.set(client, null, false), isFalse);
    expect(client.writes, [
      ('PUT', '/api/v1/wedding-plans/plan-1/assistant/consent'),
      ('DELETE', '/api/v1/me/assistant/consent'),
    ]);
    // Item 9: read without any plan, from the account.
    final account = await AssistantConsent.readAccount(client);
    expect(account.consentedAt, DateTime.utc(2026, 11, 20));
    expect(account.dailyLimit, 3);
  });

  testWidgets('a free question needs its text and is sent with it', (
    tester,
  ) async {
    final api = _FakeAssistantApi(consented: true);
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
    final fake = api ?? _FakeAssistantApi(consented: true);
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
      [
        'answer-1',
        'QUESTION',
        'كم أخصص للتصوير؟',
        'وزّع 40% للقاعة',
        'معلومة غلط أو تضر',
      ],
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
      ['answer-1', 'FORGOTTEN', null, 'وزّع 40% للقاعة', 'يقول أشياء ما تناسب'],
    ]);
  });

  testWidgets('RA-ST-04: too many open reports say why, and the action stays', (
    tester,
  ) async {
    final api = await askedOnce(
      tester,
      api: _FakeAssistantApi(
        consented: true,
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
    await askedOnce(
      tester,
      api: _FakeAssistantApi(consented: true, declined: true),
    );
    expect(find.byKey(const ValueKey('assistant-answer')), findsOneWidget);
    expect(find.byKey(const ValueKey('assistant-report')), findsNothing);
  });

  test('RA-ST-04: the report carries the kind, the own question, the answer '
      'cut to the server\'s bound, and the reason', () async {
    final client = _RecordingClient();
    final long = 'ا' * (PlanAssistantApi.reportAnswerMax + 50);
    await PlanAssistantApi(client).reportAnswer(
      'plan-1',
      answerId: 'answer-9',
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
    // RA-BE-166: the server's id of the answer, which must sign its text.
    expect(body['answerId'], 'answer-9');
    expect(body['kind'], 'CHEAPER');
    expect(body.containsKey('question'), isFalse);
    expect((body['answer'] as String).length, PlanAssistantApi.reportAnswerMax);
    expect(body['reason'], 'كلام مسيء');
  });

  testWidgets('a refusal from the server is shown in Arabic', (tester) async {
    final api = _FakeAssistantApi(
      consented: true,
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

  // RA-BE-163: an answer cut at the model's limit was shown as complete.
  testWidgets('RA-BE-163: a cut answer says it is cut', (tester) async {
    await askedOnce(
      tester,
      api: _FakeAssistantApi(consented: true, truncated: true),
    );
    expect(find.text('وزّع 40% للقاعة'), findsOneWidget);
    expect(find.byKey(const ValueKey('assistant-truncated')), findsOneWidget);
    expect(find.text('الجواب طويل، اسأل بشكل أضيق'), findsOneWidget);
  });

  testWidgets('RA-BE-163: a whole answer has no such note', (tester) async {
    await askedOnce(tester);
    expect(find.byKey(const ValueKey('assistant-truncated')), findsNothing);
  });

  test('RA-BE-163, RA-BE-166: the answer reads its cut flag and its id', () {
    final answer = PlanAssistantAnswer.fromJson({
      'answer': 'خطة',
      'declined': false,
      'truncated': true,
      'answerId': 'id.sig',
      'marketDataAvailable': true,
      'remainingToday': 3,
    });
    expect(answer.truncated, isTrue);
    expect(answer.answerId, 'id.sig');
    expect(PlanAssistantAnswer.fromJson({'answer': 'خطة'}).truncated, isFalse);
  });

  // RA-BE-165: the account's own monthly cap, said in the app's words.
  test('RA-BE-165: the monthly cap of the account is said plainly', () {
    final requestOptions = RequestOptions(
      path: '/api/v1/wedding-plans/plan-1/assistant/questions',
    );
    final exception = ApiException.fromDio(
      DioException(
        requestOptions: requestOptions,
        response: Response<Object?>(
          requestOptions: requestOptions,
          statusCode: 429,
          data: {
            'statusCode': 429,
            'code': 'ASSISTANT_USER_MONTHLY_LIMIT',
            'message': 'This account reached its monthly assistant limit',
          },
        ),
        type: DioExceptionType.badResponse,
      ),
    );
    expect(exception.serverCode, 'ASSISTANT_USER_MONTHLY_LIMIT');
    expect(exception.message, 'خلصت أسئلتك هذا الشهر، ترجع أول الشهر');
  });

  testWidgets('RA-BE-165: the monthly cap shows its message on the screen', (
    tester,
  ) async {
    await askedOnce(
      tester,
      api: _FakeAssistantApi(
        consented: true,
        failure: const ApiException(
          'خلصت أسئلتك هذا الشهر، ترجع أول الشهر',
          statusCode: 429,
          serverCode: 'ASSISTANT_USER_MONTHLY_LIMIT',
        ),
      ),
    );
    expect(find.text('خلصت أسئلتك هذا الشهر، ترجع أول الشهر'), findsOneWidget);
    expect(find.byKey(const ValueKey('assistant-answer')), findsNothing);
  });

  // Item 7: the phone held a consent the server no longer has (taken back
  // from another phone); the refusal said «وافق أولًا» and the sheet never
  // came back.
  testWidgets('a consent the server no longer holds opens the sheet again, '
      'and the question goes once it is given', (tester) async {
    final api = _FakeAssistantApi(consented: true, consentGoneOnServer: true);
    await tester.pumpWidget(
      app(PlanAssistantScreen(weddingPlanId: 'plan-1', api: api)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assistant-kind-CHEAPER')));
    await tester.pumpAndSettle();
    expect(find.text('المساعد الذكي'), findsOneWidget, reason: 'the sheet');
    expect(find.byKey(const ValueKey('assistant-answer')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('assistant-consent-agree')));
    await tester.pumpAndSettle();
    expect(api.consentsRecorded, ['plan-1']);
    expect(api.asked, [PlanAssistantKind.cheaper]);
    expect(find.byKey(const ValueKey('assistant-answer')), findsOneWidget);
  });

  testWidgets('a consent the server no longer holds, declined again, sends '
      'nothing', (tester) async {
    final api = _FakeAssistantApi(consented: true, consentGoneOnServer: true);
    await tester.pumpWidget(
      app(PlanAssistantScreen(weddingPlanId: 'plan-1', api: api)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assistant-kind-CHEAPER')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مو الآن'));
    await tester.pumpAndSettle();
    expect(api.asked, isEmpty);
    expect(api.consentsRecorded, isEmpty);
    expect(find.byKey(const ValueKey('assistant-error')), findsNothing);
  });

  // w37: the two reasons the design keeps for no answer.
  testWidgets('today\'s limit and a missing connection say why (w37)', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        PlanAssistantScreen(
          weddingPlanId: 'plan-1',
          api: _FakeAssistantApi(
            consented: true,
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
            consented: true,
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
    this.truncated = false,
    this.reportFailure,
    bool consented = false,
    this.consentFailure,
    this.consentGoneOnServer = false,
  }) : _consentedAt = consented ? DateTime.utc(2026, 11, 20) : null,
       super(ApiClient(tokenProvider: () async => null));

  /// RA-BE-163: the answer stopped at the model's limit.
  final bool truncated;

  /// Item 7: the status said consented, but the server's record is gone
  /// (taken back elsewhere) until consent is recorded again.
  bool consentGoneOnServer;

  /// RA-BE-161: the server's stored consent.
  DateTime? _consentedAt;
  final ApiException? consentFailure;
  final List<String> consentsRecorded = [];

  @override
  Future<DateTime> recordConsent(String weddingPlanId) async {
    if (consentFailure != null) throw consentFailure!;
    consentsRecorded.add(weddingPlanId);
    consentGoneOnServer = false;
    return _consentedAt ??= DateTime.utc(2026, 11, 24, 9);
  }

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
    required String answerId,
    required PlanAssistantKind kind,
    required String? question,
    required String answer,
    required String reason,
  }) async {
    if (reportFailure != null) throw reportFailure!;
    reports.add([answerId, kind.apiValue, question, answer, reason]);
  }

  int _remaining = 2;

  @override
  Future<PlanAssistantStatus> status(String weddingPlanId) async =>
      PlanAssistantStatus(
        enabled: enabled,
        allowed: allowed,
        dailyLimit: 3,
        remainingToday: _remaining,
        consentedAt: _consentedAt,
      );

  @override
  Future<PlanAssistantAnswer> ask(
    String weddingPlanId, {
    required PlanAssistantKind kind,
    String? question,
  }) async {
    if (failure != null) throw failure!;
    if (consentGoneOnServer) {
      throw const ApiException(
        'وافق على إرسال بيانات خطتك للمساعد أولًا.',
        statusCode: 400,
        serverCode: 'ASSISTANT_CONSENT_REQUIRED',
      );
    }
    asked.add(kind);
    questions.add(question);
    _remaining -= 1;
    return PlanAssistantAnswer(
      answerId: 'answer-1',
      answer: 'وزّع 40% للقاعة',
      declined: declined,
      truncated: truncated,
      marketDataAvailable: false,
      remainingToday: _remaining,
    );
  }
}

/// RA-ST-04: the path and body the report sends to the server; RA-BE-161:
/// the question's body and the consent's writes.
class _RecordingClient extends ApiClient {
  _RecordingClient() : super(tokenProvider: () async => null);

  final List<(String, Map<String, dynamic>)> posts = [];
  final List<(String, String)> writes = [];

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    posts.add((path, data));
    return {'reported': true};
  }

  @override
  Future<Map<String, dynamic>> postJsonWithReceiveTimeout(
    String path,
    Map<String, dynamic> data, {
    required Duration receiveTimeout,
  }) async {
    posts.add((path, data));
    return {'kind': 'PLAN', 'answer': 'خطة', 'remainingToday': 2};
  }

  @override
  Future<Map<String, dynamic>> getJson(String path) async =>
      path == '/api/v1/me/assistant/consent'
      ? {'consentedAt': '2026-11-20T00:00:00.000Z', 'dailyLimit': 3}
      : {
          'enabled': true,
          'allowed': true,
          'dailyLimit': 3,
          'remainingToday': 3,
          'consentedAt': null,
        };

  @override
  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> data,
  ) async {
    writes.add(('PUT', path));
    return {'consentedAt': '2026-11-24T09:00:00.000Z'};
  }

  @override
  Future<Map<String, dynamic>> deleteJson(String path) async {
    writes.add(('DELETE', path));
    return {'consentedAt': null};
  }
}
