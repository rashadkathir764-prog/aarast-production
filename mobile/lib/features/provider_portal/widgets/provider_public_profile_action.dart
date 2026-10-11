import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

/// The public profile exists only for an ACTIVE provider (the marketplace
/// lists ACTIVE providers only). Before approval the provider is told when
/// the profile becomes public instead of opening a page that cannot load.
class ProviderPublicProfileAction extends StatelessWidget {
  const ProviderPublicProfileAction({
    required this.status,
    required this.onPreview,
    super.key,
  });

  final String status;
  final VoidCallback onPreview;

  bool get _isPublic => status.toUpperCase() == 'ACTIVE';

  @override
  Widget build(BuildContext context) {
    if (_isPublic) {
      return OutlinedButton.icon(
        onPressed: onPreview,
        icon: const Icon(LucideIcons.eye),
        label: const Text('معاينة الملف العام'),
      );
    }
    return const Row(
      children: [
        Icon(LucideIcons.eyeOff, size: 18, color: AppTheme.textSecondary),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'يظهر ملفك العام للعملاء بعد اعتماد حسابك.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
