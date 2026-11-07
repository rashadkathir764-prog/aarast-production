import '../../../core/utils/app_clock.dart';

class WeddingCost {
  const WeddingCost({
    required this.id,
    required this.weddingPlanId,
    required this.budgetCategoryId,
    required this.title,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.status,
    this.providerId,
    this.quoteOfferId,
    this.partyName,
    this.partyPhone,
    this.payer,
    this.payerName,
    this.note,
    this.isPrivate = false,
    this.agreementDate,
    this.paymentsCount,
    this.categoryName,
    this.providerName,
    this.createdAt,
    this.updatedAt,
  });

  factory WeddingCost.fromJson(Map<String, dynamic> json) {
    final total = moneyValue(json['totalAmount']);
    final paid = moneyValue(json['paidAmount']);
    return WeddingCost(
      id: json['id']?.toString() ?? '',
      weddingPlanId: json['weddingPlanId']?.toString() ?? '',
      budgetCategoryId: json['budgetCategoryId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      totalAmount: json['totalAmount']?.toString() ?? '0',
      paidAmount: json['paidAmount']?.toString() ?? '0',
      remainingAmount:
          json['remainingAmount']?.toString() ?? (total - paid).toString(),
      status: json['status']?.toString() ?? 'OPEN',
      providerId: stringOrNull(json['providerId']),
      quoteOfferId: stringOrNull(json['quoteOfferId']),
      partyName: stringOrNull(json['partyName']),
      partyPhone: stringOrNull(json['partyPhone']),
      payer: stringOrNull(json['payer']),
      payerName: stringOrNull(json['payerName']),
      note: stringOrNull(json['note']),
      isPrivate: json['isPrivate'] == true,
      agreementDate: dateTimeOrNull(json['agreementDate']),
      paymentsCount: intOrNull(json['paymentsCount']),
      categoryName:
          stringOrNull(json['categoryName']) ??
          _nestedString(json['budgetCategory'], 'name'),
      providerName:
          stringOrNull(json['providerName']) ??
          _nestedString(json['provider'], 'businessName'),
      createdAt: dateTimeOrNull(json['createdAt']),
      updatedAt: dateTimeOrNull(json['updatedAt']),
    );
  }

  final String id;
  final String weddingPlanId;
  final String budgetCategoryId;
  final String title;
  final String totalAmount;
  final String paidAmount;
  final String remainingAmount;
  final String status;
  final String? providerId;
  final String? quoteOfferId;
  final String? partyName;
  final String? partyPhone;

  /// Who is expected to pay: GROOM, BRIDE, FAMILY, SHARED or OTHER.
  final String? payer;
  final String? payerName;
  final String? note;

  /// V1 checklist 4.10: only the account that recorded it sees it.
  final bool isPrivate;
  final DateTime? agreementDate;
  final int? paymentsCount;
  final String? categoryName;
  final String? providerName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCancelled => status == 'CANCELLED';
  bool get isPaid => status == 'PAID';
  bool get hasActivePayments => moneyValue(paidAmount) > 0;
  bool get hasPaymentHistory =>
      (paymentsCount ?? 0) > 0 || moneyValue(paidAmount) > 0;
  bool get canDelete => !hasPaymentHistory;
  String? get partyLabel => providerName ?? partyName;
}

class CostPayment {
  const CostPayment({
    required this.id,
    required this.costId,
    required this.amount,
    required this.paidAt,
    this.entryType = 'PAYMENT',
    this.paymentScheduleId,
    this.reversalOfId,
    this.reversedById,
    this.reversible = false,
    this.method,
    this.note,
    this.weddingPlanId,
    this.costTitle,
    this.budgetCategoryId,
    this.categoryName,
    this.providerId,
    this.providerName,
    this.createdAt,
  });

  factory CostPayment.fromJson(Map<String, dynamic> json) {
    return CostPayment(
      id: json['id']?.toString() ?? '',
      costId: json['costId']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      paidAt: dateTimeOrNull(json['paidAt']) ?? DateTime.now(),
      entryType: json['entryType']?.toString() ?? 'PAYMENT',
      paymentScheduleId: stringOrNull(json['paymentScheduleId']),
      reversalOfId: stringOrNull(json['reversalOfId']),
      reversedById: stringOrNull(json['reversedById']),
      reversible: json['reversible'] == true,
      method: stringOrNull(json['method']),
      note: stringOrNull(json['note']),
      weddingPlanId: stringOrNull(json['weddingPlanId']),
      costTitle:
          stringOrNull(json['costTitle']) ??
          _nestedString(json['cost'], 'title'),
      budgetCategoryId:
          stringOrNull(json['budgetCategoryId']) ??
          _nestedString(json['cost'], 'budgetCategoryId'),
      categoryName:
          stringOrNull(json['categoryName']) ??
          _nestedString(json['budgetCategory'], 'name'),
      providerId:
          stringOrNull(json['providerId']) ??
          _nestedString(json['cost'], 'providerId'),
      providerName:
          stringOrNull(json['providerName']) ??
          _nestedString(json['provider'], 'businessName'),
      createdAt: dateTimeOrNull(json['createdAt']),
    );
  }

