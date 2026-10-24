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
  });

  factory MarketplaceBooking.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? 'REQUESTED';
    return MarketplaceBooking(
      id: json['id'].toString(),
      quoteRequestId: json['quoteRequestId']?.toString() ?? '',
      providerId: json['providerId']?.toString() ?? '',
      eventDate:
          DateTime.tryParse(json['eventDate']?.toString() ?? '') ??
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
    );
  }

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

  bool get isRequested => status == 'REQUESTED';
  bool get isConfirmed => status == 'CONFIRMED';
  bool get isOpen => isRequested || isConfirmed;

  /// The customer may ask (again) when there is no open booking.
  bool get canRequestAgain => status == 'DECLINED' || status == 'CANCELLED';

  /// `YYYY-MM-DD`, the format the API takes.
  static String dayParam(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

DateTime? _moment(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

/// The booking's state in words, from the customer's or the provider's side.
String bookingStatusLabel(MarketplaceBooking booking, {bool forProvider = false}) {
  return switch (booking.lifecycleStatus) {
    'REQUESTED' => forProvider ? 'طلب حجز بانتظار ردّك' : 'بانتظار تأكيد المزوّد',
    'CONFIRMED' => 'محجوز',
    'COMPLETED' => 'تمّ',
    'DECLINED' => forProvider ? 'اعتذرت عنه' : 'اعتذر المزوّد',
    'CANCELLED' => booking.cancelledBy == 'PROVIDER'
        ? (forProvider ? 'ألغيته' : 'ألغاه المزوّد')
        : (forProvider ? 'ألغاه العميل' : 'ألغيته'),
    _ => booking.lifecycleStatus,
  };
}

/// Arabic text for the booking API's error codes.
String? bookingErrorMessage(String? code) {
  return switch (code) {
    'BOOKING_DATE_UNAVAILABLE' => 'المزوّد غير متاح في هذا اليوم. اختر يومًا آخر.',
    'BOOKING_DATE_HAS_BOOKING' => 'لديك حجز مؤكد في هذا اليوم.',
    'BOOKING_DATE_IN_PAST' => 'هذا اليوم مضى. اختر يومًا قادمًا.',
    'BOOKING_INVALID_DATE' => 'اختر يوم العرس أولًا.',
    'BOOKING_ALREADY_OPEN' => 'لديك طلب حجز قائم مع هذا المزوّد.',
    'BOOKING_QUOTE_NOT_ACCEPTED' => 'اقبل عرض السعر أولًا ثم اطلب الحجز.',
    'BOOKING_NOT_ALLOWED' => 'تغيّر الحجز. حدّث الصفحة ثم حاول مرة أخرى.',
    _ => null,
  };
}
