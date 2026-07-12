String? validatePositiveMoney(String? value) {
  final amount = _money(value);
  if (amount == null || amount <= 0) return 'أدخل مبلغاً أكبر من صفر';
  return null;
}

String? validateInitialPayment(String? value, {required String? totalRaw}) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) return null;
  final paid = _money(raw);
  if (paid == null || paid < 0) return 'أدخل مبلغاً صحيحاً';
  final total = _money(totalRaw);
  if (total != null && paid > total) {
    return 'المدفوع الآن لا يمكن أن يتجاوز التكلفة';
  }
  return null;
}

String? validatePaymentAmount(String? value, {required num remaining}) {
  final amountError = validatePositiveMoney(value);
  if (amountError != null) return amountError;
  final amount = _money(value)!;
  if (amount > remaining) return 'الدفعة لا يمكن أن تتجاوز المبلغ المتبقي';
  return null;
}

bool hasUsableBudgetSetupAmount(
  Iterable<String?> values, {
  required bool hasGeneralBudget,
}) {
  if (hasGeneralBudget) return true;
  return values.any((value) => (_money(value) ?? 0) > 0);
}

num? _money(String? value) {
  final raw = value?.replaceAll(',', '').trim() ?? '';
  if (raw.isEmpty) return null;
  return num.tryParse(raw);
}
