/// تحويل رمز العملة القادم من الخادم إلى تسمية عربية معروضة.
/// لا يجب أن يظهر "YER" أو رموز إنجليزية في واجهة عربية-أولًا.
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
