import 'package:flutter/material.dart';

import '../experience_v3/aarast_v3.dart';
import '../theme/app_theme.dart';

class AarastErrorState extends StatelessWidget {
  const AarastErrorState({
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'جرّب مرة ثانية',
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return AarastV3StateSurface(
      kind: AarastV3ScreenStateKind.error,
      title: title,
      message: message,
      preferInlineAction: true,
      action: onRetry == null
          ? null
          : TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.danger,
                backgroundColor: AppTheme.dangerSoft,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: AarastV3Space.x3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusControl),
                ),
              ),
              child: Text(
                retryLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: JourneyType.label,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );
  }
}
