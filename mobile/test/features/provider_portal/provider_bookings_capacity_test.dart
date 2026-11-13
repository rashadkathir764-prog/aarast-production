import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/marketplace/models/provider_board.dart';
import 'package:aarast_mobile/features/provider_portal/providers/provider_dashboard_provider.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_ledger_screen.dart';
import 'package:aarast_mobile/features/provider_portal/widgets/provider_calendar_parts.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// B3 (D60): the provider's daily number (B-20), the customers' agreed, paid
// and left (B-18), a suspended provider's expired requests (B-42) and the
// one «محجوز» the home and the board read.

MarketplaceBooking _booking(String id, String status, {int day = 21}) =>
    MarketplaceBooking.fromJson({
      'id': id,
      'quoteRequestId': 'quote-$id',
      'providerId': 'provider-1',
      'eventDate': '2027-01-${day.toString().padLeft(2, '0')}',
      'status': status,
    });

void main() {
  group('B-20 the calendar day', () {
    final day = DateTime(2027, 1, 21);

    test('a day with room says «باقي N», a full one «محجوز»', () {
      final room = ProviderDay(
        day: day,
        confirmed: [_booking('a', 'CONFIRMED')],
        asked: const [],
        closed: false,
        capacity: 3,
      );
      expect(room.state, ProviderDayState.room);
      expect(room.left, 2);
      expect(providerDayWord(room.state, left: room.left), 'باقي 2');

      final full = ProviderDay(
        day: day,
        confirmed: [_booking('a', 'CONFIRMED'), _booking('b', 'CONFIRMED')],
        asked: const [],
        closed: false,
        capacity: 2,
      );
      expect(full.state, ProviderDayState.booked);
      expect(full.left, 0);
    });

    test('a number lowered under the day keeps it full, never negative', () {
      final lowered = ProviderDay(
        day: day,
        confirmed: [_booking('a', 'CONFIRMED'), _booking('b', 'CONFIRMED')],
        asked: const [],
        closed: false,
        capacity: 1,
      );
      expect(lowered.state, ProviderDayState.booked);
      expect(lowered.left, 0);
    });

    test('a request on a day with room still asks for his answer first', () {
      final waiting = ProviderDay(
        day: day,
        confirmed: [_booking('a', 'CONFIRMED')],
        asked: [_booking('b', 'REQUESTED')],
        closed: false,
        capacity: 2,
      );
      expect(waiting.state, ProviderDayState.waiting);
    });

    test('the profile carries the number, one by default', () {
      expect(
        ProviderDashboardProfile.fromJson({
          'id': 'p',
          'businessName': 'ضيافة',
          'status': 'ACTIVE',
          'dailyBookingCapacity': 2,
        }).dailyBookingCapacity,
        2,
      );
      expect(
        ProviderDashboardProfile.fromJson({
          'id': 'p',
          'businessName': 'ضيافة',
          'status': 'ACTIVE',
        }).dailyBookingCapacity,
        1,
      );
    });

    test('a full day reads in Arabic', () {
      expect(
        bookingErrorMessage('BOOKING_DAY_FULL'),
        // RA-MO-262 (2026-11-13): no fixed «اختر» to the bride.
        'المزوّد محجوز كامل في هذا اليوم.',
      );
    });
  });

  group('B-42 an expired request', () {
    test('may be asked again, and says why it ended', () {
      final expired = _booking('a', 'EXPIRED');
      expect(expired.canRequestAgain, isTrue);
      expect(expired.isOpen, isFalse);
      expect(bookingStatusLabel(expired), 'انتهى، المزوّد موقوف مؤقتًا');
      expect(
        bookingStatusLabel(expired, forProvider: true),
        'انتهى مع إيقاف حسابك',
      );
    });
  });

  group('B-18 the money on his booking', () {
    test('three totals, read from the server as sent', () {
      final booking = MarketplaceBooking.fromJson({
        'id': 'a',
        'quoteRequestId': 'q',
        'providerId': 'p',
        'eventDate': '2027-01-21',
        'status': 'CONFIRMED',
        'money': {
          'agreed': '550000.00',
          'paid': '100000.00',
          'left': '450000.00',
          'currency': 'YER',
          'lastPaidAt': '2026-12-12T10:00:00.000Z',
        },
      });
      expect(booking.money!.paid, '100000.00');
      expect(booking.money!.left, '450000.00');
      expect(booking.money!.lastPaidAt, isNotNull);
      expect(_booking('b', 'CONFIRMED').money, isNull);
    });

    testWidgets('p47 shows what reached him and what is left, per booking', (
      tester,
    ) async {
      final dashboard = ProviderDashboardProvider(_LedgerApi());
      await tester.pumpWidget(
        ChangeNotifierProvider<ProviderDashboardProvider>.value(
          value: dashboard,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: ProviderLedgerScreen(now: DateTime(2027, 1, 5)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('حساباتك'), findsOneWidget);
      expect(find.text('وصلك'), findsOneWidget);
      expect(find.text('باقي لك'), findsOneWidget);
      expect(find.textContaining('100,000'), findsOneWidget);
      expect(find.textContaining('450,000'), findsWidgets);
      expect(find.text('محمد الحمدي'), findsOneWidget);
      // Read only: nothing to remind, confirm or collect.
      expect(find.text('ذكّره'), findsNothing);
      expect(find.byKey(const Key('provider-ledger-note')), findsOneWidget);

      await tester.tap(find.byKey(const Key('provider-ledger-next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('provider-ledger-empty')), findsOneWidget);
    });
  });

  group('D60 one «محجوز»', () {
    final items = [
      (id: 'item-hall', name: 'القاعة', providerCategoryIds: ['halls']),
      (id: 'item-food', name: 'الضيافة', providerCategoryIds: ['catering']),
    ];
    final accepted = QuoteRequest.fromJson({
      'id': 'quote-food',
      'status': 'ACCEPTED',
      'lifecycleStatus': 'ACCEPTED',
      'weddingPlanId': 'plan-1',
      'costSuggestion': {'categoryId': 'catering'},
    });

    test('an accepted offer alone is «اطلب الحجز», never booked', () {
      final rows = buildProviderBoard(
        items: items,
        costs: const [],
        quotes: [accepted],
        costItemById: const {},
        booked: (items: <String>{}, quotes: <String>{}),
      );
      final food = rows.firstWhere((row) => row.key == 'item-food');
      expect(food.booked, isFalse);
      expect(food.detail, contains('اطلب الحجز'));
      expect(providerBoardStatus(rows), isNot(contains('محجوز')));
    });

    test('a row is booked exactly when the server counts it', () {
      final rows = buildProviderBoard(
        items: items,
        costs: const [],
        quotes: [accepted],
        costItemById: const {},
        booked: (items: {'item-food', 'item-hall'}, quotes: <String>{}),
      );
      expect(rows.where((row) => row.booked).length, 2);
      expect(providerBoardStatus(rows), contains('محجوز 2'));
    });

    test('the home reads the same count from the summary', () {
      final booked = DashboardBookedServices.fromJson({
        'count': 4,
        'budgetCategoryIds': ['a', 'b', 'c'],
        'quoteRequestIds': ['q'],
      });
      expect(booked.count, 4);
      expect(booked.itemIds, ['a', 'b', 'c']);
      expect(DashboardBookedServices.fromJson(const {}).count, 0);
    });
  });
}

class _LedgerApi extends ProviderDashboardApi {
  _LedgerApi() : super(ApiClient(tokenProvider: () async => null));

  @override
  Future<ProviderLedger> getLedger(DateTime month) async =>
      ProviderLedger.fromJson(
        month.month == 1
            ? {
                'totals': [
                  {
                    'currency': 'YER',
                    'agreed': '550000.00',
                    'paid': '100000.00',
                    'left': '450000.00',
                    'bookings': 1,
                  },
                ],
                'bookings': [
                  {
                    'bookingId': 'booking-1',
                    'quoteRequestId': 'quote-1',
                    'customerName': 'محمد الحمدي',
                    'eventDate': '2027-01-21',
                    'money': {
                      'agreed': '550000.00',
                      'paid': '100000.00',
                      'left': '450000.00',
                      'currency': 'YER',
                      'lastPaidAt': null,
                    },
                  },
                ],
              }
            : {'totals': [], 'bookings': []},
      );
}
