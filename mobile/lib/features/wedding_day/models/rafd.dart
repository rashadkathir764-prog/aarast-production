import 'package:flutter/foundation.dart';

/// The largest gift b06 takes (the server keeps 12 digits).
const rafdMaxAmount = 9999999999;

/// «20,000»: the amount with its thousands grouped, as b06 and e09 draw it.
String groupedAmount(num value) {
  final digits = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}$buffer';
}

/// D66: one gift a guest brought, as the rafd book keeps it (b06, e09).
/// Tracking only: nothing is paid or moved. [pending] is one written on this
/// phone that has not reached the server yet.
@immutable
class RafdEntry {
  const RafdEntry({
    required this.clientId,
    required this.giverName,
    required this.amount,
    required this.recordedAt,
    this.id,
    this.thankedAt,
    this.pending = false,
  });

  factory RafdEntry.fromJson(Map<String, dynamic> json) => RafdEntry(
    id: json['id']?.toString(),
    clientId: json['clientId']?.toString() ?? '',
    giverName: json['giverName']?.toString() ?? '',
    amount: num.tryParse(json['amount']?.toString() ?? '') ?? 0,
    recordedAt:
        DateTime.tryParse(json['recordedAt']?.toString() ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    thankedAt: DateTime.tryParse(
      json['thankedAt']?.toString() ?? '',
    )?.toLocal(),
  );

  /// The phone's own JSON for the outbox (and the batch it sends).
  factory RafdEntry.fromOutbox(Map<String, dynamic> json) => RafdEntry(
    clientId: json['clientId'].toString(),
    giverName: json['giverName'].toString(),
    amount: num.tryParse(json['amount'].toString()) ?? 0,
    recordedAt:
        DateTime.tryParse(json['recordedAt'].toString())?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    pending: true,
  );

  /// The server's id; null while it waits on the phone.
  final String? id;
  final String clientId;
  final String giverName;
  final num amount;
  final DateTime recordedAt;
  final DateTime? thankedAt;
  final bool pending;

  bool get thanked => thankedAt != null;

  /// The first word of the name, as the thanks message greets him
  /// («يا عبدالله»).
  String get firstName => giverName.trim().split(RegExp(r'\s+')).first;

  Map<String, dynamic> toOutboxJson() => {
    'clientId': clientId,
    'giverName': giverName,
    'amount': amount.toString(),
    'recordedAt': recordedAt.toUtc().toIso8601String(),
  };
}

/// e09: the owner's book: what arrived, from how many, how many were thanked.
@immutable
class RafdBook {
  const RafdBook({
    required this.weddingPlanId,
    required this.currency,
    required this.items,
  });

  factory RafdBook.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    return RafdBook(
      weddingPlanId: json['weddingPlanId']?.toString() ?? '',
      currency: json['currency']?.toString() ?? 'YER',
      items: [
        if (items is List)
          for (final item in items)
            if (item is Map) RafdEntry.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  final String weddingPlanId;
  final String currency;

  /// Newest first.
  final List<RafdEntry> items;

  /// The same book with the entries still waiting on this phone on top.
  RafdBook withPending(List<RafdEntry> pending) => RafdBook(
    weddingPlanId: weddingPlanId,
    currency: currency,
    items: [
      ...pending.reversed,
      for (final item in items)
        if (!pending.any((waiting) => waiting.clientId == item.clientId)) item,
    ],
  );

  num get total => items.fold<num>(0, (sum, item) => sum + item.amount);

  /// How many gave: one entry is one giver (a group writes one name).
  int get givers => items.length;

  int get thanked => items.where((item) => item.thanked).length;

  /// e10's queue: recorded on the server and not thanked yet, oldest first.
  List<RafdEntry> get toThank => [
    for (final item in items.reversed)
      if (!item.thanked && !item.pending && item.id != null) item,
  ];
}
