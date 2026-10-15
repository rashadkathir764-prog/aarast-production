import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'release_field_focus.dart';

/// Every Aarast sheet is a picker or a choice: it releases the field being
/// edited first, so closing it does not reopen the keyboard on that field.
Future<T?> showAarastBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  Color? backgroundColor,
  Color? barrierColor,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  bool useRootNavigator = false,
}) {
  releaseFieldFocus();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor ?? AppTheme.surfaceRaised,
    barrierColor: barrierColor ?? AppTheme.textPrimary.withAlpha(105),
    shape:
        shape ??
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXl),
          ),
        ),
    clipBehavior: clipBehavior,
    constraints: constraints,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    useRootNavigator: useRootNavigator,
    builder: (context) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(builder: builder),
      );
    },
  );
}

class AarastBottomSheetHandle extends StatelessWidget {
  const AarastBottomSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 46,
        height: 4,
        margin: const EdgeInsets.only(top: 10, bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.brandMuted,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
