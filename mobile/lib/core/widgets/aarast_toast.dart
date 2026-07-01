import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AarastToast {
  static void showSuccess(BuildContext context, String message, {SnackBarAction? action}) {
    _show(context, message, AppTheme.success, Icons.check_circle_outline_rounded, action);
  }

  static void showError(BuildContext context, String message, {SnackBarAction? action}) {
    _show(context, message, AppTheme.danger, Icons.error_outline_rounded, action);
  }

  static void showInfo(BuildContext context, String message, {SnackBarAction? action}) {
    _show(context, message, AppTheme.gold, Icons.info_outline_rounded, action);
  }

  static void _show(BuildContext context, String message, Color color, IconData icon, SnackBarAction? action) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        duration: const Duration(seconds: 4),
        action: action,
      ),
    );
  }
}
