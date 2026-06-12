import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';

class GuestListScreen extends StatefulWidget {
  const GuestListScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends State<GuestListScreen> {
  final List<_GuestEntry> _guests = [];

  @override
  Widget build(BuildContext context) {
    return AarastPageScaffold(
      title: 'قائمة الضيوف',
      subtitle: 'مساحة جاهزة لربط API الضيوف لاحقًا',
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGuestSheet,
        child: const Icon(Icons.add_rounded),
      ),
      child: ListView(
        children: [
          const AarastCard(
            color: AppTheme.dCard,
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppTheme.dGoldDeep),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'هذه واجهة أمامية مؤقتة بدون حفظ دائم حتى يتم تفعيل API الضيوف. لن يتم إرسال بيانات للباك اند.',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppTheme.dInkSoft,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_guests.isEmpty)
            AarastEmptyState(
              icon: Icons.people_outline_rounded,
              title: 'لا توجد أسماء بعد',
              message:
                  'أضيفي أسماء تجريبية لتنظيم الشكل الآن، وسيتم ربط الحفظ الفعلي في مرحلة الضيوف.',
              action: FilledButton.icon(
                onPressed: _showAddGuestSheet,
                icon: const Icon(Icons.add_rounded),
                label: const Text('إضافة ضيف'),
              ),
            )
          else ...[
            _GuestSummary(count: _guests.length),
            const SizedBox(height: 14),
            for (final guest in _guests) ...[
              _GuestTile(guest: guest),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  Future<void> _showAddGuestSheet() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    var side = 'العائلة';
    var status = 'مدعو';

    final added = await showModalBottomSheet<_GuestEntry>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                return SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.dLine,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'إضافة ضيف',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'اسم الضيف',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم التواصل (اختياري)',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final value in ['العائلة', 'الأصدقاء', 'العمل'])
                            ChoiceChip(
                              label: Text(value),
                              selected: side == value,
                              onSelected: (_) =>
                                  setSheetState(() => side = value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final value in ['مدعو', 'مؤكد', 'اعتذار'])
                            ChoiceChip(
                              label: Text(value),
                              selected: status == value,
                              onSelected: (_) =>
                                  setSheetState(() => status = value),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;
                          Navigator.of(sheetContext).pop(
                            _GuestEntry(
                              name: name,
                              phone: phoneController.text.trim(),
                              side: side,
                              status: status,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('إضافة مؤقتة'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();

    if (added != null) {
      setState(() => _guests.add(added));
    }
  }
}

class _GuestSummary extends StatelessWidget {
  const _GuestSummary({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dCard,
      child: Row(
        children: [
          _SummaryIcon(
            icon: Icons.people_alt_rounded,
            color: AppTheme.dMaroon,
            bg: AppTheme.dPinkBg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count ضيف في القائمة المؤقتة',
              style: const TextStyle(
                color: AppTheme.dInk,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const AarastStatusPill(
            label: 'تجريبي',
            color: AppTheme.dGoldDeep,
            backgroundColor: AppTheme.dCreamBg,
          ),
        ],
      ),
    );
  }
}

class _GuestTile extends StatelessWidget {
  const _GuestTile({required this.guest});

  final _GuestEntry guest;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _SummaryIcon(
            icon: Icons.person_outline_rounded,
            color: _statusColor(guest.status),
            bg: _statusColor(guest.status).withAlpha(24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guest.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  guest.phone.isEmpty
                      ? guest.side
                      : '${guest.side} · ${guest.phone}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.dInkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          AarastStatusPill(
            label: guest.status,
            color: _statusColor(guest.status),
            backgroundColor: _statusColor(guest.status).withAlpha(24),
          ),
        ],
      ),
    );
  }
}

class _SummaryIcon extends StatelessWidget {
  const _SummaryIcon({
    required this.icon,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _GuestEntry {
  const _GuestEntry({
    required this.name,
    required this.phone,
    required this.side,
    required this.status,
  });

  final String name;
  final String phone;
  final String side;
  final String status;
}

Color _statusColor(String status) {
  return switch (status) {
    'مؤكد' => AppTheme.dGreen,
    'اعتذار' => AppTheme.danger,
    _ => AppTheme.dMaroon,
  };
}
