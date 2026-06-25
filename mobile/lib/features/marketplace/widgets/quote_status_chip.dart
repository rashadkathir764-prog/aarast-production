import 'package:flutter/material.dart';

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
        border: Border.all(
          color: presentation.color.withValues(alpha: 0.24),
        ),
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
        icon: Icons.outbox_outlined,
        color: AppTheme.dGoldDeep,
      );
    case 'PENDING_PROVIDER':
    case 'SENT':
    case 'VIEWED':
      return const QuoteStatusPresentation(
        label: 'بانتظار رد المورد',
        icon: Icons.hourglass_top_rounded,
        color: AppTheme.dBlue,
      );
    case 'RECEIVED':
    case 'RESPONDED':
      return const QuoteStatusPresentation(
        label: 'وصل عرض سعر',
        icon: Icons.mark_email_unread_outlined,
        color: AppTheme.dMaroon,
      );
    case 'ACCEPTED':
      return const QuoteStatusPresentation(
        label: 'مقبول',
        icon: Icons.check_circle_outline_rounded,
        color: AppTheme.success,
      );
    case 'REJECTED':
      return const QuoteStatusPresentation(
        label: 'مرفوض',
        icon: Icons.block_outlined,
        color: Color(0xFFB42318),
      );
    case 'CANCELLED':
      return const QuoteStatusPresentation(
        label: 'ملغي',
        icon: Icons.cancel_outlined,
        color: AppTheme.dMuted,
      );
    case 'EXPIRED':
      return const QuoteStatusPresentation(
        label: 'منتهي',
        icon: Icons.event_busy_outlined,
        color: AppTheme.dMuted,
      );
    default:
      return const QuoteStatusPresentation(
        label: 'مسودة',
        icon: Icons.edit_note_outlined,
        color: AppTheme.dGoldDeep,
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
