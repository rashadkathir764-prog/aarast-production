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
    this.note,
    this.agreementDate,
    this.dueDate,
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
      note: stringOrNull(json['note']),
      agreementDate: dateTimeOrNull(json['agreementDate']),
      dueDate: dateTimeOrNull(json['dueDate']),
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
  final String? note;
  final DateTime? agreementDate;
  final DateTime? dueDate;
  final int? paymentsCount;
  final String? categoryName;
  final String? providerName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCancelled => status == 'CANCELLED';
  bool get isPaid => status == 'PAID';
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
    final dueDate = dateTimeOrNull(json['dueDate']) ?? DateTime.now();
    return PaymentSchedule(
      id: json['id']?.toString() ?? '',
      costId: json['costId']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      dueDate: dueDate,
      status: status,
      isOverdue:
          json['isOverdue'] == true ||
          (status == 'PENDING' && dueDate.isBefore(_today())),
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
  final String amount;
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

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
