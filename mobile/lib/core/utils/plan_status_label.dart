/// تحويل حالة الخطة القادمة من الخادم إلى نص عربي معروض للمستخدم.
/// لا يجب أن يظهر أي رمز إنجليزي (PLANNING/ACTIVE) في الواجهة.
String planStatusLabelAr(String status) {
  return switch (status.toUpperCase()) {
    'PLANNING' => 'قيد التخطيط',
    'ACTIVE' => 'نشطة',
    'IN_PROGRESS' => 'قيد التنفيذ',
    'COMPLETED' || 'DONE' => 'مكتملة',
    'ARCHIVED' => 'مؤرشفة',
    'DRAFT' => 'مسودة',
    'CANCELLED' => 'ملغاة',
    _ => 'قيد التخطيط',
  };
}
