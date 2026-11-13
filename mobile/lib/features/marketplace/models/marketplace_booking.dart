import '../../../core/utils/plan_day.dart';

/// The wedding day reserved with a provider after their offer was accepted
/// (V1 checklist 4.6). Tracking only: no deposit or payment.
class MarketplaceBooking {
  const MarketplaceBooking({
    required this.id,
    required this.quoteRequestId,
    required this.providerId,
    required this.eventDate,
    required this.status,
    required this.lifecycleStatus,
    this.cancelledBy,
    this.note,
    this.quoteOfferId,
    this.createdAt,
    this.confirmedAt,
    this.declinedAt,
    this.cancelledAt,
    this.customerName,
    this.guestCount,
    this.weddingPlanId,
    this.money,
    this.completedAt,
    this.notHappenedAt,
    this.notHappenedReason,
    this.deliveryDueAt,
    this.deliveredAt,
    this.deliveryLink,
    this.deliveryNote,
    this.deliveryConfirmedAt,
    this.change,
  });

  factory MarketplaceBooking.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? 'REQUESTED';
    return MarketplaceBooking(
      id: json['id'].toString(),
      quoteRequestId: json['quoteRequestId']?.toString() ?? '',
      providerId: json['providerId']?.toString() ?? '',
      // A day, read as the day in Sana'a (D11).
      eventDate:
          planDayFromJson(json['eventDate']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: status,
      lifecycleStatus: json['lifecycleStatus']?.toString() ?? status,
      cancelledBy: json['cancelledBy']?.toString(),
      note: _text(json['note']),
      quoteOfferId: _text(json['quoteOfferId']),
      createdAt: _moment(json['createdAt']),
      confirmedAt: _moment(json['confirmedAt']),
      declinedAt: _moment(json['declinedAt']),
      cancelledAt: _moment(json['cancelledAt']),
      customerName: _text(json['customerName']),
      guestCount: json['guestCount'] is num
          ? (json['guestCount'] as num).toInt()
          : null,
      weddingPlanId: json['weddingPlanId']?.toString(),
      money: json['money'] is Map
          ? BookingMoney.fromJson(
              Map<String, dynamic>.from(json['money'] as Map),
            )
          : null,
      completedAt: _moment(json['completedAt']),
      notHappenedAt: _moment(json['notHappenedAt']),
      notHappenedReason: _text(json['notHappenedReason']),
      deliveryDueAt: _moment(json['deliveryDueAt']),
      deliveredAt: _moment(json['deliveredAt']),
      deliveryLink: _text(json['deliveryLink']),
      deliveryNote: _text(json['deliveryNote']),
      deliveryConfirmedAt: _moment(json['deliveryConfirmedAt']),
      change: json['change'] is Map
          ? BookingChange.fromJson(
              Map<String, dynamic>.from(json['change'] as Map),
            )
          : null,
    );
  }

  /// B-22: the provider said «تم», or «ما صار» and why
  /// (`CUSTOMER_NO_SHOW`, `WE_DID_NOT_ATTEND`, `FORCE_MAJEURE`,
  /// `OFFICIAL_DECISION`). Two days after the day it completes by itself.
  final DateTime? completedAt;
  final DateTime? notHappenedAt;
  final String? notHappenedReason;

  /// B-23: the delivery promised by the offer, the delivery, its confirmation.
  final DateTime? deliveryDueAt;
  final DateTime? deliveredAt;
  final String? deliveryLink;
  final String? deliveryNote;
  final DateTime? deliveryConfirmedAt;

  /// B-24: the last change of day the customer asked for.
  final BookingChange? change;

  /// B-22: from the day to two days after, before any word; past that the
  /// server completes the booking by itself.
  bool canRecordOutcome(DateTime today) {
    if (!isConfirmed || completedAt != null || notHappenedAt != null) {
      return false;
    }
    final day = DateTime(eventDate.year, eventDate.month, eventDate.day);
    final now = DateTime(today.year, today.month, today.day);
    return !now.isBefore(day) && now.difference(day).inDays <= 2;
  }

  /// B-23: a completed booking not delivered yet.
  bool get canDeliver =>
      isConfirmed && completedAt != null && deliveredAt == null;

  /// B-23: delivered, not confirmed yet by the customer.
  bool get canConfirmDelivery =>
      deliveredAt != null && deliveryConfirmedAt == null;

  /// B-24: a confirmed booking before its day, with no change waiting.
  bool canAskChange(DateTime today) =>
      isConfirmed &&
      !DateTime(
        eventDate.year,
        eventDate.month,
        eventDate.day,
      ).isBefore(DateTime(today.year, today.month, today.day)) &&
      change?.isPending != true;

