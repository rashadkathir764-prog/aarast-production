/// تحويل رمز العملة القادم من الخادم إلى تسمية عربية معروضة.
/// لا يجب أن يظهر "YER" أو رموز إنجليزية في واجهة عربية-أولًا.
const defaultCurrencyCode = 'YER';

String currencyLabelAr(String? code) {
  final normalized = code?.trim().toUpperCase();
  return switch (normalized) {
    null || '' || 'YER' || 'YR' => 'ر.ي',
    'SAR' => 'ر.س',
    'USD' => 'دولار',
    'EUR' => 'يورو',
    _ => code!.trim(),
  };
}

String currencyCodeFromDisplayInput(String? value) {
  final normalized = value?.trim().toUpperCase();
  return switch (normalized) {
    null || '' || 'ر.ي' || 'YER' || 'YR' => defaultCurrencyCode,
    'ر.س' || 'SAR' => 'SAR',
    'دولار' || 'USD' => 'USD',
    'يورو' || 'EUR' => 'EUR',
    _ => normalized,
  };
}
