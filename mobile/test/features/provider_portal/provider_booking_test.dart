import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_booking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'provider_requests_test.dart'
    show RequestsApi, bookingJson, offerJson, pumpHarness, quoteJson;

// Provider slice 3 (D39): p21 confirm, p22 booked, p25 cancelled. Day level
// (one booking per day, D-2): no team; no deposit, remaining or delivery
// (decision D-1 open); no «نسخة».

class BookingApi extends RequestsApi {
  BookingApi({super.quotes, super.bookings, this.tracked = const []});

  /// The booking maps the quotes and the list share, changed in place.
  final List<Map<String, dynamic>> tracked;

  final decisions = <String>[];
  ApiException? failWith;

  @override
  Future<MarketplaceBooking> decideBooking({
    required String bookingId,
    required String action,
    String? note,
  }) async {
    final failure = failWith;
    if (failure != null) throw failure;
    decisions.add(
      [bookingId, action, if (note != null && note.isNotEmpty) note].join(':'),
    );
    final status = switch (action) {
      'confirm' => 'CONFIRMED',
      'decline' => 'DECLINED',
      _ => 'CANCELLED',
    };
    for (final booking in tracked) {
      if (booking['id'] == bookingId) {
        booking['status'] = status;
        booking['lifecycleStatus'] = status;
        if (note != null && note.isNotEmpty) booking['note'] = note;
        if (action == 'cancel') booking['cancelledBy'] = 'PROVIDER';
      }
    }
    return MarketplaceBooking.fromJson({
      'id': bookingId,
      'quoteRequestId': 'quote-1',
      'eventDate': '2027-01-21',
      'status': status,
    });
  }
}

BookingApi _asked() {
  final booking = bookingJson();
  return BookingApi(
    quotes: [
      quoteJson(
        status: 'ACCEPTED',
        offers: [offerJson(status: 'ACCEPTED')],
        booking: booking,
      ),
    ],
    bookings: [booking],
    tracked: [booking],
  );
}

BookingApi _booked({String lifecycle = 'CONFIRMED'}) {
  final booking = bookingJson(status: 'CONFIRMED')
    ..['lifecycleStatus'] = lifecycle
    ..['quoteOfferId'] = 'offer-1';
  return BookingApi(
    quotes: [
      quoteJson(
        status: 'ACCEPTED',
        offers: [offerJson(status: 'ACCEPTED')],
        booking: booking,
      ),
    ],
    bookings: [if (lifecycle == 'CONFIRMED') booking],
    tracked: [booking],
  );
}

BookingApi _ended({
  String status = 'CANCELLED',
  String? by = 'CUSTOMER',
  String? note = 'العرس تأجل للصيف',
}) {
  final booking = bookingJson(status: status)
    ..['cancelledBy'] = by
    ..['note'] = note
    ..['cancelledAt'] = DateTime.now()
        .subtract(const Duration(days: 1))
        .toUtc()
        .toIso8601String()
    ..['declinedAt'] = DateTime.now().toUtc().toIso8601String();
  return BookingApi(
    quotes: [
      quoteJson(
        status: 'ACCEPTED',
        offers: [offerJson(status: 'ACCEPTED')],
        booking: booking,
      ),
    ],
  );
}

Future<void> _open(WidgetTester tester, BookingApi api) =>
    pumpHarness(tester, api, initial: '/provider/requests/quote-1');

