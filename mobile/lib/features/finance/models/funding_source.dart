import '../../../core/experience_v3/aarast_journey_profile.dart';
import '../../../core/utils/plan_day.dart';

/// Where wedding money comes from, as `/api/v1/.../funding-sources` returns
/// it. Tracking only: the app records money; it never moves it.
class FundingSource {
  const FundingSource({
    required this.id,
    required this.weddingPlanId,
    required this.kind,
    required this.sourceName,
    required this.amount,
    required this.status,
    this.sourcePhone,
    this.receivedAt,
    this.expectedAt,
    this.note,
    this.repaidAmount,
    this.outstandingAmount,
    this.repayments = const [],
  });

  factory FundingSource.fromJson(Map<String, dynamic> json) {
    return FundingSource(
      id: json['id'].toString(),
      weddingPlanId: json['weddingPlanId'].toString(),
      kind: json['kind']?.toString() ?? FundingKind.other,
      sourceName: json['sourceName']?.toString() ?? '',
      sourcePhone: json['sourcePhone']?.toString(),
      amount: json['amount']?.toString() ?? '0',
      status: json['status']?.toString() ?? FundingStatus.received,
      receivedAt: DateTime.tryParse(json['receivedAt']?.toString() ?? ''),
      // A day, read as the server keeps it (Sana'a).
      expectedAt: planDayFromJson(json['expectedAt']),
      note: json['note']?.toString(),
      repaidAmount: json['repaidAmount']?.toString(),
      outstandingAmount: json['outstandingAmount']?.toString(),
      repayments: [
        for (final item in json['repayments'] as List? ?? const [])
          if (item is Map)
            LoanRepayment.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }

  final String id;
  final String weddingPlanId;
  final String kind;
  final String sourceName;
  final String? sourcePhone;
  final String amount;
  final String status;
  final DateTime? receivedAt;

  /// Promised money: the day it is expected (the mahr's rest, c05 «يوصلك
  /// يوم العقد 15 نوفمبر»).
  final DateTime? expectedAt;
  final String? note;

  /// Loans only.
  final String? repaidAmount;
  final String? outstandingAmount;
  final List<LoanRepayment> repayments;

  bool get isLoan => kind == FundingKind.loan;
  bool get isMahr => kind == FundingKind.mahr;
  bool get isPledged => status == FundingStatus.pledged;

  Map<String, dynamic> toJson() => {
    'id': id,
    'weddingPlanId': weddingPlanId,
    'kind': kind,
    'sourceName': sourceName,
    'sourcePhone': sourcePhone,
    'amount': amount,
    'status': status,
    'receivedAt': receivedAt?.toIso8601String(),
    'expectedAt': expectedAt?.toIso8601String(),
    'note': note,
    'repaidAmount': repaidAmount,
    'outstandingAmount': outstandingAmount,
    'repayments': [for (final item in repayments) item.toJson()],
  };
}

class LoanRepayment {
  const LoanRepayment({
    required this.id,
    required this.fundingSourceId,
    required this.amount,
    required this.status,
    this.dueDate,
    this.paidAt,
    this.note,
  });

  factory LoanRepayment.fromJson(Map<String, dynamic> json) {
    return LoanRepayment(
      id: json['id'].toString(),
      fundingSourceId: json['fundingSourceId'].toString(),
      amount: json['amount']?.toString() ?? '0',
      status: json['status']?.toString() ?? RepaymentStatus.planned,
      dueDate: DateTime.tryParse(json['dueDate']?.toString() ?? ''),
      paidAt: DateTime.tryParse(json['paidAt']?.toString() ?? ''),
      note: json['note']?.toString(),
    );
  }

  final String id;
  final String fundingSourceId;
  final String amount;
  final String status;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final String? note;

  bool get isPaid => status == RepaymentStatus.paid;
  bool get isCancelled => status == RepaymentStatus.cancelled;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fundingSourceId': fundingSourceId,
    'amount': amount,
    'status': status,
    'dueDate': dueDate?.toIso8601String(),
    'paidAt': paidAt?.toIso8601String(),
    'note': note,
  };
}

abstract final class FundingKind {
  static const savings = 'SAVINGS';
  static const familySupport = 'FAMILY_SUPPORT';
  static const gift = 'GIFT';
  static const loan = 'LOAN';
  static const other = 'OTHER';

  /// The bride's mahr from the groom (C1). Recorded by a06 (the server makes
  /// it), so it is not one of the kinds a new source is added as.
  static const mahr = 'MAHR';

  static const all = [savings, familySupport, gift, loan, other];

  /// The kind's name; the groom's rafd is the bride's gifts.
  static String label(String kind, JourneyProfile profile) => switch (kind) {
    savings => 'مدخرات',
    familySupport => 'دعم الأهل',
    gift => profile.plan('رفد ونقوط', 'هدايا ونقوط'),
    loan => 'سلفة (دين)',
    mahr => 'المهر',
    _ => 'مصدر آخر',
  };
}

abstract final class FundingStatus {
  static const pledged = 'PLEDGED';
  static const received = 'RECEIVED';
}

abstract final class RepaymentStatus {
  static const planned = 'PLANNED';
  static const paid = 'PAID';
  static const cancelled = 'CANCELLED';
}

/// Who is expected to pay a cost.
abstract final class CostPayerOption {
  static const values = <(String, String)>[
    ('GROOM', 'العريس'),
    ('BRIDE', 'العروسة'),
    ('FAMILY', 'الأهل'),
    ('SHARED', 'مشترك'),
    ('OTHER', 'آخر'),
  ];

  static String? label(String? code) {
    for (final (value, label) in values) {
      if (value == code) return label;
    }
    return null;
  }
}
