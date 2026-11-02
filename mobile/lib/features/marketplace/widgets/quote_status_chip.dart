import 'package:flutter/material.dart';

import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/experience_v3/aarast_v3_foundations.dart';

class QuoteStatusChip extends StatelessWidget {
  const QuoteStatusChip({
    required this.status,
    this.compact = false,
    this.forProvider = false,
    super.key,
  });

  final String status;
  final bool compact;

  /// Words the status from the provider's side ("awaiting your reply")
  /// instead of the customer's ("awaiting the provider").
  final bool forProvider;

  @override
  Widget build(BuildContext context) {
    final presentation = quoteStatusPresentation(
      status,
      forProvider: forProvider,
    );
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AarastV3Space.x2 : AarastV3Space.x3,
        vertical: compact ? AarastV3Space.x1 : AarastV3Space.x2,
      ),
      decoration: BoxDecoration(
        color: presentation.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AarastV3Radius.pill),
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
          const SizedBox(width: AarastV3Space.x1),
          Text(
            presentation.label,
            style:
                (compact
                        ? Theme.of(context).textTheme.labelSmall
                        : Theme.of(context).textTheme.labelMedium)
                    ?.copyWith(
                      color: presentation.color,
                      fontWeight: FontWeight.w900,
                    ),
          ),
        ],
      ),
    );
  }
}

QuoteStatusPresentation quoteStatusPresentation(
  String status, {
  bool forProvider = false,
}) {
  // Field test Q13: the provider was told "awaiting the provider's reply"
  // about a request waiting on them.
  if (forProvider) {
    switch (status) {
      case 'PENDING_PROVIDER':
      case 'SENT':
      case 'VIEWED':
        return const QuoteStatusPresentation(
          label: 'بانتظار ردّك',
          icon: LucideIcons.hourglass,
          color: AppTheme.brand,
        );
      case 'RECEIVED':
      case 'RESPONDED':
        return const QuoteStatusPresentation(
          label: 'أرسلت عرضك',
          icon: LucideIcons.send,
          color: AppTheme.textPrimary,
        );
      case 'ACCEPTED':
        return const QuoteStatusPresentation(
          label: 'قبل العميل عرضك',
          icon: LucideIcons.checkCircle,
          color: AppTheme.success,
        );
      case 'REJECTED':
        return const QuoteStatusPresentation(
          label: 'اعتذر العميل',
          icon: LucideIcons.ban,
          color: AppTheme.danger,
        );
    }
  }
  switch (status) {
    case 'READY_TO_SEND':
      return const QuoteStatusPresentation(
        label: 'جاهز للإرسال',
        icon: LucideIcons.send,
        color: AppTheme.focus,
      );
    case 'PENDING_PROVIDER':
    case 'SENT':
    case 'VIEWED':
      return const QuoteStatusPresentation(
        label: 'بانتظار رد المزود',
        icon: LucideIcons.hourglass,
        color: AppTheme.textPrimary,
      );
    case 'RECEIVED':
    case 'RESPONDED':
      return const QuoteStatusPresentation(
        label: 'وصل عرض سعر',
        icon: LucideIcons.mail,
        color: AppTheme.brand,
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
        color: AppTheme.textSecondary,
      );
    case 'EXPIRED':
      return const QuoteStatusPresentation(
        label: 'منتهي',
        icon: LucideIcons.calendarX,
        color: AppTheme.textSecondary,
      );
    default:
      return const QuoteStatusPresentation(
        label: 'مسودة',
        icon: LucideIcons.fileEdit,
        color: AppTheme.focus,
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
