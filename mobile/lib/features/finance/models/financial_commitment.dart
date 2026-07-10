class FinancialCommitment {
  const FinancialCommitment({
    required this.id,
    required this.weddingPlanId,
    required this.budgetCategoryId,
    required this.title,
    required this.totalAmount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.sourceType,
    required this.status,
    this.providerId,
    this.planProviderLinkId,
    this.quoteRequestId,
    this.quoteOfferId,
    this.partyName,
    this.partyPhone,
    this.dueDate,
    this.agreementDate,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory FinancialCommitment.fromJson(Map<String, dynamic> json) {
    final total = _moneyValue(json['totalAmount']);
    final paid = _moneyValue(json['paidAmount']);
    return FinancialCommitment(
      id: json['id']?.toString() ?? '',
      weddingPlanId: json['weddingPlanId']?.toString() ?? '',
      budgetCategoryId: json['budgetCategoryId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      totalAmount: json['totalAmount']?.toString() ?? '0',
      paidAmount: json['paidAmount']?.toString() ?? '0',
      remainingAmount:
          json['remainingAmount']?.toString() ?? (total - paid).toString(),
      sourceType: json['sourceType']?.toString() ?? 'MANUAL_COMMITMENT',
      status: json['status']?.toString() ?? 'OPEN',
      providerId: _stringOrNull(json['providerId']),
      planProviderLinkId: _stringOrNull(json['planProviderLinkId']),
      quoteRequestId: _stringOrNull(json['quoteRequestId']),
      quoteOfferId: _stringOrNull(json['quoteOfferId']),
      partyName: _stringOrNull(json['partyName']),
      partyPhone: _stringOrNull(json['partyPhone']),
      dueDate: _dateTimeOrNull(json['dueDate']),
      agreementDate: _dateTimeOrNull(json['agreementDate']),
      note: _stringOrNull(json['note']),
      createdAt: _dateTimeOrNull(json['createdAt']),
      updatedAt: _dateTimeOrNull(json['updatedAt']),
    );
  }

  final String id;
  final String weddingPlanId;
  final String budgetCategoryId;
  final String title;
  final String totalAmount;
  final String paidAmount;
  final String remainingAmount;
  final String sourceType;
  final String status;
  final String? providerId;
  final String? planProviderLinkId;
  final String? quoteRequestId;
  final String? quoteOfferId;
  final String? partyName;
  final String? partyPhone;
  final DateTime? dueDate;
  final DateTime? agreementDate;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isCancelled => status == 'CANCELLED';
  bool get isProviderLinked =>
      sourceType == 'PROVIDER_SERVICE' || providerId != null;
  bool get isManualDebt => sourceType == 'MANUAL_DEBT';
}

class FinancialPaymentRecord {
  const FinancialPaymentRecord({
    required this.id,
    required this.weddingPlanId,
    required this.financialCommitmentId,
    required this.budgetCategoryId,
    required this.title,
    required this.amount,
    required this.paidAt,
    this.entryType = 'PAYMENT',
    this.financialInstallmentId,
    this.reversalOfId,
    this.reversedById,
    this.reversible = false,
    this.method,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory FinancialPaymentRecord.fromJson(Map<String, dynamic> json) {
    return FinancialPaymentRecord(
      id: json['id']?.toString() ?? '',
      weddingPlanId: json['weddingPlanId']?.toString() ?? '',
      financialCommitmentId: json['financialCommitmentId']?.toString() ?? '',
      budgetCategoryId: json['budgetCategoryId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      paidAt: _dateTimeOrNull(json['paidAt']) ?? DateTime.now(),
      entryType: json['entryType']?.toString() ?? 'PAYMENT',
      financialInstallmentId: _stringOrNull(json['financialInstallmentId']),
      reversalOfId: _stringOrNull(json['reversalOfId']),
      reversedById: _stringOrNull(json['reversedById']),
      reversible: json['reversible'] == true,
      method: _stringOrNull(json['method']),
      note: _stringOrNull(json['note']),
      createdAt: _dateTimeOrNull(json['createdAt']),
      updatedAt: _dateTimeOrNull(json['updatedAt']),
    );
  }

  final String id;
  final String weddingPlanId;
  final String financialCommitmentId;
  final String budgetCategoryId;
  final String title;
  final String amount;
  final DateTime paidAt;
  final String entryType;
  final String? financialInstallmentId;
  final String? reversalOfId;
  final String? reversedById;
  final bool reversible;
  final String? method;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isReversal => entryType == 'REVERSAL';
  bool get isReversed => reversedById != null;
  String get signedAmount => isReversal && !amount.startsWith('-')
      ? '-$amount'
      : amount;
}

class FinancialInstallment {
  const FinancialInstallment({
    required this.id,
    required this.weddingPlanId,
    required this.financialCommitmentId,
    required this.budgetCategoryId,
    required this.amount,
    required this.status,
    this.dueDate,
    this.paidAt,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory FinancialInstallment.fromJson(Map<String, dynamic> json) {
    return FinancialInstallment(
      id: json['id']?.toString() ?? '',
      weddingPlanId: json['weddingPlanId']?.toString() ?? '',
      financialCommitmentId: json['financialCommitmentId']?.toString() ?? '',
      budgetCategoryId: json['budgetCategoryId']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0',
      status: json['status']?.toString() ?? 'PENDING',
      dueDate: _dateTimeOrNull(json['dueDate']),
      paidAt: _dateTimeOrNull(json['paidAt']),
      note: _stringOrNull(json['note']),
      createdAt: _dateTimeOrNull(json['createdAt']),
      updatedAt: _dateTimeOrNull(json['updatedAt']),
    );
  }

  final String id;
  final String weddingPlanId;
  final String financialCommitmentId;
  final String budgetCategoryId;
  final String amount;
  final String status;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPaid => status == 'PAID';
}

String? _stringOrNull(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

num _moneyValue(Object? value) {
  return num.tryParse(value?.toString().replaceAll(',', '').trim() ?? '') ?? 0;
}
