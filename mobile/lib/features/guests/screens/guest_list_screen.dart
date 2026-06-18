import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_phone_field_suffix.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/guest.dart';
import '../providers/guests_provider.dart';

class GuestListScreen extends StatefulWidget {
  const GuestListScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends State<GuestListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  void didUpdateWidget(covariant GuestListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuestsProvider>();
    final planIdReady = widget.weddingPlanId.trim().isNotEmpty;

    return AarastPageScaffold(
      title: 'قائمة الضيوف',
      subtitle: 'إدارة الحضور وحالة الدعوات',
      floatingActionButton: FloatingActionButton(
        onPressed: planIdReady && !provider.isSubmitting
            ? () => _showGuestSheet()
            : null,
        child: const Icon(Icons.add_rounded),
      ),
      child: RefreshIndicator(
        color: AppTheme.dMaroon,
        onRefresh: _load,
        child: _body(provider, planIdReady),
      ),
    );
  }

  Widget _body(GuestsProvider provider, bool planIdReady) {
    if (!planIdReady) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          AarastEmptyState(
            icon: Icons.event_busy_outlined,
            title: 'اختاري خطة أولاً',
            message: 'لا يمكن إدارة الضيوف بدون خطة زفاف محددة.',
          ),
        ],
      );
    }

    if (provider.isLoading && provider.guests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && provider.guests.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          AarastEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'تعذر تحميل الضيوف',
            message: provider.errorMessage!,
            action: OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    if (provider.guests.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 40),
          AarastEmptyState(
            icon: Icons.people_outline_rounded,
            title: 'لا توجد أسماء بعد',
            message: 'أضيفي أول ضيف ليتم حفظه في الخطة.',
            action: FilledButton.icon(
              onPressed: () => _showGuestSheet(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة ضيف'),
            ),
          ),
        ],
      );
    }

    return ListView(
      children: [
        _GuestSummary(guests: provider.guests),
        const SizedBox(height: 14),
        for (final guest in provider.guests) ...[
          _GuestTile(
            guest: guest,
            onEdit: () => _showGuestSheet(guest: guest),
            onStatus: (status) => _updateStatus(guest, status),
            onDelete: () => _confirmDelete(guest),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 90),
      ],
    );
  }

  Future<void> _load() {
    return context.read<GuestsProvider>().loadGuests(widget.weddingPlanId);
  }

  Future<void> _showGuestSheet({Guest? guest}) async {
    final result = await showModalBottomSheet<_GuestSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GuestFormSheet(guest: guest),
    );

    if (result == null || !mounted) return;

    final provider = context.read<GuestsProvider>();
    final ok = guest == null
        ? await provider.createGuest(
            weddingPlanId: widget.weddingPlanId,
            name: result.name,
            phone: result.phone,
            side: result.side,
            status: result.status,
            seatsCount: result.seatsCount,
            notes: result.notes,
          )
        : await provider.updateGuest(
            guest: guest,
            name: result.name,
            phone: result.phone ?? '',
            side: result.side,
            status: result.status,
            seatsCount: result.seatsCount,
            notes: result.notes,
          );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('تم حفظ الضيف.')));
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(provider.errorMessage ?? 'تعذر حفظ الضيف.')),
        );
    }
  }

  Future<void> _updateStatus(Guest guest, String status) async {
    await context.read<GuestsProvider>().updateGuest(
      guest: guest,
      status: status,
    );
  }

  Future<void> _confirmDelete(Guest guest) async {
    final provider = context.read<GuestsProvider>();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'حذف ${guest.name}؟',
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(
                          color: AppTheme.dInk,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سيتم حذف الضيف من قائمة هذه الخطة.',
                    style: TextStyle(
                      color: AppTheme.dInkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(sheetContext).pop(false),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.of(sheetContext).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.danger,
                          ),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('حذف'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed == true) {
      final ok = await provider.deleteGuest(guest);
      if (ok && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('تم حذف الضيف.')));
      }
    }
  }
}

class _GuestFormSheet extends StatefulWidget {
  const _GuestFormSheet({this.guest});

  final Guest? guest;

  @override
  State<_GuestFormSheet> createState() => _GuestFormSheetState();
}