  final String id;
  final String quoteRequestId;
  final String providerId;

  /// A calendar day (no time).
  final DateTime eventDate;

  /// `REQUESTED`, `CONFIRMED`, `DECLINED` or `CANCELLED`.
  final String status;

  /// [status], or `COMPLETED` for a confirmed booking whose day has passed.
  final String lifecycleStatus;

  /// `CUSTOMER` or `PROVIDER` for a cancelled booking.
  final String? cancelledBy;

  /// The customer's note when asking; the provider's or the canceller's
  /// own note once declined or cancelled (their reason).
  final String? note;

  /// The accepted offer the booking follows; its cost carries the same id.
  final String? quoteOfferId;
  final DateTime? createdAt;
  final DateTime? confirmedAt;
  final DateTime? declinedAt;
  final DateTime? cancelledAt;

  /// Provider list only.
  final String? customerName;
  final int? guestCount;
  final String? weddingPlanId;

  /// Provider side only (B-18): what the customer agreed, paid and still
  /// owes on this booking's item; null without an agreement.
  final BookingMoney? money;

  /// RA-MO-263: a request whose day passed with no answer. The server can
  /// no longer confirm, decline or cancel it, so it reads it as over
  /// (`lifecycleStatus` EXPIRED) and takes a new request.
  bool get isUnansweredPast =>
      status == 'REQUESTED' && lifecycleStatus == 'EXPIRED';

  bool get isRequested => status == 'REQUESTED' && !isUnansweredPast;
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isOpen => isRequested || isConfirmed;

  /// The customer may ask (again) when there is no open booking; a request
  /// that expired with the provider's suspension (B-42), or whose day
  /// passed unanswered, too.
  bool get canRequestAgain =>
      status == 'DECLINED' ||
      status == 'CANCELLED' ||
      status == 'EXPIRED' ||
      isUnansweredPast;

  /// The server's own rule for a review (F10, RA-BE-46): the booking's day
  /// passed, or the provider reported that he himself did not come. Any
  /// other «ما صار» closes the review.
  bool get canBeReviewed =>
      lifecycleStatus == 'COMPLETED' ||
      (lifecycleStatus == 'NOT_HAPPENED' &&
          notHappenedReason == 'WE_DID_NOT_ATTEND');

