import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('date pickers use one white surface without Material tint', () {
    final theme = AppTheme.light().datePickerTheme;

    expect(theme.backgroundColor, AppTheme.surface);
    expect(theme.headerBackgroundColor, AppTheme.surface);
    expect(theme.rangePickerBackgroundColor, AppTheme.surface);
    expect(theme.rangePickerHeaderBackgroundColor, AppTheme.surface);
    expect(theme.surfaceTintColor, Colors.transparent);
    expect(theme.rangePickerSurfaceTintColor, Colors.transparent);
    expect(theme.elevation, 6);
    expect(theme.rangePickerElevation, 6);
    expect(
      theme.shape,
      const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusXl)),
        side: BorderSide(color: AppTheme.border),
      ),
    );
    expect(theme.rangePickerShape, theme.shape);
  });
}
