import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/widgets/quote_status_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quote response keeps structured context and real offer state', () {
    final quote = QuoteRequest.fromJson({
      'id': 'quote-1',
      'providerId': 'provider-1',
      'weddingPlanId': 'plan-1',
      'status': 'RESPONDED',
      'lifecycleStatus': 'RECEIVED',
      'contactName': 'رشاد',
      'contactNormalizedPhone': '+967777758200',
      'location': {'governorate': 'صنعاء', 'cityOrDistrict': 'أمانة العاصمة'},
      'offers': [
        {
          'id': 'offer-1',
          'status': 'PENDING',
          'amount': '250000',
          'currency': 'YER',
        },
      ],
    });

    expect(quote.lifecycleStatus, 'RECEIVED');
    expect(quote.location?.governorate, 'صنعاء');
    expect(quote.contactPhone, '+967777758200');
    expect(quote.pendingOffer?.amount, '250000');
    expect(quote.canAcceptOrReject, isTrue);
  });

  test('accepted quote exposes its automatically created canonical cost', () {
    final quote = QuoteRequest.fromJson({
      'id': 'quote-accepted',
      'providerId': 'provider-1',
      'weddingPlanId': 'plan-1',
      'status': 'ACCEPTED',
      'lifecycleStatus': 'ACCEPTED',
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
        'suggestedAction': 'VIEW_COST',
        'availableActions': ['VIEW_COST'],
        'quoteOfferId': 'offer-accepted',
        'costId': 'cost-from-offer',
        'automaticCostCreated': true,
      },
    });

    expect(quote.costSuggestion?.providerId, 'provider-1');
    expect(quote.costSuggestion?.quotedAmount, '250000');
    expect(quote.costSuggestion?.quoteOfferId, 'offer-accepted');
    expect(quote.costSuggestion?.automaticCostCreated, isTrue);
    expect(quote.costSuggestion?.costId, 'cost-from-offer');
    expect(quote.costSuggestion?.canViewCost, isTrue);
  });

  testWidgets('quote status chip uses truthful Arabic lifecycle labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              QuoteStatusChip(status: 'READY_TO_SEND'),
              QuoteStatusChip(status: 'PENDING_PROVIDER'),
              QuoteStatusChip(status: 'RECEIVED'),
              QuoteStatusChip(status: 'ACCEPTED'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('جاهز للإرسال'), findsOneWidget);
    expect(find.text('بانتظار رد المورد'), findsOneWidget);
    expect(find.text('وصل عرض سعر'), findsOneWidget);
    expect(find.text('مقبول'), findsOneWidget);
    expect(find.textContaining('حجز'), findsNothing);
  });
}
