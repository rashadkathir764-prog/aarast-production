import '../../../core/network/api_client.dart';

abstract final class FinanceMoneyRules {
  /// D86: the server's own shape for an amount (`money.ts`): up to twelve
  /// digits and two decimals. The phone refuses the same, so a change kept
  /// on the phone is never refused later for its shape.
  static final RegExp serverAmount = RegExp(r'^\d{1,12}(\.\d{1,2})?$');

  static const _shapeMessage =
      'أرقام بس، بحد أقصى 12 رقمًا وخانتين بعد الفاصلة.';

  static num value(Object? value) {
    return num.tryParse(value?.toString().replaceAll(',', '').trim() ?? '') ??
        0;
  }

  static num assertPositive(Object? value, String label) {
    final raw = value?.toString().replaceAll(',', '').trim() ?? '';
    final parsed = num.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      throw ApiException('$label لازم يكون أكبر من صفر.');
    }
    if (!serverAmount.hasMatch(raw)) {
      throw ApiException('$label: $_shapeMessage');
    }
    return parsed;
  }

  static num assertOptionalNonNegative(Object? value, String label) {
    final raw = value?.toString().replaceAll(',', '').trim() ?? '';
    if (raw.isEmpty) return 0;
    final parsed = num.tryParse(raw);
    if (parsed == null || parsed < 0) {
      throw ApiException('$label مش صحيح.');
    }
    if (!serverAmount.hasMatch(raw)) {
      throw ApiException('$label: $_shapeMessage');
    }
    return parsed;
  }

  static void assertCostAmounts({
    required String totalAmount,
    String? initialPaymentAmount,
  }) {
    final total = assertPositive(totalAmount, 'مبلغ الاتفاق');
    final paid = assertOptionalNonNegative(
      initialPaymentAmount,
      'الدفعة الأولى',
    );
    if (paid > total) {
      throw const ApiException('الدفعة الأولى ما تزيد عن الاتفاق.');
    }
  }

  static void assertPaymentWithinRemaining({
    required Map<String, dynamic> cost,
    required num amount,
  }) {
    if (cost['status']?.toString() == 'CANCELLED') {
      throw const ApiException('الاتفاق ملغي، ما تنسجّل عليه دفعة.');
    }
    final total = value(cost['totalAmount']);
    final paid = value(cost['paidAmount']);
    final remaining = (total - paid).clamp(0, total);
    if (amount > remaining) {
      throw const ApiException('المبلغ أكثر من الباقي على الاتفاق.');
    }
  }

  static void assertScheduleWithinRemaining({
    required num amount,
    required num remainingAmount,
  }) {
    if (amount > remainingAmount) {
      throw const ApiException('مبلغ الموعد أكثر من الباقي على الاتفاق.');
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

  /// The status once the balance moved. D107, as the server's
  /// `statusAfterReversal`: an expense is its payment, so with nothing paid
  /// it is cancelled, never left owed (RA-BE-130).
  static String balanceStatus({
    required bool expense,
    required num total,
    required num paid,
  }) => expense && paid <= 0 ? 'CANCELLED' : costStatus(total, paid);
}
