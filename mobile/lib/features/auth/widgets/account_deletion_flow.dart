import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';

/// The shared typed confirmation for account deletion, as a journey sheet:
/// the account goes only after «حذف» is typed. The groom's «حسابي» keeps
/// deletion hidden until the 30-day grace exists (C4); a participant and a
/// provider reach it from their own account screens.
Future<bool> confirmAccountDeletion(
  BuildContext context, {
  required String keyPrefix,
}) async {
  return await showJourneySheet<bool>(
        context: context,
        builder: (_) => _AccountDeletionSheet(keyPrefix: keyPrefix),
      ) ==
      true;
}

class _AccountDeletionSheet extends StatefulWidget {
  const _AccountDeletionSheet({required this.keyPrefix});

  final String keyPrefix;

  @override
  State<_AccountDeletionSheet> createState() => _AccountDeletionSheetState();
}

class _AccountDeletionSheetState extends State<_AccountDeletionSheet> {
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typed = _confirmation.text.trim() == 'حذف';
    return JourneySheetBody(
      title: 'حذف حسابك نهائيًا؟',
      subtitle: 'ينحذف الحساب وكل بياناته، وما يرجع بعد الحذف.',
      children: [
        JourneyTextField(
          key: Key('${widget.keyPrefix}-delete-account-input'),
          label: 'اكتب «حذف» للتأكيد',
          controller: _confirmation,
          icon: LucideIcons.trash2,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        JourneyButton(
          key: Key('${widget.keyPrefix}-delete-account-confirm'),
          label: 'احذف نهائيًا',
          background: AarastV3Color.danger,
          expand: true,
          large: true,
          onPressed: typed ? () => Navigator.pop(context, true) : null,
        ),
        const SizedBox(height: 8),
        JourneyButton.quiet(
          label: 'رجوع',
          expand: true,
          onPressed: () => Navigator.pop(context, false),
        ),
      ],
    );
  }
}
