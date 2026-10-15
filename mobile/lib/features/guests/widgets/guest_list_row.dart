import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/guest.dart';
import '../utils/guest_display.dart';

const _statusValues = ['INVITED', 'CONFIRMED', 'PENDING', 'DECLINED'];

/// صف ضيف تشغيلي مسطّح يحافظ على إجراءات التعديل والحالة والحذف.
///
/// يظهر رقم الجوال كسطر وصفي هادئ ليستمر استخدام القائمة تشغيليًا. أما
/// [Guest.seatsCount] فهو العدد الكامل للمقاعد، بما فيها المرافقون، لذلك لا
/// نضيف [Guest.companionsCount] إليه مرة أخرى.
class GuestListRow extends StatelessWidget {
  const GuestListRow({
    required this.guest,
    required this.groupLabel,
    required this.isDuplicate,
    required this.isBusy,
    required this.onEdit,
    required this.onStatus,
    required this.onDelete,
    this.onSendInvitation,
    super.key,
  });

  final Guest guest;
  final String groupLabel;
  final bool isDuplicate;
  final bool isBusy;
  final VoidCallback onEdit;
  final ValueChanged<String> onStatus;
  final VoidCallback onDelete;

  /// Sends the guest their personal RSVP link over WhatsApp (V1 checklist
  /// 4.7); null where links are unavailable (a plan kept on the phone only).
  final VoidCallback? onSendInvitation;

  @override
  Widget build(BuildContext context) {
    final statusColor = guestStatusColor(guest.status, guest.attendanceStatus);
    final missing = guest.hasMissingData;
    final displayColor = missing
        ? AppTheme.brand
        : isDuplicate
        ? AppTheme.danger
        : statusColor;
    final displayLabel = missing
        ? 'ناقص بيانات'
        : isDuplicate
        ? 'تكرار محتمل'
        : _attendanceLabel(guest);
    final initial = guest.name.trim().isNotEmpty ? guest.name.trim()[0] : '؟';

    final primaryAction = missing
        ? _GuestPrimaryAction(
            label: 'إكمال البيانات',
            semanticLabel: 'إكمال بيانات الضيف',
            icon: LucideIcons.userCog,
            onTap: isBusy ? null : onEdit,
          )
        : onSendInvitation != null && guest.invitationStatus == 'NOT_SENT'
        ? _GuestPrimaryAction(
            label: 'إرسال الدعوة',
            semanticLabel: 'إرسال رابط الدعوة للضيف عبر واتساب',
            icon: LucideIcons.send,
            onTap: isBusy ? null : onSendInvitation,
          )
        : guest.status == 'INVITED' || guest.status == 'PENDING'
        ? _GuestPrimaryAction(
            label: 'تحديث الرد',
            semanticLabel: 'تحديث رد الضيف',
            icon: LucideIcons.userCheck,
            onTap: isBusy ? null : () => _showStatusSheet(context),
          )
        : null;

    return AarastV3ListRow(
      title: guest.name.trim().isEmpty ? 'بدون اسم' : guest.name,
      semanticLabel: '${guest.name}، $displayLabel',
      accent: displayColor,
      onTap: isBusy ? null : onEdit,
      leading: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: displayColor.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(AarastV3Radius.control),
        ),
        child: Text(
          initial,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: displayColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetaRow(guest: guest, groupLabel: groupLabel),
          if (guest.notes?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AarastV3Space.x1),
            Text(
              guest.notes!.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
      status: _StatusChip(label: displayLabel, color: displayColor),
      action: _GuestMenu(
        isBusy: isBusy,
        onEdit: onEdit,
        onStatus: onStatus,
        onDelete: onDelete,
        onSendInvitation: onSendInvitation,
      ),
      footer: primaryAction == null
          ? null
          : Align(
              alignment: AlignmentDirectional.centerStart,
              child: primaryAction,
            ),
    );
  }

  Future<void> _showStatusSheet(BuildContext context) async {
    final selected = await showAarastBottomSheet<String>(
      context: context,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'تحديث رد ${guest.name}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                for (final status in _statusValues)
                  if (status != guest.status)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        status == 'CONFIRMED'
                            ? LucideIcons.checkCircle2
                            : status == 'DECLINED'
                            ? LucideIcons.userX
                            : LucideIcons.clock3,
                        color: guestStatusColor(status, status),
                      ),
                      title: Text(guestStatusLabel(status)),
                      onTap: () => Navigator.of(sheetContext).pop(status),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null) onStatus(selected);
  }
}

class _GuestPrimaryAction extends StatelessWidget {
  const _GuestPrimaryAction({
    required this.label,
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 5),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 11)),
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
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 7,
        runSpacing: 3,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _MetaItem(
            label: guestSideLabel(guest.side),
            maxWidth: constraints.maxWidth,
          ),
          if (groupLabel.trim().isNotEmpty && groupLabel != 'بدون مجموعة')
            _MetaItem(label: groupLabel, maxWidth: constraints.maxWidth),
          _MetaItem(
            label: _seatLabel(guest.seatsCount),
            maxWidth: constraints.maxWidth,
          ),
          if (phone != null && phone.isNotEmpty)
            _MetaItem(
              label: phone,
              textDirection: TextDirection.ltr,
              maxWidth: constraints.maxWidth,
            ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.label,
    required this.maxWidth,
    this.textDirection,
  });

  final String label;
  final double maxWidth;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Text(
        label,
        textDirection: textDirection,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w600,
        ),
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
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
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
    this.onSendInvitation,
  });

  final bool isBusy;
  final VoidCallback onEdit;
  final ValueChanged<String> onStatus;
  final VoidCallback onDelete;
  final VoidCallback? onSendInvitation;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: !isBusy,
      tooltip: 'إجراءات الضيف',
      padding: EdgeInsets.zero,
      // PopupMenuButton.constraints belongs to the opened menu, not its icon.
      // A 44x44 tight menu made every Arabic action wrap and clip on device.
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 240),
      icon: const Icon(
        LucideIcons.moreHorizontal,
        color: AppTheme.textSecondary,
        size: 18,
      ),
      onSelected: (value) {
        if (value == 'edit') {
          onEdit();
        } else if (value == 'invite') {
          onSendInvitation?.call();
        } else if (value == 'delete') {
          onDelete();
        } else if (_statusValues.contains(value)) {
          onStatus(value);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'edit', child: Text('تعديل')),
        if (onSendInvitation != null)
          const PopupMenuItem(
            value: 'invite',
            child: Text('إرسال رابط الدعوة'),
          ),
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
