import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/hijri_date.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../data/plan_events_api.dart';
import '../models/plan_event.dart';
import '../providers/plan_events_provider.dart';

/// b13 «تعديل مناسبة»: the day (and its Hijri day), the time, the place and
/// who is in charge; a new event opens it from b12's suggestions. The
/// wedding's own day is the plan's date and moves with «أجّل العرس».
Future<void> showPlanEventSheet(
  BuildContext context, {
  required String weddingPlanId,
  required PlanEventsProvider provider,
  PlanEvent? event,
  PlanEventType? type,
  VoidCallback? onMoveDay,
}) {
  return showJourneySheet<void>(
    context: context,
    builder: (_) => PlanEventSheet(
      weddingPlanId: weddingPlanId,
      provider: provider,
      event: event,
      type: type ?? event?.type ?? PlanEventType.custom,
      onMoveDay: onMoveDay,
    ),
  );
}

/// «الأربعاء 20».
String _weekdayDay(DateTime date) => '${formatArabicWeekday(date)} ${date.day}';

class PlanEventSheet extends StatefulWidget {
  const PlanEventSheet({
    required this.weddingPlanId,
    required this.provider,
    required this.type,
    this.event,
    this.onMoveDay,
    super.key,
  });

  final String weddingPlanId;
  final PlanEventsProvider provider;
  final PlanEventType type;

  /// Null for a new event.
  final PlanEvent? event;

  /// Called once this sheet closes, for the wedding's own day to move.
  final VoidCallback? onMoveDay;

  @override
  State<PlanEventSheet> createState() => _PlanEventSheetState();
}

class _PlanEventSheetState extends State<PlanEventSheet> {
  late final _title = TextEditingController(text: widget.event?.title ?? '');
  late final _place = TextEditingController(
    text: widget.event?.placeLabel ?? '',
  );
  late final _person = TextEditingController(
    text: widget.event?.responsibleName ?? '',
  );
  late final _note = TextEditingController(text: widget.event?.note ?? '');
  late final _mapUrl = TextEditingController(text: widget.event?.mapUrl ?? '');
  late final _address = TextEditingController(
    text: widget.event?.address ?? '',
  );
  String? _mapError;
  late DateTime? _date = widget.event?.date;
  late PlanEventSlot? _slot = widget.event?.slot;
  late String? _exactTime = widget.event?.exactTime;
  bool _saving = false;
  String? _error;

