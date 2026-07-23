import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/phone/phone_number_utils.dart';
import '../../../../core/theme/aarast_design_tokens.dart';
import '../../models/guest.dart';
import '../../utils/guest_display.dart';

const _statusValues = ['INVITED', 'CONFIRMED', 'PENDING', 'DECLINED'];

/// صف ضيف تشغيلي مسطّح يحافظ على إجراءات التعديل والحالة والحذف.
///
/// يظهر رقم الجوال كسطر وصفي هادئ ليستمر استخدام القائمة تشغيليًا. أما
/// [Guest.seatsCount] فهو العدد الكامل للمقاعد، بما فيها المرافقون، لذلك لا
/// نضيف [Guest.companionsCount] إليه مرة أخرى.
class SmartGuestCard extends StatelessWidget {
  const SmartGuestCard({
    required this.guest,
    required this.groupLabel,
    required this.isDuplicate,
    required this.isBusy,
    required this.onEdit,
    required this.onStatus,
    required this.onDelete,
    super.key,
  });

  final Guest guest;
  final String groupLabel;
  final bool isDuplicate;
  final bool isBusy;
  final VoidCallback onEdit;
  final ValueChanged<String> onStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = guestStatusColor(guest.status, guest.attendanceStatus);
    final missing = guest.hasMissingData;
    final displayColor = missing
        ? AarastDesignTokens.burgundy
        : isDuplicate
        ? AarastDesignTokens.danger
        : statusColor;
    final displayLabel = missing
        ? 'ناقص بيانات'
        : isDuplicate
        ? 'تكرار محتمل'
        : _attendanceLabel(guest);
    final initial = guest.name.trim().isNotEmpty ? guest.name.trim()[0] : '؟';

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: AarastDesignTokens.surface,
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
            border: Border.all(color: AarastDesignTokens.border),
            boxShadow: AarastDesignTokens.cardShadow(),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: displayColor.withValues(alpha: 0.10),
                  borderRadius: const BorderRadiusDirectional.only(
                    topStart: Radius.circular(15),
                    topEnd: Radius.circular(15),
                    bottomStart: Radius.circular(15),
                    bottomEnd: Radius.circular(4),
                  ),
                ),
                child: Text(
                  initial,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: displayColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guest.name.trim().isEmpty ? 'بدون اسم' : guest.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: guest.name.trim().isEmpty
                            ? AarastDesignTokens.muted
                            : AarastDesignTokens.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _MetaRow(guest: guest, groupLabel: groupLabel),
                    if (guest.notes?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        guest.notes!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AarastDesignTokens.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusChip(label: displayLabel, color: displayColor),
                  const SizedBox(height: 3),
                  _GuestMenu(
                    isBusy: isBusy,
                    onEdit: onEdit,
                    onStatus: onStatus,
                    onDelete: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.guest, required this.groupLabel});

  final Guest guest;
  final String groupLabel;

  @override
  Widget build(BuildContext context) {
    final phone = PhoneNumberUtils.display(guest.phone) ?? guest.phone?.trim();
    return Wrap(
      spacing: 7,
      runSpacing: 3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _MetaItem(label: guestSideLabel(guest.side)),
        if (groupLabel.trim().isNotEmpty && groupLabel != 'بدون مجموعة')
          _MetaItem(label: groupLabel),
        _MetaItem(label: _seatLabel(guest.seatsCount)),
        if (phone != null && phone.isNotEmpty)
          _MetaItem(label: phone, textDirection: TextDirection.ltr),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.label, this.textDirection});

  final String label;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textDirection: textDirection,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AarastDesignTokens.muted,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusPill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _GuestMenu extends StatelessWidget {
  const _GuestMenu({
    required this.isBusy,
    required this.onEdit,
    required this.onStatus,
    required this.onDelete,
  });

  final bool isBusy;
  final VoidCallback onEdit;
  final ValueChanged<String> onStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: !isBusy,
      tooltip: 'إجراءات الضيف',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      icon: const Icon(
        LucideIcons.moreHorizontal,
        color: AarastDesignTokens.muted,
        size: 18,
      ),
      onSelected: (value) {
        if (value == 'edit') {
          onEdit();
        } else if (value == 'delete') {
          onDelete();
        } else if (_statusValues.contains(value)) {
          onStatus(value);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('تعديل')),
        for (final status in _statusValues)
          PopupMenuItem(value: status, child: Text(guestStatusLabel(status))),
        const PopupMenuDivider(),
        const PopupMenuItem(value: 'delete', child: Text('حذف')),
      ],
    );
  }
}

String _attendanceLabel(Guest guest) {
  if (guest.isConfirmed) return 'مؤكد';
  if (guest.isDeclined) return 'لن يحضر';
  if (guest.status == 'INVITED') return 'مدعو';
  return 'بانتظار الرد';
}

String _seatLabel(int count) {
  return switch (count) {
    1 => 'مقعد واحد',
    2 => 'مقعدان',
    >= 3 && <= 10 => '$count مقاعد',
    _ => '$count مقعد',
  };
}
