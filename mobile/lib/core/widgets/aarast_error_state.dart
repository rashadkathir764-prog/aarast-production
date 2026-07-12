import 'package:flutter/material.dart';

import 'package:lucide_icons/lucide_icons.dart';

import '../theme/app_theme.dart';
import 'aarast_ui.dart';

class AarastErrorState extends StatelessWidget {
  const AarastErrorState({
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'حاول مرة أخرى',
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dangerSoft,
      border: Border.all(color: AppTheme.dangerSoft),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.dangerSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(
                  LucideIcons.alertCircle,
                  color: AppTheme.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            AarastButton(
              label: retryLabel,
              icon: LucideIcons.refreshCw,
              variant: AarastButtonVariant.secondary,
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    );
  }
}