void main() {
  group('p21 confirm', () {
    testWidgets('a booking request opens the sheet, day level, no team', (
      tester,
    ) async {
      final api = _asked();
      await _open(tester, api);
      expect(find.text('محمد قبل عرضك'), findsWidgets);
      // RA-MO-303 (2026-11-13): the customer may be a bride.
      expect(find.text('طلب حجز صور وفيديو · الخميس 21 يناير'), findsOne);
      expect(find.textContaining('نتأكد إن اليوم فاضي'), findsOne);
      expect(find.textContaining('فريق'), findsNothing);

      await tester.tap(
        find.byKey(const Key('provider-booking-confirm-booking-1')),
      );
      await tester.pumpAndSettle();
      expect(api.decisions, ['booking-1:confirm']);
      // The request is now the booking (p22).
      expect(find.byType(ProviderBookingScreen), findsOne);
      expect(find.text('حجز محمد الحمدي'), findsOne);
    });

    testWidgets('«ما أقدر، اعتذر» sends the apology with its reason', (
      tester,
    ) async {
      final api = _asked();
      await _open(tester, api);
      await tester.tap(
        find.byKey(const Key('provider-booking-decline-booking-1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('تعتذر من محمد؟'), findsOne);
      await tester.enterText(
        find.byKey(const Key('provider-booking-reason')),
        'عندنا ارتباط',
      );
      await tester.tap(find.byKey(const Key('provider-booking-decline-send')));
      await tester.pumpAndSettle();
      expect(api.decisions, ['booking-1:decline:عندنا ارتباط']);
      // The request is now the ended booking (p25).
      expect(find.byType(ProviderBookingEndedScreen), findsOne);
      expect(find.text('اعتذرت عن الحجز'), findsOne);
    });

    testWidgets('a day taken in the same moment is said, nothing changes', (
      tester,
    ) async {
      final api = _asked()
        ..failWith = const ApiException(
          'x',
          statusCode: 409,
          serverCode: 'BOOKING_DATE_UNAVAILABLE',
        );
      await _open(tester, api);
      await tester.tap(
        find.byKey(const Key('provider-booking-confirm-booking-1')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('يوم الخميس ما عاد فاضي عندك، فما تأكد الحجز.'),
        findsOne,
      );
      expect(find.byType(ProviderBookingScreen), findsNothing);
    });

    testWidgets('without the network, confirming says it needs it (p43)', (
      tester,
    ) async {
      final api = _asked()
        ..failWith = const ApiException('x', isNetworkFailure: true);
      await _open(tester, api);
      await tester.tap(
        find.byKey(const Key('provider-booking-confirm-booking-1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('تأكيد الحجز يحتاج نت'), findsOne);
    });
  });

  group('p22 booked', () {
    testWidgets('facts, agreement and reminders; no version, team or money '
        'rows', (tester) async {
      await _open(tester, _booked());
      await tester.pumpAndSettle();
      expect(find.text('حجز محمد الحمدي'), findsOne);
      expect(find.text('محجوز'), findsOne);
      expect(find.text('الخميس 21 يناير · 13 شعبان'), findsOne);
      expect(find.text('124 تقريبًا'), findsOne);
      expect(find.text('الاتفاق'), findsOne);
      expect(find.textContaining('صور وفيديو · 550,000'), findsOne);
      expect(find.text('تصوير ليلة كاملة'), findsOne);
      expect(find.text('نذكّرك أنت ومحمد قبل بأسبوع وبيوم'), findsOne);
      for (final dropped in [
        'نسخة',
        'الفريق',
        'الدفعة المقدمة',
        'الباقي',
        'التسليم',
        'المناسبة',
        'الفترة',
        'عربون',
        'مقدم',
      ]) {
        expect(find.textContaining(dropped), findsNothing, reason: dropped);
      }
    });

    testWidgets('cancelling asks first and sends the reason', (tester) async {
      final api = _booked();
      await _open(tester, api);
      await tester.tap(
        find.byKey(const Key('provider-booking-cancel-booking-1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('تلغي حجز محمد؟'), findsOne);
      await tester.enterText(
        find.byKey(const Key('provider-booking-reason')),
        'تعطلت المعدات',
      );
      await tester.tap(find.byKey(const Key('provider-booking-cancel-send')));
      await tester.pumpAndSettle();
      expect(api.decisions, ['booking-1:cancel:تعطلت المعدات']);
      expect(find.text('لغيت الحجز'), findsOne);
    });

    testWidgets('the chat opens from the booking', (tester) async {
      await _open(tester, _booked());
      await tester.tap(find.byKey(const Key('provider-booking-chat')));
      await tester.pumpAndSettle();
      expect(find.text('محادثة الطلب quote-1'), findsOne);
    });

    testWidgets('a day that passed reads «تم», with no cancel or reminder', (
      tester,
    ) async {
      await _open(tester, _booked(lifecycle: 'COMPLETED'));
      expect(find.text('تم'), findsOne);
      expect(
        find.byKey(const Key('provider-booking-cancel-booking-1')),
        findsNothing,
      );
      expect(find.textContaining('نذكّرك'), findsNothing);
    });
  });

  group('p25 cancelled', () {
    testWidgets('who, when, why, and the day free again; no deposit', (
      tester,
    ) async {
      await _open(tester, _ended());
      expect(find.text('حجز محمد الحمدي'), findsOne);
      expect(find.text('ملغي'), findsOne);
      expect(find.text('محمد لغى الحجز'), findsOne);
      expect(
        find.textContaining('صور وفيديو · الخميس 21 يناير · أمس'),
        findsOne,
      );
      expect(find.text('السبب: «العرس تأجل للصيف»'), findsOne);
      expect(find.text('رجع اليوم فاضي في تقويمك'), findsOne);
      expect(find.textContaining('الدفعة'), findsNothing);
      expect(find.textContaining('فريق'), findsNothing);
      expect(find.text('سجّل'), findsNothing);
    });

    testWidgets('no reason is shown when none was given', (tester) async {
      await _open(tester, _ended(note: null));
      expect(find.textContaining('السبب'), findsNothing);
    });

    testWidgets('a day he closed since is not called free', (tester) async {
      final api = _ended()..blocked.add(DateTime(2027, 1, 21));
      await _open(tester, api);
      expect(find.text('رجع اليوم فاضي في تقويمك'), findsNothing);
    });
  });
}
