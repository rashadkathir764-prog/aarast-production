import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/widgets/plan_quote_requests_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('plan quote actions stay explicit and phone safe at 320px RTL', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 760);
    addTearDown(tester.view.reset);

    var acceptCalls = 0;
    var rejectCalls = 0;
    var createCostCalls = 0;
    var conversationCalls = 0;
    final quotes = [_receivedQuote(), _acceptedQuote()];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: PlanQuoteRequestsSection(
                    quotes: quotes,
                    canManageProviders: true,
                    canManageMoney: true,
                    isSubmitting: false,
                    onOpenConversation: (_) => conversationCalls += 1,
                    onAccept: (_) => acceptCalls += 1,
                    onReject: (_) => rejectCalls += 1,
                    onCreateCost: (_) => createCostCalls += 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.textContaining('لا ينشئ تكلفة أو دفعة تلقائيًا'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('quote-accept-quote-received')));
    await tester.tap(find.byKey(const Key('quote-reject-quote-received')));

    await tester.scrollUntilVisible(
      find.byKey(const Key('quote-create-cost-quote-accepted')),
      240,
    );
    expect(
      find.text('تم ربط المورد بالخطة. لم تُنشأ تكلفة أو دفعة تلقائيًا.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('quote-create-cost-quote-accepted')));
    await tester.scrollUntilVisible(
      find.byKey(const Key('quote-open-conversation-quote-accepted')),
      180,
    );
    await tester.tap(
      find.byKey(const Key('quote-open-conversation-quote-accepted')),
    );

    expect(acceptCalls, 1);
    expect(rejectCalls, 1);
    expect(createCostCalls, 1);
    expect(conversationCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cost CTA is hidden without money-management permission', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: PlanQuoteRequestsSection(
              quotes: [_acceptedQuote()],
              canManageProviders: true,
              canManageMoney: false,
              isSubmitting: false,
              onOpenConversation: (_) {},
              onAccept: (_) {},
              onReject: (_) {},
              onCreateCost: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('quote-create-cost-quote-accepted')),
      findsNothing,
    );
    expect(
      find.text('تحتاج صلاحية إدارة المال لإضافة هذه التكلفة.'),
      findsOneWidget,
    );
  });
}

QuoteRequest _receivedQuote() {
  return QuoteRequest.fromJson({
    'id': 'quote-received',
    'providerId': 'provider-1',
    'weddingPlanId': 'plan-1',
    'status': 'RESPONDED',
    'lifecycleStatus': 'RECEIVED',
    'provider': {
      'id': 'provider-1',
      'businessName': 'قاعة السعادة',
      'ratingAverage': 4.8,
      'ratingCount': 12,
    },
    'offers': [
      {
        'id': 'offer-pending',
        'status': 'PENDING',
        'amount': '250000',
        'currency': 'YER',
      },
    ],
  });
}

QuoteRequest _acceptedQuote() {
  return QuoteRequest.fromJson({
    'id': 'quote-accepted',
    'providerId': 'provider-1',
    'weddingPlanId': 'plan-1',
    'status': 'ACCEPTED',
    'lifecycleStatus': 'ACCEPTED',
    'provider': {
      'id': 'provider-1',
      'businessName': 'قاعة السعادة',
      'ratingAverage': 4.8,
      'ratingCount': 12,
    },
    'offers': [
      {
        'id': 'offer-accepted',
        'status': 'ACCEPTED',
        'title': 'خدمة القاعة',
        'amount': '250000',
        'currency': 'YER',
      },
    ],
    'costSuggestion': {
      'providerId': 'provider-1',
      'providerName': 'قاعة السعادة',
      'category': 'القاعات',
      'quotedAmount': '250000',
      'currency': 'YER',
      'suggestedAction': 'CREATE_COST',
      'availableActions': ['CREATE_COST'],
      'quoteOfferId': 'offer-accepted',
      'automaticCostCreated': false,
    },
  });
}
