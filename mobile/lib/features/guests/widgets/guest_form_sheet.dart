import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/contacts/contact_duplicate_utils.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/contact_phone_field.dart';
import '../models/guest.dart';
import '../utils/guest_display.dart';

class GuestFormSheet extends StatefulWidget {
  const GuestFormSheet({
    required this.existingGuests,
    required this.groups,
    required this.blockDuplicatePhone,
    this.guest,
    super.key,
  });

  final Guest? guest;
  final List<Guest> existingGuests;
  final List<GuestGroup> groups;
  final bool blockDuplicatePhone;

  @override
  State<GuestFormSheet> createState() => _GuestFormSheetState();
}

class _GuestFormSheetState extends State<GuestFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;
  late String _side;
  late String _status;
  late String? _groupId;
  late int _seatsCount;
  late int _companionsCount;
  String? _sheetError;

  @override
  void initState() {
    super.initState();
    final guest = widget.guest;
    _nameController = TextEditingController(text: guest?.name ?? '');
    _phoneController = TextEditingController(text: guest?.phone ?? '');
    _notesController = TextEditingController(text: guest?.notes ?? '');
    _nameController.addListener(_handleContactChanged);
    _phoneController.addListener(_handleContactChanged);
    _side = _supportedSide(guest?.side);
    _status = guest?.status ?? 'INVITED';
    _groupId =
        widget.groups.isEmpty ||
            widget.groups.any((group) => group.id == guest?.groupId)
        ? guest?.groupId
        : null;
    _seatsCount = guest?.seatsCount ?? 1;
    _companionsCount = guest?.companionsCount ?? 0;
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleContactChanged)
      ..dispose();
    _phoneController
      ..removeListener(_handleContactChanged)
      ..dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleContactChanged() {
    if (mounted) setState(() {});
  }

  Guest? get _duplicatePhoneGuest {
    return ContactDuplicateUtils.findByPhone(
      widget.existingGuests,
      candidatePhone: _phoneController.text,
      phoneOf: (guest) => guest.phone,
      exclude: (guest) => guest.id == widget.guest?.id,
    );
  }

  bool get _hasSoftNameDuplicate {
    if (_phoneController.text.trim().isNotEmpty) return false;
    return widget.existingGuests.any(
      (guest) =>
          guest.id != widget.guest?.id &&
          ContactDuplicateUtils.sameName(guest.name, _nameController.text),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _sheetError = 'اسم الضيف مطلوب');
      return;
    }

    if (_duplicatePhoneGuest != null && widget.blockDuplicatePhone) {
      setState(() => _sheetError = 'هذا الضيف موجود مسبقًا');
      return;
    }

    String? phone;
    try {
      phone = PhoneNumberUtils.normalizeOptional(_phoneController.text);
    } on FormatException {
      setState(() => _sheetError = PhoneNumberUtils.invalidMessage);
      return;
    }

    setState(() => _sheetError = null);
    Navigator.of(context).pop(
      GuestFormResult(
        name: name,
        phone: phone,
        groupId: _groupId,
        side: _side,
        status: _status,
        seatsCount: _seatsCount,
        companionsCount: _companionsCount,
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
                const GuestSheetHandle(),
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
                    prefixIcon: Icon(LucideIcons.user),
                  ),
                ),
                const SizedBox(height: 12),
                ContactPhoneField(
                  nameController: _nameController,
                  phoneController: _phoneController,
                  label: 'رقم الجوال (اختياري)',
                  duplicateMessage: _duplicatePhoneGuest == null
                      ? null
                      : 'هذا الضيف موجود مسبقًا',
                  onDraftChanged: (_) {
                    if (!mounted) return;
                    setState(() => _sheetError = null);
                  },
                ),
                if (_hasSoftNameDuplicate) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'يوجد ضيف بنفس الاسم دون رقم. يمكنك المتابعة إذا كان شخصًا آخر.',
                    style: TextStyle(
                      color: AppTheme.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _ChipPickerRow(
                  label: 'الطرف',
                  options: [
                    for (final item in _sideValues)
                      _ChipOption(value: item, label: guestSideLabel(item)),
                  ],
                  selected: _side,
                  onSelected: (value) => setState(() => _side = value),
                ),
                const SizedBox(height: 12),
                if (widget.groups.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _groupId,
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('بدون مجموعة'),
                      ),
                      for (final group in widget.groups)
                        DropdownMenuItem(
                          value: group.id,
                          child: Text(group.name),
                        ),
                    ],
                    onChanged: (value) {
                      setState(
                        () => _groupId = value?.isEmpty == true ? null : value,
                      );
                    },
                    decoration: const InputDecoration(
                      labelText: 'المجموعة',
                      prefixIcon: Icon(LucideIcons.folderOpen),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _ChipPickerRow(
                  label: 'حالة الرد',
                  options: [
                    for (final item in _statusValues)
                      _ChipOption(value: item, label: _statusLabel(item)),
                  ],
                  selected: _status,
                  onSelected: (value) => setState(() => _status = value),
                ),
                const SizedBox(height: 12),
                _StepperRow(
                  label: 'الحضور المتوقع: $_seatsCount',
                  onMinus: _seatsCount > 1
                      ? () => setState(() {
                          _seatsCount--;
                          if (_companionsCount >= _seatsCount) {
                            _companionsCount = _seatsCount - 1;
                          }
                        })
                      : null,
                  onPlus: _seatsCount < 20
                      ? () => setState(() => _seatsCount++)
                      : null,
                ),
                const SizedBox(height: 8),
                _StepperRow(
                  label: 'عدد المرافقين: $_companionsCount',
                  onMinus: _companionsCount > 0
                      ? () => setState(() => _companionsCount--)
                      : null,
                  onPlus: _companionsCount < 20
                      ? () => setState(() {
                          _companionsCount++;
                          if (_seatsCount < _companionsCount + 1) {
                            _seatsCount = _companionsCount + 1;
                          }
                        })
                      : null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات (اختياري)',
                    prefixIcon: Icon(LucideIcons.stickyNote),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(LucideIcons.check, size: 18),
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

class GuestFormResult {
  const GuestFormResult({
    required this.name,
    required this.side,
    required this.status,
    required this.seatsCount,
    required this.companionsCount,
    this.phone,
    this.groupId,
    this.notes,
  });

  final String name;
  final String? phone;
  final String? groupId;
  final String side;
  final String status;
  final int seatsCount;
  final int companionsCount;
  final String? notes;
}

class GuestSheetHandle extends StatelessWidget {
  const GuestSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _ChipOption {
  const _ChipOption({required this.value, required this.label});

  final String value;
  final String label;
}

class _ChipPickerRow extends StatelessWidget {
  const _ChipPickerRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<_ChipOption> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelMedium?.copyWith(color: AppTheme.muted),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelected(option.value),
                  borderRadius: BorderRadius.circular(999),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: option.value == selected
                          ? AppTheme.burgundy
                          : AppTheme.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: option.value == selected
                            ? AppTheme.burgundy
                            : AppTheme.border,
                      ),
                    ),
                    child: Text(
                      option.label,
                      style: textTheme.labelMedium?.copyWith(
                        color: option.value == selected
                            ? Colors.white
                            : AppTheme.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton(
            onPressed: onMinus,
            icon: const Icon(LucideIcons.minusCircle),
            tooltip: 'تقليل العدد',
          ),
          IconButton(
            onPressed: onPlus,
            icon: const Icon(LucideIcons.plusCircle),
            tooltip: 'زيادة العدد',
          ),
        ],
      ),
    );
  }
}

const _sideValues = ['GROOM', 'BRIDE', 'OTHER'];
const _statusValues = ['INVITED', 'CONFIRMED', 'PENDING', 'DECLINED'];

String _supportedSide(String? side) {
  return _sideValues.contains(side) ? side! : 'OTHER';
}

String _statusLabel(String status) {
  return switch (status) {
    'CONFIRMED' => 'مؤكد',
    'DECLINED' => 'لن يحضر',
    'PENDING' => 'بانتظار الرد',
    _ => 'مدعو',
  };
}
