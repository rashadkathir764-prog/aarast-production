import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_theme.dart';
import 'aarast_ui.dart';

class AarastComingSoonScreen extends StatelessWidget {
  const AarastComingSoonScreen({
    required this.title,
    required this.message,
    this.icon = LucideIcons.sparkles,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AarastPageScaffold(
      title: title,
      subtitle: 'تجهيز هادئ قبل الإطلاق',
      child: ListView(
        children: [
          const SizedBox(height: 36),
          AarastEmptyState(
            icon: icon,
            title: title,
            message: message,
            action: OutlinedButton.icon(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              },
              icon: const Icon(LucideIcons.chevronRight),
              label: const Text('رجوع'),
            ),
          ),
          const SizedBox(height: AppTheme.gapXl),
          const AarastCard(
            color: AppTheme.surface,
            child: Row(
              children: [
                Icon(LucideIcons.lock, color: AppTheme.gold),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'لن نعرض أزرارًا غير مرتبطة ببيانات فعلية. عند جاهزية الخدمة ستظهر هنا بوضوح.',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
