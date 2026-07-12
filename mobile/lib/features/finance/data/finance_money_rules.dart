import '../../../core/network/api_client.dart';

abstract final class FinanceMoneyRules {
  static num value(Object? value) {
    return num.tryParse(value?.toString().replaceAll(',', '').trim() ?? '') ??
        0;
  }

  static num assertPositive(Object? value, String field) {
    final parsed = num.tryParse(
      value?.toString().replaceAll(',', '').trim() ?? '',
    );
    if (parsed == null || parsed <= 0) {
      throw ApiException(
        field == 'totalAmount'
            ? 'التكلفة المتفق عليها يجب أن تكون أكبر من صفر.'
            : 'المبلغ يجب أن يكون أكبر من صفر.',
      );
    }
    return parsed;
  }

  static num assertOptionalNonNegative(Object? value, String field) {
    final raw = value?.toString().replaceAll(',', '').trim() ?? '';
    if (raw.isEmpty) return 0;
    final parsed = num.tryParse(raw);
    if (parsed == null || parsed < 0) {
      throw ApiException('$field غير صحيح.');
    }
    return parsed;
  }

  static void assertCommitmentAmounts({
    required String totalAmount,
    String? paidAmount,
  }) {
    final total = assertPositive(totalAmount, 'totalAmount');
    final paid = assertOptionalNonNegative(paidAmount, 'paidAmount');
    if (paid > total) {
      throw const ApiException(
        'المدفوع لا يمكن أن يتجاوز التكلفة المتفق عليها.',
      );
    }
  }

  static void assertPaymentWithinRemaining({
    required Map<String, dynamic> commitment,
    required num amount,
  }) {
    if (commitment['status']?.toString() == 'CANCELLED') {
      throw const ApiException('لا يمكن تسجيل دفعة على التزام ملغي.');
    }
    final total = value(commitment['totalAmount']);
    final paid = value(commitment['paidAmount']);
    final remaining = (total - paid).clamp(0, total);
    if (amount > remaining) {
      throw const ApiException('مبلغ الدفعة لا يمكن أن يتجاوز الباقي المستحق.');
    }
  }

  static String? asMoney(num? value) {
    if (value == null) return null;
    return value.toStringAsFixed(2);
  }

  static String commitmentStatus(num total, num paid) {
    if (total <= 0 || paid <= 0) return 'OPEN';
    if (paid >= total) return 'PAID';
    return 'PARTIALLY_PAID';
  }
}
