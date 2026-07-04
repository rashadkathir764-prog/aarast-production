import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/phone/phone_number_utils.dart';
import '../../../../core/theme/aarast_design_tokens.dart';
import '../../models/guest.dart';
import '../../utils/guest_display.dart';

const _statusValues = ['INVITED', 'CONFIRMED', 'PENDING', 'DECLINED'];

/// بطاقة الضيف الذكية — أفاتار بلون الحالة، اسم، الطرف/المجموعة/المقاعد،
/// رقم الجوال للدعوة، وحالة واحدة واضحة. تنبيهات (ناقص/تكرار) عند الحاجة فقط.
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
    final color = guestStatusColor(guest.status, guest.attendanceStatus);
    final phone = PhoneNumberUtils.display(guest.phone) ?? guest.phone?.trim();
    final missing = guest.hasMissingData;
    final initial =
        guest.name.trim().isNotEmpty ? guest.name.trim()[0] : '؟';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            color: AarastDesignTokens.surface,
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
            border: Border.all(
              color: missing
                  ? AarastDesignTokens.warningSoft
                  : AarastDesignTokens.border,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
            child: Stack(
              children: [
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 4, color: color),
                ),
                Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // مونوغرام بأول حرف من الاسم — أنيق وشخصي.
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(
                                  AarastDesignTokens.radiusMd),
                              border: Border.all(
                                  color: color.withValues(alpha: 0.22)),
                            ),
                            child: Text(
                              initial,
                              style: TextStyle(
                                color: color,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  guest.name.trim().isEmpty
                                      ? 'بدون اسم'
                                      : guest.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: guest.name.trim().isEmpty
                                        ? AarastDesignTokens.muted
                                        : AarastDesignTokens.ink,
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                _MetaRow(guest: guest, groupLabel: groupLabel),
                              ],
                            ),
                          ),
                          _GuestMenu(
                            isBusy: isBusy,
                            onEdit: onEdit,
                            onStatus: onStatus,
                            onDelete: onDelete,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _StatusChip(
                            label: guestStatusLabel(guest.status),
                            color: color,
                            icon: guestStatusIcon(
                                guest.status, guest.attendanceStatus),
                          ),
                          if (phone != null && phone.isNotEmpty)
                            _PhoneChip(phone: phone),
                          if (missing)
                            const _AlertChip(
                              label: 'ناقص بيانات',
                              color: AarastDesignTokens.warning,
                              icon: LucideIcons.info,
                            ),
                          if (isDuplicate)
                            const _AlertChip(
                              label: 'تكرار محتمل',
                              color: AarastDesignTokens.danger,
                              icon: LucideIcons.copy,
                            ),
                        ],
                      ),
                      if (guest.notes?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 9),
                        Text(
                          guest.notes!.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AarastDesignTokens.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
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
    final seats = guest.seatsCount + guest.companionsCount;
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _MetaItem(icon: LucideIcons.users, label: guestSideLabel(guest.side)),
        if (groupLabel.trim().isNotEmpty && groupLabel != 'بدون مجموعة')
          _MetaItem(icon: LucideIcons.folder, label: groupLabel),
        _MetaItem(
          icon: LucideIcons.armchair,
          label: '$seats ${seats == 1 ? 'حضور' : 'حضور'}',
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AarastDesignTokens.muted),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            color: AarastDesignTokens.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneChip extends StatelessWidget {
  const _PhoneChip({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AarastDesignTokens.ivory,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusPill),
        border: Border.all(color: AarastDesignTokens.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.phone,
              size: 12, color: AarastDesignTokens.muted),
          const SizedBox(width: 5),
          Text(
            phone,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: AarastDesignTokens.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  const _AlertChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
      icon: const Icon(LucideIcons.moreVertical,
          color: AarastDesignTokens.muted, size: 18),
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
