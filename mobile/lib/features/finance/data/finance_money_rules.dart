import '../../../core/network/api_client.dart';

abstract final class FinanceMoneyRules {
  static num value(Object? value) {
    return num.tryParse(value?.toString().replaceAll(',', '').trim() ?? '') ??
        0;
  }

  static num assertPositive(Object? value, String label) {
    final parsed = num.tryParse(
      value?.toString().replaceAll(',', '').trim() ?? '',
    );
    if (parsed == null || parsed <= 0) {
      throw ApiException('$label يجب أن يكون أكبر من صفر.');
    }
    return parsed;
  }

  static num assertOptionalNonNegative(Object? value, String label) {
    final raw = value?.toString().replaceAll(',', '').trim() ?? '';
    if (raw.isEmpty) return 0;
    final parsed = num.tryParse(raw);
    if (parsed == null || parsed < 0) {
      throw ApiException('$label غير صحيح.');
    }
    return parsed;
  }

  static void assertCostAmounts({
    required String totalAmount,
    String? initialPaymentAmount,
  }) {
    final total = assertPositive(totalAmount, 'إجمالي التكلفة');
    final paid = assertOptionalNonNegative(
      initialPaymentAmount,
      'الدفعة الأولى',
    );
    if (paid > total) {
      throw const ApiException('الدفعة الأولى لا يمكن أن تتجاوز التكلفة.');
    }
  }

  static void assertPaymentWithinRemaining({
    required Map<String, dynamic> cost,
    required num amount,
  }) {
    if (cost['status']?.toString() == 'CANCELLED') {
      throw const ApiException('لا يمكن تسجيل دفعة على تكلفة ملغاة.');
    }
    final total = value(cost['totalAmount']);
    final paid = value(cost['paidAmount']);
    final remaining = (total - paid).clamp(0, total);
    if (amount > remaining) {
      throw const ApiException('المبلغ يتجاوز الباقي على التكلفة.');
    }
  }

  static void assertScheduleWithinRemaining({
    required num amount,
    required num remainingAmount,
  }) {
    if (amount > remainingAmount) {
      throw const ApiException('مبلغ الموعد يتجاوز الباقي على التكلفة.');
    }
  }

  static String? asMoney(num? value) {
    if (value == null) return null;
    return value.toStringAsFixed(2);
  }

  static String costStatus(num total, num paid) {
    if (total <= 0 || paid <= 0) return 'OPEN';
    if (paid >= total) return 'PAID';
    return 'PARTIALLY_PAID';
  }
}