class _GuestFormSheetState extends State<_GuestFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;
  late String _side;
  late String _status;
  late int _seatsCount;
  String? _sheetError;

  @override
  void initState() {
    super.initState();
    final guest = widget.guest;
    _nameController = TextEditingController(text: guest?.name ?? '');
    _phoneController = TextEditingController(text: guest?.phone ?? '');
    _notesController = TextEditingController(text: guest?.notes ?? '');
    _side = guest?.side ?? 'OTHER';
    _status = guest?.status ?? 'INVITED';
    _seatsCount = guest?.seatsCount ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _sheetError = 'اسم الضيف مطلوب');
      return;
    }

    String? phone;
    try {
      phone = normalizeOptionalYemeniPhone(_phoneController.text);
    } on FormatException {
      setState(() => _sheetError = 'رقم الهاتف غير صحيح');
      return;
    }

    setState(() => _sheetError = null);
    Navigator.of(context).pop(
      _GuestSheetResult(
        name: name,
        phone: phone,
        side: _side,
        status: _status,
        seatsCount: _seatsCount,
        notes: _notesController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guest = widget.guest;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
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
                  guest == null ? 'إضافة ضيف' : 'تعديل ضيف',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الضيف',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم التواصل (اختياري)',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    suffixIcon: ContactPhoneFieldSuffix(
                      controller: _phoneController,
                      onPhoneSelected: (_) {
                        if (!mounted) return;
                        setState(() => _sheetError = null);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _side,
                  items: _sideValues
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(_sideLabel(item)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _side = value);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'القسم',
                    prefixIcon: Icon(Icons.group_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  items: _statusValues
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(_statusLabel(item)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _status = value);
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'حالة الدعوة',
                    prefixIcon: Icon(Icons.mark_email_read_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'عدد المقاعد: $_seatsCount',
                        style: const TextStyle(
                          color: AppTheme.dInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _seatsCount > 1
                          ? () => setState(() => _seatsCount--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    IconButton(
                      onPressed: _seatsCount < 20
                          ? () => setState(() => _seatsCount++)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(guest == null ? 'إضافة ضيف' : 'حفظ التعديل'),
                ),
                if (_sheetError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _sheetError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestSheetResult {
  const _GuestSheetResult({
    required this.name,
    required this.side,
    required this.status,
    required this.seatsCount,
    this.phone,
    this.notes,
  });

  final String name;
  final String? phone;
  final String side;
  final String status;
  final int seatsCount;
  final String? notes;
}

class _GuestSummary extends StatelessWidget {
  const _GuestSummary({required this.guests});

  final List<Guest> guests;

  @override
  Widget build(BuildContext context) {
    final totalSeats = guests.fold<int>(
      0,
      (sum, guest) => sum + guest.seatsCount,
    );
    final confirmed = guests
        .where((guest) => guest.status == 'CONFIRMED')
        .length;
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
              '${guests.length} ضيف، $totalSeats مقعد',
              style: const TextStyle(
                color: AppTheme.dInk,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          AarastStatusPill(
            label: '$confirmed مؤكد',
            color: AppTheme.dGreen,
            backgroundColor: AppTheme.dGreen.withAlpha(24),
          ),
        ],
      ),
    );
  }
}

class _GuestTile extends StatelessWidget {
  const _GuestTile({
    required this.guest,
    required this.onEdit,
    required this.onStatus,
    required this.onDelete,
  });

  final Guest guest;
  final VoidCallback onEdit;
  final ValueChanged<String> onStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(guest.status);
    return AarastCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _SummaryIcon(
            icon: Icons.person_outline_rounded,
            color: color,
            bg: color.withAlpha(24),
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
                const SizedBox(height: 3),
                Text(
                  [
                    _sideLabel(guest.side),
                    '${guest.seatsCount} مقعد',
                    if (guest.phone?.trim().isNotEmpty == true)
                      guest.phone!.trim(),
                  ].join(' · '),
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
            label: _statusLabel(guest.status),
            color: color,
            backgroundColor: color.withAlpha(24),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
              if (_statusValues.contains(value)) onStatus(value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('تعديل')),
              for (final status in _statusValues)
                PopupMenuItem(value: status, child: Text(_statusLabel(status))),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete', child: Text('حذف')),
            ],
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

const _sideValues = ['GROOM', 'BRIDE', 'FAMILY', 'FRIEND', 'OTHER'];
const _statusValues = ['INVITED', 'CONFIRMED', 'DECLINED', 'PENDING'];

String _sideLabel(String side) {
  return switch (side) {
    'GROOM' => 'أهل العريس',
    'BRIDE' => 'أهل العروس',
    'FAMILY' => 'العائلة',
    'FRIEND' => 'الأصدقاء',
    _ => 'أخرى',
  };
}

String _statusLabel(String status) {
  return switch (status) {
    'CONFIRMED' => 'مؤكد',
    'DECLINED' => 'اعتذر',
    'PENDING' => 'بانتظار الرد',
    _ => 'مدعو',
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'CONFIRMED' => AppTheme.dGreen,
    'DECLINED' => AppTheme.danger,
    'PENDING' => AppTheme.dGoldDeep,
    _ => AppTheme.dMaroon,
  };
}
