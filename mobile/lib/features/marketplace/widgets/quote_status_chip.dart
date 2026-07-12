import 'package:flutter/material.dart';

import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';

class QuoteStatusChip extends StatelessWidget {
  const QuoteStatusChip({
    required this.status,
    this.compact = false,
    super.key,
  });

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final presentation = quoteStatusPresentation(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: presentation.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: presentation.color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            presentation.icon,
            size: compact ? 14 : 16,
            color: presentation.color,
          ),
          const SizedBox(width: 6),
          Text(
            presentation.label,
            style: TextStyle(
              color: presentation.color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

QuoteStatusPresentation quoteStatusPresentation(String status) {
  switch (status) {
    case 'READY_TO_SEND':
      return const QuoteStatusPresentation(
        label: 'جاهز للإرسال',
        icon: LucideIcons.send,
        color: AppTheme.gold,
      );
    case 'PENDING_PROVIDER':
    case 'SENT':
    case 'VIEWED':
      return const QuoteStatusPresentation(
        label: 'بانتظار رد المورد',
        icon: LucideIcons.hourglass,
        color: AppTheme.ink,
      );
    case 'RECEIVED':
    case 'RESPONDED':
      return const QuoteStatusPresentation(
        label: 'وصل عرض سعر',
        icon: LucideIcons.mail,
        color: AppTheme.burgundy,
      );
    case 'ACCEPTED':
      return const QuoteStatusPresentation(
        label: 'مقبول',
        icon: LucideIcons.checkCircle,
        color: AppTheme.success,
      );
    case 'REJECTED':
      return const QuoteStatusPresentation(
        label: 'مرفوض',
        icon: LucideIcons.ban,
        color: AppTheme.danger,
      );
    case 'CANCELLED':
      return const QuoteStatusPresentation(
        label: 'ملغي',
        icon: LucideIcons.xCircle,
        color: AppTheme.muted,
      );
    case 'EXPIRED':
      return const QuoteStatusPresentation(
        label: 'منتهي',
        icon: LucideIcons.calendarX,
        color: AppTheme.muted,
      );
    default:
      return const QuoteStatusPresentation(
        label: 'مسودة',
        icon: LucideIcons.fileEdit,
        color: AppTheme.gold,
      );
  }
}

class QuoteStatusPresentation {
  const QuoteStatusPresentation({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}