  bool get _isMain => widget.type == PlanEventType.wedding;
  bool get _isCustom => widget.type == PlanEventType.custom;

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _person.dispose();
    _note.dispose();
    _mapUrl.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    releaseFieldFocus();
    final today = DateUtils.dateOnly(appNow());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 10),
      locale: const Locale('ar'),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  void _moveDay() {
    Navigator.of(context).pop();
    widget.onMoveDay!();
  }

  Future<void> _pickSlot(PlanEventSlot slot) async {
    if (slot != PlanEventSlot.exact) {
      setState(() => _slot = slot);
      return;
    }
    releaseFieldFocus();
    final parts = (_exactTime ?? '').split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: parts.length == 2
          ? TimeOfDay(
              hour: int.tryParse(parts[0]) ?? 16,
              minute: int.tryParse(parts[1]) ?? 0,
            )
          : const TimeOfDay(hour: 16, minute: 0),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _slot = PlanEventSlot.exact;
      _exactTime =
          '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _save() async {
    if (_isCustom && _title.text.trim().isEmpty) {
      setState(
        () => _error = context.say('اكتب اسم المناسبة', 'اكتبي اسم المناسبة'),
      );
      return;
    }
    // The server keeps a whole https link only; said here, under the field.
    final map = _mapUrl.text.trim();
    if (map.isNotEmpty && !(Uri.tryParse(map)?.isScheme('https') ?? false)) {
      setState(
        () => _mapError = context.say(
          'الرابط لازم يبدأ بـ https://. انسخه من «مشاركة» في تطبيق الخرائط.',
          'الرابط لازم يبدأ بـ https://. انسخيه من «مشاركة» في تطبيق الخرائط.',
        ),
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _mapError = null;
    });
    try {
      await widget.provider.save(
        widget.weddingPlanId,
        event: widget.event,
        type: widget.type,
        draft: PlanEventDraft(
          title: _isCustom ? _title.text : widget.event?.title,
          date: _date,
          slot: _slot,
          exactTime: _exactTime,
          placeLabel: _place.text,
          responsibleName: _person.text,
          note: _note.text,
          mapUrl: _mapUrl.text,
          address: _address.text,
          setsPlaceLinks: true,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } catch (_) {
      // RA-MO-208: a failure that is not the server's answer (the phone's
      // copy could not be written) left the spinner turning for good.
      if (mounted) {
        setState(() {
          _saving = false;
          _error = context.say(
            'ما انحفظت المناسبة. جرّب مرة ثانية.',
            'ما انحفظت المناسبة. جرّبي مرة ثانية.',
          );
        });
      }
    }
  }

  /// RA-MO-190: «احذف المناسبة» deleted at the first tap, with its place,
  /// its person in charge and its note, and nothing to take it back. The
  /// first tap asks; the second deletes.
  bool _askedToRemove = false;

  Future<void> _remove() async {
    final event = widget.event;
    if (event == null) return;
    if (!_askedToRemove) {
      setState(() => _askedToRemove = true);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.provider.remove(widget.weddingPlanId, event);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } catch (_) {
      // RA-MO-208: as for saving.
      if (mounted) {
        setState(() {
          _saving = false;
          _error = context.say(
            'ما انحذفت المناسبة. جرّب مرة ثانية.',
            'ما انحذفت المناسبة. جرّبي مرة ثانية.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.journeyProfile;
    final name = _isCustom
        ? (_title.text.trim().isEmpty ? 'مناسبة ثانية' : _title.text.trim())
        : (widget.event?.name(profile) ?? widget.type.label(profile));
    final date = _date;
    final hijri = date == null ? null : HijriDate.fromGregorian(date);
    return JourneySheetBody(
      title: name,
      // D12 of the closing round: the line said the occasion shows in the
      // week's program and on the day, which only the last week's do; it now
      // says what reaches the guests. D14: the guests are the plan's side.
      subtitle: profile.plan(
        'موعدها ومكانها يوصلون ضيوفها مع الدعوة',
        'موعدها ومكانها يوصلون ضيفاتها مع الدعوة',
      ),
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error case final error?) ...[
            JourneyNote(
              text: error,
              icon: LucideIcons.alertCircle,
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
            ),
            const SizedBox(height: AarastV3Space.x2),
          ],
          JourneyButton(
            key: const ValueKey('plan-event-save'),
            label: 'حفظ',
            expand: true,
            large: true,
            loading: _saving,
            onPressed: _saving ? null : _save,
          ),
          if (widget.event?.id != null && !_isMain) ...[
            const SizedBox(height: AarastV3Space.x1),
            JourneyTextAction(
              key: const ValueKey('plan-event-remove'),
              label: _askedToRemove
                  ? context.say(
                      'تنحذف بمكانها وملاحظتها. اضغط ثاني للتأكيد',
                      'تنحذف بمكانها وملاحظتها. اضغطي ثاني للتأكيد',
                    )
                  : context.say('احذف المناسبة', 'احذفي المناسبة'),
              icon: LucideIcons.trash2,
              color: AarastV3Color.danger,
              onPressed: _saving ? null : _remove,
            ),
          ],
        ],
      ),
      children: [
        if (_isCustom) ...[
          JourneyTextField(
            label: 'اسم المناسبة',
            controller: _title,
            hint: 'مثلًا الحناء',
            maxLength: 60,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AarastV3Space.x2),
        ],
        Row(
          children: [
            Expanded(
              child: _isMain
                  ? JourneyPickerField(
                      key: const ValueKey('plan-event-main-day'),
                      label: 'اليوم',
                      icon: LucideIcons.calendar,
                      value: date == null ? null : _weekdayDay(date),
                      placeholder: 'موعد العرس',
                      // RA-MO-196: a plan with no day yet sets its first
                      // in «بيانات الخطة»; «أجّل العرس» moves a day it has.
                      helper: date == null
                          ? 'يتحدد من «بيانات الخطة»'
                          : 'يتغير من «أجّل العرس»',
                      onTap: widget.onMoveDay == null ? null : _moveDay,
                    )
                  : JourneyPickerField(
                      key: const ValueKey('plan-event-day'),
                      label: 'اليوم',
                      icon: LucideIcons.calendar,
                      value: date == null ? null : _weekdayDay(date),
                      placeholder: context.say('اختر اليوم', 'اختاري اليوم'),
                      onTap: _saving ? null : _pickDay,
                    ),
            ),
            const SizedBox(width: AarastV3Space.x2),
            Expanded(
              child: JourneyPickerField(
                label: 'الهجري',
                icon: LucideIcons.moon,
                value: hijri?.dayAndMonth,
                placeholder: '—',
                onTap: null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x4),
        Text(
          'الوقت',
          style: JourneyType.of(
            JourneyType.bodySmall,
            weight: JourneyType.bold,
            color: AarastV3Color.textMuted,
          ),
        ),
        const SizedBox(height: AarastV3Space.x2),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final slot in PlanEventSlot.values)
              JourneyChip(
                key: ValueKey('plan-event-slot-${slot.wire}'),
                label:
                    slot == PlanEventSlot.exact &&
                        _slot == PlanEventSlot.exact &&
                        _exactTime != null
                    ? _exactTime!
                    : slot.label,
                icon: slot == PlanEventSlot.exact ? LucideIcons.clock : null,
                selected: _slot == slot,
                onTap: _saving ? null : () => _pickSlot(slot),
              ),
          ],
        ),
        const SizedBox(height: AarastV3Space.x4),
        JourneyTextField(
          key: const ValueKey('event-place'),
          label: 'المكان',
          controller: _place,
          icon: LucideIcons.mapPin,
          hint: 'بيت الوالد · الحصبة',
          maxLength: 120,
        ),
        const SizedBox(height: AarastV3Space.x2),
        // D116: each occasion's own map link and address reach its guests,
        // in their message and on their page.
        JourneyTextField(
          key: const ValueKey('event-map-url'),
          label: 'رابط الموقع على الخريطة (اختياري)',
          hint: 'https://maps.app.goo.gl/…',
          helper: _mapError == null
              ? 'من «مشاركة» في تطبيق الخرائط. يوصل الضيوف مع الدعوة.'
              : null,
          errorText: _mapError,
          controller: _mapUrl,
          icon: LucideIcons.map,
          keyboardType: TextInputType.url,
          textDirection: TextDirection.ltr,
          maxLength: 500,
        ),
        const SizedBox(height: AarastV3Space.x2),
        JourneyTextField(
          key: const ValueKey('event-address'),
          label: 'العنوان (اختياري)',
          hint: 'شارع تعز، جوار جامع النور',
          controller: _address,
          icon: LucideIcons.navigation,
          maxLength: 160,
        ),
        const SizedBox(height: AarastV3Space.x2),
        JourneyTextField(
          label: 'مين مسؤول؟',
          controller: _person,
          icon: LucideIcons.user,
          hint: 'صالح أخوي',
          maxLength: 60,
        ),
        const SizedBox(height: AarastV3Space.x2),
        JourneyTextField(
          label: 'ملاحظة',
          controller: _note,
          icon: LucideIcons.stickyNote,
          hint: 'القات عند صالح',
          maxLength: 120,
        ),
      ],
    );
  }
}
