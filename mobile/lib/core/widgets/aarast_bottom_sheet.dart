import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

Future<T?> showAarastBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withAlpha(105),
    builder: (context) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          margin: const EdgeInsets.only(top: 16),
          decoration: const BoxDecoration(
            color: AppTheme.ivory,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXl),
            ),
          ),
          child: builder(context),
        ),
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
          color: AppTheme.burgundySoft,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