  /// `YYYY-MM-DD`, the format the API takes.
  static String dayParam(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

/// B-24: a change of day the customer asked for, and the provider's answer.
class BookingChange {
  const BookingChange({
    required this.id,
    required this.fromDate,
    required this.toDate,
    required this.status,
    this.note,
    this.declineReason,
  });

  factory BookingChange.fromJson(Map<String, dynamic> json) => BookingChange(
    id: json['id'].toString(),
    fromDate:
        planDayFromJson(json['fromDate']) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    toDate:
        planDayFromJson(json['toDate']) ??
        DateTime.fromMillisecondsSinceEpoch(0),
    status: json['status']?.toString() ?? 'PENDING',
    note: _text(json['note']),
    declineReason: _text(json['declineReason']),
  );

  final String id;
  final DateTime fromDate;
  final DateTime toDate;

  /// `PENDING`, `ACCEPTED`, `DECLINED` or `CANCELLED`.
  final String status;
  final String? note;
  final String? declineReason;

  bool get isPending => status == 'PENDING';
  bool get isDeclined => status == 'DECLINED';
}

/// B-18: the three totals the provider reads, read only. The customer
/// records every payment; the provider never sees one, nor who paid.
class BookingMoney {
  const BookingMoney({
    required this.agreed,
    required this.paid,
    required this.left,
    required this.currency,
    this.lastPaidAt,
  });

  factory BookingMoney.fromJson(Map<String, dynamic> json) => BookingMoney(
    agreed: json['agreed']?.toString() ?? '0',
    paid: json['paid']?.toString() ?? '0',
    left: json['left']?.toString() ?? '0',
    currency: json['currency']?.toString() ?? 'YER',
    lastPaidAt: _moment(json['lastPaidAt']),
  );

  /// Decimal strings as the server sends them («550000.00»).
  final String agreed;
  final String paid;
  final String left;
  final String currency;
  final DateTime? lastPaidAt;
}

/// p47 «حساباتك» (B-18): one month of his confirmed bookings and what their
/// customers recorded, each currency on its own (never added together).
class ProviderLedger {
  const ProviderLedger({required this.totals, required this.bookings});

  factory ProviderLedger.fromJson(Map<String, dynamic> json) => ProviderLedger(
    totals: [
      for (final row
          in (json['totals'] is List ? json['totals'] as List : const []))
        if (row is Map)
          ProviderLedgerTotal(
            currency: row['currency']?.toString() ?? 'YER',
            agreed: row['agreed']?.toString() ?? '0',
            paid: row['paid']?.toString() ?? '0',
            left: row['left']?.toString() ?? '0',
            bookings: row['bookings'] is num
                ? (row['bookings'] as num).toInt()
                : 0,
          ),
    ],
    bookings: [
      for (final row
          in (json['bookings'] is List ? json['bookings'] as List : const []))
        if (row is Map)
          ProviderLedgerBooking(
            bookingId: row['bookingId']?.toString() ?? '',
            quoteRequestId: row['quoteRequestId']?.toString() ?? '',
            customerName: _text(row['customerName']),
            eventDate:
                planDayFromJson(row['eventDate']) ??
                DateTime.fromMillisecondsSinceEpoch(0),
            money: row['money'] is Map
                ? BookingMoney.fromJson(
                    Map<String, dynamic>.from(row['money'] as Map),
                  )
                : null,
          ),
    ],
  );

  final List<ProviderLedgerTotal> totals;
  final List<ProviderLedgerBooking> bookings;
}

class ProviderLedgerTotal {
  const ProviderLedgerTotal({
    required this.currency,
    required this.agreed,
    required this.paid,
    required this.left,
    required this.bookings,
  });

  final String currency;
  final String agreed;
  final String paid;
  final String left;
  final int bookings;
}

class ProviderLedgerBooking {
  const ProviderLedgerBooking({
    required this.bookingId,
    required this.quoteRequestId,
    required this.eventDate,
    this.customerName,
    this.money,
  });

  final String bookingId;
  final String quoteRequestId;
  final String? customerName;
  final DateTime eventDate;

  /// Null when the customer keeps no agreement for this booking.
  final BookingMoney? money;
}

DateTime? _moment(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

/// The booking's state in words, from the customer's or the provider's side.
String bookingStatusLabel(
  MarketplaceBooking booking, {
  bool forProvider = false,
}) {
  return switch (booking.lifecycleStatus) {
    'REQUESTED' =>
      forProvider ? 'طلب حجز بانتظار ردّك' : 'بانتظار تأكيد المزوّد',
    'CONFIRMED' => 'محجوز',
    'COMPLETED' => 'تمّ',
    'DECLINED' => forProvider ? 'اعتذرت عنه' : 'اعتذر المزوّد',
    'CANCELLED' =>
      booking.cancelledBy == 'PROVIDER'
          ? (forProvider ? 'ألغيته' : 'ألغاه المزوّد')
          : (forProvider ? 'ألغاه العميل' : 'ألغيته'),
    // RA-MO-263: its day passed with no answer.
    'EXPIRED' when booking.isUnansweredPast =>
      forProvider ? 'مرّ يومه وما رديت عليه' : 'مرّ يومه وما ردّ المزوّد',
    // B-42: his account was stopped while the request waited.
    'EXPIRED' =>
      forProvider ? 'انتهى مع إيقاف حسابك' : 'انتهى، المزوّد موقوف مؤقتًا',
    _ => booking.lifecycleStatus,
  };
}

/// Arabic text for the booking API's error codes.
String? bookingErrorMessage(String? code) {
  return switch (code) {
    // RA-MO-262: no fixed «اختر» to a reader who may be the bride; what
    // the day is, and the picker stays open for another.
    'BOOKING_DATE_UNAVAILABLE' => 'المزوّد مو متاح في هذا اليوم.',
    'BOOKING_DAY_FULL' => 'المزوّد محجوز كامل في هذا اليوم.',
    'BOOKING_DATE_HAS_BOOKING' => 'عندك حجز مؤكد في هذا اليوم.',
    'BOOKING_DATE_IN_PAST' => 'هذا اليوم مضى، الحجز ليوم جاي.',
    'BOOKING_INVALID_DATE' => 'يوم العرس لازم يتحدد أول.',
    'BOOKING_ALREADY_OPEN' => 'عندك طلب حجز مفتوح مع هذا المزوّد.',
    'BOOKING_QUOTE_NOT_ACCEPTED' => 'الحجز يُطلب بعد قبول عرض السعر.',
    'BOOKING_NOT_ALLOWED' => 'تغيّر الحجز، وحاله الجديد يطلع لما تتحدث الصفحة.',
    _ => null,
  };
}