  final String id;
  final String costId;
  final String amount;
  final DateTime paidAt;
  final String entryType;
  final String? paymentScheduleId;
  final String? reversalOfId;
  final String? reversedById;
  final bool reversible;
  final String? method;
  final String? note;
  final String? weddingPlanId;
  final String? costTitle;
  final String? budgetCategoryId;
  final String? categoryName;
  final String? providerId;
  final String? providerName;
  final DateTime? createdAt;

  bool get isReversal => entryType == 'REVERSAL';
  bool get isReversed => reversedById != null;
  String get signedAmount =>
      isReversal && !amount.startsWith('-') ? '-$amount' : amount;
}

class PaymentSchedule {
  const PaymentSchedule({
    required this.id,
    required this.costId,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.amountDue,
    this.isOverdue = false,
    this.paidAt,
    this.note,
    this.weddingPlanId,
    this.costTitle,
    this.budgetCategoryId,
    this.categoryName,
    this.providerId,
    this.providerName,
    this.createdAt,
    this.updatedAt,
  });

  factory PaymentSchedule.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? 'PENDING';
    final dueDate = dateTimeOrNull(json['dueDate']) ?? appNow();
    return PaymentSchedule(
      id: json['id']?.toString() ?? '',
      costId:
          json['costId']?.toString() ?? json['weddingCostId']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      amountDue: stringOrNull(json['amountDue']),
      dueDate: dueDate,
      status: status,
      isOverdue:
          json['isOverdue'] == true ||
          _isPaymentScheduleOverdueAt(status, dueDate, appNow()),
      paidAt: dateTimeOrNull(json['paidAt']),
      note: stringOrNull(json['note']),
      weddingPlanId: stringOrNull(json['weddingPlanId']),
      costTitle:
          stringOrNull(json['costTitle']) ??
          _nestedString(json['cost'], 'title'),
      budgetCategoryId:
          stringOrNull(json['budgetCategoryId']) ??
          _nestedString(json['cost'], 'budgetCategoryId'),
      categoryName:
          stringOrNull(json['categoryName']) ??
          _nestedString(json['budgetCategory'], 'name'),
      providerId:
          stringOrNull(json['providerId']) ??
          _nestedString(json['cost'], 'providerId'),
      providerName:
          stringOrNull(json['providerName']) ??
          _nestedString(json['provider'], 'businessName'),
      createdAt: dateTimeOrNull(json['createdAt']),
      updatedAt: dateTimeOrNull(json['updatedAt']),
    );
  }

  final String id;
  final String costId;

  /// The amount as the person wrote it (what the reminder's form edits).
  final String amount;

  /// RA-BE-53: what the server says this pending reminder asks for now, at
  /// most what its agreement still owes; null from an older server.
  final String? amountDue;
  final DateTime dueDate;
  final String status;
  final bool isOverdue;
  final DateTime? paidAt;
  final String? note;
  final String? weddingPlanId;
  final String? costTitle;
  final String? budgetCategoryId;
  final String? categoryName;
  final String? providerId;
  final String? providerName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPending => status == 'PENDING';
  bool get isPaid => status == 'PAID';
  bool get isCancelled => status == 'CANCELLED';

  /// RA-BE-53: what paying this reminder records and what the money screens
  /// show for it: the server's figure, else its own amount.
  String get dueAmount => amountDue ?? amount;

  /// This reminder asking for at most what its agreement still owes, as the
  /// server reads it (`scheduleAmountDue`), for the copy kept on the phone.
  PaymentSchedule withRemaining(String remainingAmount) {
    final remaining = moneyValue(remainingAmount);
    final own = moneyValue(amount);
    final due = !isPending || remaining <= 0
        ? '0'
        : (own < remaining ? amount : remainingAmount);
    return PaymentSchedule(
      id: id,
      costId: costId,
      amount: amount,
      amountDue: due,
      dueDate: dueDate,
      status: status,
      isOverdue: isOverdue,
      paidAt: paidAt,
      note: note,
      weddingPlanId: weddingPlanId,
      costTitle: costTitle,
      budgetCategoryId: budgetCategoryId,
      categoryName: categoryName,
      providerId: providerId,
      providerName: providerName,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Mirrors the backend rule: a pending reminder is overdue only when its
  /// due instant is before the start of the current calendar day in Riyadh.
  bool isOverdueAt(DateTime now) {
    return _isPaymentScheduleOverdueAt(status, dueDate, now);
  }
}

String? stringOrNull(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? dateTimeOrNull(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

num moneyValue(Object? value) {
  return num.tryParse(value?.toString().replaceAll(',', '').trim() ?? '') ?? 0;
}

int? intOrNull(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

String? _nestedString(Object? value, String key) {
  if (value is Map) return stringOrNull(value[key]);
  return null;
}

bool _isPaymentScheduleOverdueAt(
  String status,
  DateTime dueDate,
  DateTime now,
) {
  if (status != 'PENDING') return false;
  final riyadhNow = now.toUtc().add(const Duration(hours: 3));
  final startOfTodayInRiyadh = DateTime.utc(
    riyadhNow.year,
    riyadhNow.month,
    riyadhNow.day,
  ).subtract(const Duration(hours: 3));
  return dueDate.toUtc().isBefore(startOfTodayInRiyadh);
}
