import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_duplicate_utils.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../shared/widgets/contact_phone_field.dart';
import '../models/guest.dart';
import '../utils/guest_display.dart';

/// e06 «ضيف جديد» and editing a guest: the name, an optional number, the
/// family (a new one made right here), how many come with them, and, under
/// «تفاصيل أكثر», the side, the answer and a note. Presentational: the
/// caller saves the result.
class GuestFormSheet extends StatefulWidget {
  const GuestFormSheet({
    required this.existingGuests,
    required this.groups,
    required this.blockDuplicatePhone,
    this.guest,
    this.draftScope,
    this.onCreateGroup,
    super.key,
  });

  final Guest? guest;
  final List<Guest> existingGuests;
  final List<GuestGroup> groups;
  final bool blockDuplicatePhone;
  final String? draftScope;

  /// Makes a group by name and returns its id; null hides «جديدة» (a
  /// phone-only plan keeps no groups).
  final Future<String?> Function(String name)? onCreateGroup;

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
  late List<GuestGroup> _groups = List.of(widget.groups);
  late bool _showMore;
  String? _nameError;
  String? _phoneError;
  bool _creatingGroup = false;
  AarastFormDraftCoordinator? _draft;
  bool _didConfigureDraft = false;
  bool _restoringDraft = false;

  bool get _editing => widget.guest != null;

  @override
  void initState() {
    super.initState();
    final guest = widget.guest;
    _nameController = TextEditingController(text: guest?.name ?? '');
    _phoneController = TextEditingController(text: guest?.phone ?? '');
    _notesController = TextEditingController(text: guest?.notes ?? '');
    for (final controller in [
      _nameController,
      _phoneController,
      _notesController,
    ]) {
      controller.addListener(_handleChanged);
    }
    _side = _sideValues.contains(guest?.side) ? guest!.side : 'OTHER';
    _status = guest?.status ?? 'INVITED';
    _groupId = widget.groups.any((group) => group.id == guest?.groupId)
        ? guest?.groupId
        : null;
    _seatsCount = guest?.seatsCount ?? 1;
    _companionsCount = guest?.companionsCount ?? 0;
    _showMore =
        guest != null &&
        (guest.side != 'OTHER' ||
            guest.status != 'INVITED' ||
            (guest.notes ?? '').trim().isNotEmpty);
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
    for (final controller in [
      _nameController,
      _phoneController,
      _notesController,
    ]) {
      controller
        ..removeListener(_handleChanged)
        ..dispose();
    }
    _draft?.dispose();
    super.dispose();
  }

