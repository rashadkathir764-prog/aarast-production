import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_duplicate_utils.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
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
    this.draftScope,
    super.key,
  });

  final Guest? guest;
  final List<Guest> existingGuests;
  final List<GuestGroup> groups;
  final bool blockDuplicatePhone;
  final String? draftScope;

  @override
  State<GuestFormSheet> createState() => _GuestFormSheetState();
}

class _GuestFormSheetState extends State<GuestFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _notesController;
  late String _side;
  late String _status;
  late String? _groupId;
  late int _seatsCount;
  late int _companionsCount;
  AarastFormDraftCoordinator? _draft;
  bool _didConfigureDraft = false;
  bool _restoringDraft = false;

  @override
  void initState() {
    super.initState();
    final guest = widget.guest;
    _nameController = TextEditingController(text: guest?.name ?? '');
    _phoneController = TextEditingController(text: guest?.phone ?? '');
    _notesController = TextEditingController(text: guest?.notes ?? '');
    _nameController.addListener(_handleContactChanged);
    _phoneController.addListener(_handleContactChanged);
    _notesController.addListener(_handleContactChanged);
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didConfigureDraft) return;
    _didConfigureDraft = true;
    final scope = widget.draftScope?.trim();
    if (scope == null || scope.isEmpty) return;
    final store = context.read<AarastFormDraftStore?>();
    if (store == null) return;
    _draft = AarastFormDraftCoordinator(
      store: store,
      scope: scope,
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_restoreDraft());
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_handleContactChanged)
      ..dispose();
    _phoneController
      ..removeListener(_handleContactChanged)
      ..dispose();
    _notesController
      ..removeListener(_handleContactChanged)
      ..dispose();
    _draft?.dispose();
    super.dispose();
  }

  void _handleContactChanged() {
    if (!mounted) return;
    setState(() {});
    _scheduleDraft();
  }

  Future<void> _restoreDraft() async {
    final data = await _draft?.restore();
    if (!mounted || data == null) return;
    _restoringDraft = true;
    _nameController.text = data['name']?.toString() ?? _nameController.text;
    _phoneController.text = data['phone']?.toString() ?? _phoneController.text;
    _notesController.text = data['notes']?.toString() ?? _notesController.text;
    final side = data['side']?.toString();
    final status = data['status']?.toString();
    final groupId = data['groupId']?.toString();
    setState(() {
      if (side != null && _sideValues.contains(side)) _side = side;
      if (status != null && _statusValues.contains(status)) _status = status;
      if (groupId != null &&
          widget.groups.any((group) => group.id == groupId)) {
        _groupId = groupId;
      }
      _seatsCount = _draftInt(data['seatsCount'], _seatsCount).clamp(1, 20);
      _companionsCount = _draftInt(
        data['companionsCount'],
        _companionsCount,
      ).clamp(0, 20);
      if (_companionsCount >= _seatsCount) {
        _seatsCount = (_companionsCount + 1).clamp(1, 20);
      }
    });
    _restoringDraft = false;
  }

  int _draftInt(Object? value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  void _scheduleDraft() {
    if (_restoringDraft) return;
    _draft?.schedule({
      'name': _nameController.text,
      'phone': _phoneController.text,
      'notes': _notesController.text,
      'side': _side,
      'status': _status,
      'groupId': _groupId,
      'seatsCount': _seatsCount,
      'companionsCount': _companionsCount,
    });
  }

  void _mutate(VoidCallback change) {
    setState(change);
    _scheduleDraft();
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
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final phone = PhoneNumberUtils.normalizeOptional(_phoneController.text);
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
      child: AarastV3BottomSheetFormLayout(
        header: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const GuestSheetHandle(),
            const SizedBox(height: AppTheme.space8),
            _GuestFormHeader(
              editing: guest != null,
              onClose: () => Navigator.of(context).pop(),
            ),
            if (_draft != null) ...[
              const SizedBox(height: AppTheme.space8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AarastV3DraftStatusLine(status: _draft!.status),
              ),
            ],
          ],
        ),
        action: AarastV3PrimaryAction(
          label: guest == null ? 'إضافة ضيف' : 'حفظ التعديل',
          icon: LucideIcons.check,
          onPressed: _submit,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AarastV3FocusPrompt(
                question: 'من الضيف الذي تريد إضافته؟',
                supportingText:
                    'الاسم يكفي للبدء؛ أكمل الهاتف والرد والمقاعد عندما تعرفها.',
                icon: LucideIcons.userPlus,
              ),
              const SizedBox(height: AppTheme.space10),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم الضيف',
                  prefixIcon: Icon(LucideIcons.user),
                ),
                validator: (value) =>
                    value?.trim().isEmpty == true ? 'اسم الضيف مطلوب' : null,
              ),
              const SizedBox(height: AppTheme.space10),
              ContactPhoneField(
                nameController: _nameController,
                phoneController: _phoneController,
                label: 'رقم الجوال',
                duplicateMessage: _duplicatePhoneGuest == null
                    ? null
                    : 'هذا الضيف موجود مسبقًا',
                duplicateIsBlocking: widget.blockDuplicatePhone,
                onDraftChanged: (_) {
                  if (!mounted) return;
                  setState(() {});
                  _scheduleDraft();
                },
              ),
              if (_hasSoftNameDuplicate) ...[
                const SizedBox(height: AppTheme.space4),
                const Text(
                  'يوجد اسم مشابه بلا رقم؛ يمكنك المتابعة إن كان شخصاً آخر.',
                  style: TextStyle(
                    color: AppTheme.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.space10),
              AarastV3Disclosure(
                title: 'تفاصيل إضافية',
                subtitle: 'الطرف والرد والمقاعد والمجموعة',
                icon: LucideIcons.slidersHorizontal,
                initiallyExpanded:
                    guest != null ||
                    _groupId != null ||
                    _notesController.text.trim().isNotEmpty ||
                    _side != 'OTHER' ||
                    _status != 'INVITED' ||
                    _seatsCount != 1 ||
                    _companionsCount != 0,
                child: Column(
                  children: [
                    _CompactDecisionSurface(
                      children: [
                        _ChipPickerRow(
                          label: 'الطرف',
                          options: [
                            for (final item in _sideValues)
                              _ChipOption(
                                value: item,
                                label: guestSideLabel(item),
                              ),
                          ],
                          selected: _side,
                          onSelected: (value) => _mutate(() => _side = value),
                        ),
                        const SizedBox(height: AppTheme.space8),
                        _ChipPickerRow(
                          label: 'حالة الرد',
                          options: [
                            for (final item in _statusValues)
                              _ChipOption(
                                value: item,
                                label: _statusLabel(item),
                              ),
                          ],
                          selected: _status,
                          onSelected: (value) => _mutate(() => _status = value),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space8),
                    Row(
                      children: [
                        Expanded(
                          child: _CompactStepper(
                            label: 'المقاعد',
                            value: _seatsCount,
                            onMinus: _seatsCount > 1
                                ? () => _mutate(() {
                                    _seatsCount--;
                                    if (_companionsCount >= _seatsCount) {
                                      _companionsCount = _seatsCount - 1;
                                    }
                                  })
                                : null,
                            onPlus: _seatsCount < 20
                                ? () => _mutate(() => _seatsCount++)
                                : null,
                          ),
                        ),
                        const SizedBox(width: AppTheme.space8),
                        Expanded(
                          child: _CompactStepper(
                            label: 'المرافقون',
                            value: _companionsCount,
                            onMinus: _companionsCount > 0
                                ? () => _mutate(() => _companionsCount--)
                                : null,
                            onPlus: _companionsCount < 20
                                ? () => _mutate(() {
                                    _companionsCount++;
                                    if (_seatsCount < _companionsCount + 1) {
                                      _seatsCount = _companionsCount + 1;
                                    }
                                  })
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space8),
                    _GuestOptionalDetails(
                      groups: widget.groups,
                      groupId: _groupId,
                      onGroupChanged: (value) {
                        _mutate(
                          () =>
                              _groupId = value?.isEmpty == true ? null : value,
                        );
                      },
                      notesController: _notesController,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.space10),
              AarastV3LiveSummary(
                items: [
                  AarastV3SummaryItem(
                    label: 'الضيف',
                    value: _nameController.text.trim().isEmpty
                        ? 'لم يُكتب بعد'
                        : _nameController.text.trim(),
                  ),
                  AarastV3SummaryItem(
                    label: 'الرد',
                    value: _statusLabel(_status),
                  ),
                  AarastV3SummaryItem(label: 'المقاعد', value: '$_seatsCount'),
                ],
              ),
            ],
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

class _GuestFormHeader extends StatelessWidget {
  const _GuestFormHeader({required this.editing, required this.onClose});

  final bool editing;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.inkSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusControl),
          ),
          child: const Icon(
            LucideIcons.userPlus,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: AppTheme.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editing ? 'تعديل ضيف' : 'ضيف جديد',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.textPrimary,
                  fontFamily: AppTheme.displayFontFamily,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'الاسم أولاً، والبقية حسب حاجتك.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onClose,
          tooltip: 'إغلاق',
          icon: const Icon(LucideIcons.x),
        ),
      ],
    );
  }
}

class _CompactDecisionSurface extends StatelessWidget {
  const _CompactDecisionSurface({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space8),
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _GuestOptionalDetails extends StatelessWidget {
  const _GuestOptionalDetails({
    required this.groups,
    required this.groupId,
    required this.onGroupChanged,
    required this.notesController,
  });

  final List<GuestGroup> groups;
  final String? groupId;
  final ValueChanged<String?> onGroupChanged;
  final TextEditingController notesController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (groups.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            initialValue: groupId,
            items: [
              const DropdownMenuItem(value: '', child: Text('بدون مجموعة')),
              for (final group in groups)
                DropdownMenuItem(value: group.id, child: Text(group.name)),
            ],
            onChanged: onGroupChanged,
            decoration: const InputDecoration(
              labelText: 'المجموعة',
              prefixIcon: Icon(LucideIcons.folderOpen),
            ),
          ),
          const SizedBox(height: AppTheme.space8),
        ],
        TextFormField(
          controller: notesController,
          minLines: 1,
          maxLines: 2,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'ملاحظة قصيرة',
            prefixIcon: Icon(LucideIcons.stickyNote),
          ),
        ),
      ],
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
          style: textTheme.labelMedium?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var index = 0; index < options.length; index++) ...[
              if (index > 0) const SizedBox(width: AppTheme.space6),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final option = options[index];
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onSelected(option.value),
                        borderRadius: BorderRadius.circular(999),
                        child: Ink(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: option.value == selected
                                ? AppTheme.brand
                                : AppTheme.surfaceRaised,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: option.value == selected
                                  ? AppTheme.brand
                                  : AppTheme.border,
                            ),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                option.label,
                                maxLines: 1,
                                style: textTheme.labelMedium?.copyWith(
                                  color: option.value == selected
                                      ? Colors.white
                                      : AppTheme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _CompactStepper extends StatelessWidget {
  const _CompactStepper({
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final int value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.space6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _StepperButton(
            icon: LucideIcons.minus,
            onPressed: onMinus,
            tooltip: 'تقليل العدد',
          ),
          SizedBox(
            width: 24,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _StepperButton(
            icon: LucideIcons.plus,
            onPressed: onPlus,
            tooltip: 'زيادة العدد',
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      icon: Icon(icon, size: 17),
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
