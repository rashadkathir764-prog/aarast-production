import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../marketplace/marketplace_api.dart' show QuoteOfferLine;

/// An offer he sent with no network (p43), kept on this phone until it
/// reaches the server. Replaying it is safe: the server keeps one live
/// (not withdrawn) offer per request and answers a second create with 409
/// `QUOTE_OFFER_ALREADY_EXISTS` (F6), so an offer that did arrive is never
/// doubled.
class ProviderQueuedOffer {
  const ProviderQueuedOffer({
    required this.quoteRequestId,
    required this.message,
    required this.amount,
    required this.currency,
    required this.queuedAt,
    this.title,
    this.validUntil,
    this.lines,
    this.deliveryDays,
  });

  factory ProviderQueuedOffer.fromJson(Map<String, dynamic> json) =>
      ProviderQueuedOffer(
        quoteRequestId: json['quoteRequestId'].toString(),
        message: json['message'].toString(),
        amount: json['amount'].toString(),
        currency: json['currency'].toString(),
        title: json['title']?.toString(),
        validUntil: DateTime.tryParse(json['validUntil']?.toString() ?? ''),
        lines: json['lines'] is List
            ? [
                for (final line in json['lines'] as List)
                  if (line is Map)
                    QuoteOfferLine.fromJson(Map<String, dynamic>.from(line)),
              ]
            : null,
        deliveryDays: json['deliveryDays'] is num
            ? (json['deliveryDays'] as num).toInt()
            : null,
        queuedAt:
            DateTime.tryParse(json['queuedAt']?.toString() ?? '') ??
            DateTime.now(),
      );

  final String quoteRequestId;
  final String message;
  final String amount;
  final String currency;
  final String? title;
  final DateTime? validUntil;

  /// B-07: what the price covers, and the delivery days.
  final List<QuoteOfferLine>? lines;
  final int? deliveryDays;
  final DateTime queuedAt;

  Map<String, dynamic> toJson() => {
    'quoteRequestId': quoteRequestId,
    'message': message,
    'amount': amount,
    'currency': currency,
    'title': ?title,
    'validUntil': ?validUntil?.toUtc().toIso8601String(),
    if (lines != null) 'lines': [for (final line in lines!) line.toJson()],
    'deliveryDays': ?deliveryDays,
    'queuedAt': queuedAt.toUtc().toIso8601String(),
  };
}

/// Why an offer kept on the phone was not sent when the network came back.
enum ProviderOfferDropReason {
  /// The request is no longer in his list.
  requestGone,

  /// The request already holds a live offer of his.
  alreadyAnswered,

  /// Its seven days ended before the network came back (B-04).
  expired,

  /// The customer cancelled it.
  cancelled,

  /// He declined it (from another phone).
  declined,

  /// It no longer waits for his answer for another reason.
  closed,

  /// The server refused the offer; [ProviderDroppedOffer.serverMessage].
  refused,
}

/// An offer kept on the phone that will not be sent, told to him once in
/// clear words (never dropped silently).
class ProviderDroppedOffer {
  const ProviderDroppedOffer({
    required this.quoteRequestId,
    required this.reason,
    this.serverMessage,
  });

  final String quoteRequestId;
  final ProviderOfferDropReason reason;
  final String? serverMessage;
}

/// The offers waiting on this phone, per provider. Only offers wait: every
/// other write needs the server's answer at once (B-34).
class ProviderOfferQueue {
  const ProviderOfferQueue(this._preferences);

  final SharedPreferences _preferences;

  static String _key(String providerId) =>
      'aarast_provider_offer_queue:$providerId';

  List<ProviderQueuedOffer> read(String providerId) {
    final raw = _preferences.getString(_key(providerId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return [
        for (final item in list)
          if (item is Map)
            ProviderQueuedOffer.fromJson(Map<String, dynamic>.from(item)),
      ];
    } on FormatException {
      return const [];
    }
  }

  Future<void> write(String providerId, List<ProviderQueuedOffer> offers) {
    if (offers.isEmpty) return _preferences.remove(_key(providerId));
    return _preferences.setString(
      _key(providerId),
      jsonEncode([for (final offer in offers) offer.toJson()]),
    );
  }
}