  void _handleChanged() {
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
      if (_sideValues.contains(side)) _side = side!;
      if (_statusValues.contains(status)) _status = status!;
      if (_groups.any((group) => group.id == groupId)) _groupId = groupId;
      _companionsCount = _draftInt(
        data['companionsCount'],
        _companionsCount,
      ).clamp(0, 20);
      _seatsCount = _draftInt(
        data['seatsCount'],
        _seatsCount,
      ).clamp(_companionsCount + 1, 21);
    });
    _restoringDraft = false;
  }

  int _draftInt(Object? value, int fallback) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? fallback;

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

  /// «كم معه؟»: the seats follow, never fewer than the guest and them.
  void _setCompanions(int companions) => _mutate(() {
    _companionsCount = companions;
    _seatsCount = companions + 1;
  });

  Guest? get _duplicatePhoneGuest => ContactDuplicateUtils.findByPhone(
    widget.existingGuests,
    candidatePhone: _phoneController.text,
    phoneOf: (guest) => guest.phone,
    exclude: (guest) => guest.id == widget.guest?.id,
  );

  bool get _hasSoftNameDuplicate {
    if (_phoneController.text.trim().isNotEmpty) return false;
    return widget.existingGuests.any(
      (guest) =>
          guest.id != widget.guest?.id &&
          ContactDuplicateUtils.sameName(guest.name, _nameController.text),
    );
  }

  Future<void> _createGroup() async {
    final create = widget.onCreateGroup;
    if (create == null) return;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewGroupDialog(),
    );
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || !mounted) return;
    setState(() => _creatingGroup = true);
    final id = await create(trimmed);
    if (!mounted) return;
    setState(() {
      _creatingGroup = false;
      if (id != null) {
        _groups = [
          ..._groups,
          GuestGroup(id: id, weddingPlanId: '', name: trimmed),
        ];
        _groupId = id;
      }
    });
    _scheduleDraft();
  }

  void _submit({bool addAnother = false}) {
    final name = _nameController.text.trim();
    final phone = PhoneNumberUtils.analyze(_phoneController.text);
    final duplicate =
        widget.blockDuplicatePhone && _duplicatePhoneGuest != null;
    setState(() {
      _nameError = name.isEmpty ? 'اكتب اسمه' : null;
      _phoneError = phone.isInvalid
          ? phone.message ?? PhoneNumberUtils.invalidMessage
          : duplicate
          ? 'رقمه عندك لـ${_duplicatePhoneGuest!.name}'
          : null;
    });
    if (_nameError != null || _phoneError != null) return;
    Navigator.of(context).pop(
      GuestFormResult(
        name: name,
        phone: PhoneNumberUtils.normalizeOptional(_phoneController.text),
        groupId: _groupId,
        side: _side,
        status: _status,
        seatsCount: _seatsCount,
        companionsCount: _companionsCount,
        notes: _notesController.text,
        addAnother: addAnother,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final duplicate = _duplicatePhoneGuest;
    return JourneySheetBody(
      title: _editing ? 'تعديل ضيف' : 'ضيف جديد',
      children: [
        if (_draft != null) ...[
          AarastV3DraftStatusLine(status: _draft!.status),
          const SizedBox(height: 8),
        ],
        JourneyTextField(
          key: const ValueKey('guest-form-name'),
          label: 'الاسم',
          hint: 'مثلًا: خالد الحمدي',
          controller: _nameController,
          icon: LucideIcons.user,
          autofocus: !_editing,
          errorText: _nameError,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 10),
        ContactPhoneField(
          key: const ValueKey('guest-form-phone'),
          nameController: _nameController,
          phoneController: _phoneController,
          label: 'رقم الجوال (اختياري)',
          duplicateMessage: duplicate == null
              ? null
              : 'رقمه عندك لـ${duplicate.name}',
          duplicateIsBlocking: widget.blockDuplicatePhone,
          onDraftChanged: (_) {
            if (!mounted) return;
            setState(() => _phoneError = null);
            _scheduleDraft();
          },
        ),
        if (_phoneError != null)
          Text(
            _phoneError!,
            key: const ValueKey('guest-form-phone-error'),
            style: JourneyType.of(
              JourneyType.small,
              weight: JourneyType.bold,
              color: AarastV3Color.danger,
            ),
          ),
        if (_hasSoftNameDuplicate)
          Text(
            'فيه اسم مشابه بدون رقم؛ كمّل لو هو شخص ثاني.',
            style: JourneyType.of(
              JourneyType.small,
              weight: JourneyType.bold,
              color: AarastV3Color.brandAccentStrong,
            ),
          ),
        if (_groups.isNotEmpty || widget.onCreateGroup != null) ...[
          _label('العائلة'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final group in _groups)
                JourneyChip(
                  key: ValueKey('guest-form-group-${group.id}'),
                  label: group.name,
                  selected: _groupId == group.id,
                  selectedColor: AarastV3Color.lilac,
                  onTap: () => _mutate(
                    () => _groupId = _groupId == group.id ? null : group.id,
                  ),
                ),
              if (widget.onCreateGroup != null)
                JourneyChip(
                  key: const ValueKey('guest-form-group-new'),
                  label: _creatingGroup ? 'نحفظها…' : 'جديدة',
                  icon: LucideIcons.plus,
                  selected: false,
                  onTap: _creatingGroup ? null : _createGroup,
                ),
            ],
          ),
        ],
        _label('كم معه؟'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final count in const [0, 1, 2, 3])
              JourneyChip(
                key: ValueKey('guest-form-companions-$count'),
                label: count == 0
                    ? 'لحاله'
                    : PhoneNumberUtils.isolateLtr('+$count'),
                selected: _companionsCount == count,
                selectedColor: AarastV3Color.lilac,
                onTap: () => _setCompanions(count),
              ),
            JourneyChip(
              key: const ValueKey('guest-form-companions-more'),
              label: _companionsCount > 3
                  ? PhoneNumberUtils.isolateLtr('+$_companionsCount')
                  : 'أكثر',
              selected: _companionsCount > 3,
              selectedColor: AarastV3Color.lilac,
              onTap: _companionsCount < 20
                  ? () => _setCompanions(
                      _companionsCount < 4 ? 4 : _companionsCount + 1,
                    )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: JourneyTextAction(
            key: const ValueKey('guest-form-more'),
            label: _showMore ? 'أقل' : 'تفاصيل أكثر',
            icon: _showMore ? LucideIcons.chevronUp : LucideIcons.chevronDown,
            color: AarastV3Color.lilac,
            onPressed: () => setState(() => _showMore = !_showMore),
          ),
        ),
        if (_showMore) ...[
          _label('من أي طرف؟'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final side in _sideValues)
                JourneyChip(
                  key: ValueKey('guest-form-side-$side'),
                  label: guestSideLabel(side),
                  selected: _side == side,
                  selectedColor: AarastV3Color.lilac,
                  onTap: () => _mutate(() => _side = side),
                ),
            ],
          ),
          _label('ردّه'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (status, label) in const [
                ('INVITED', 'ما ردّ'),
                ('CONFIRMED', 'أكّد'),
                ('DECLINED', 'اعتذر'),
              ])
                JourneyChip(
                  key: ValueKey('guest-form-status-$status'),
                  label: label,
                  selected:
                      _status == status ||
                      (status == 'INVITED' && _status == 'PENDING'),
                  selectedColor: AarastV3Color.lilac,
                  onTap: () => _mutate(() => _status = status),
                ),
            ],
          ),
          const SizedBox(height: 12),
          JourneyTextField(
            key: const ValueKey('guest-form-notes'),
            label: 'ملاحظة',
            controller: _notesController,
            maxLength: 500,
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: JourneyButton(
                key: const ValueKey('guest-form-save'),
                label: _editing ? 'حفظ التعديل' : 'حفظ',
                background: AarastV3Color.lilac,
                expand: true,
                large: true,
                onPressed: _submit,
              ),
            ),
            if (!_editing) ...[
              const SizedBox(width: 10),
              JourneyButton(
                key: const ValueKey('guest-form-save-next'),
                label: 'حفظ وأضف التالي',
                background: AarastV3Color.lilacSoft,
                foreground: AarastV3Color.lilac,
                large: true,
                onPressed: () => _submit(addAnother: true),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 8),
    child: Text(
      text,
      style: JourneyType.of(
        JourneyType.small,
        weight: JourneyType.bold,
        color: AarastV3Color.textMuted,
      ),
    ),
  );
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
    this.addAnother = false,
  });

  final String name;
  final String? phone;
  final String? groupId;
  final String side;
  final String status;
  final int seatsCount;
  final int companionsCount;
  final String? notes;

  /// «حفظ وأضف التالي»: open the form again once this one is saved.
  final bool addAnother;
}

/// Owns its controller so it is disposed after the dialog route is gone.
class _NewGroupDialog extends StatefulWidget {
  const _NewGroupDialog();

  @override
  State<_NewGroupDialog> createState() => _NewGroupDialogState();
}

class _NewGroupDialogState extends State<_NewGroupDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AarastDialog(
      title: const Text('عائلة جديدة'),
      content: TextField(
        key: const ValueKey('guest-form-group-name'),
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'مثلًا: آل السقاف'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('رجوع'),
        ),
        FilledButton(
          key: const ValueKey('guest-form-group-create'),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('أضفها'),
        ),
      ],
    );
  }
}

const _sideValues = ['GROOM', 'BRIDE', 'OTHER'];
const _statusValues = ['INVITED', 'CONFIRMED', 'PENDING', 'DECLINED'];
