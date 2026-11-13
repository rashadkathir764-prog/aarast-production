import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/plan_day.dart';

/// D65: the kinds of the wedding's events (b12). WEDDING is the wedding
/// itself, on the plan's date. The groom's nights are السمرة and المقيل,
/// the bride's الحفلة and النسمة (JOURNEY_PROFILE).
enum PlanEventType {
  wedding('WEDDING'),
  samra('SAMRA'),
  maqeel('MAQEEL'),
  hafla('HAFLA'),
  nashma('NASHMA'),
  aqd('AQD'),
  lunch('LUNCH'),
  dinner('DINNER'),
  custom('CUSTOM');

  const PlanEventType(this.wire);

  final String wire;

  static PlanEventType? fromWire(Object? value) {
    for (final type in values) {
      if (type.wire == value) return type;
    }
    return null;
  }

  /// Its name in the plan's words: the bride's wedding is «الزفة».
  String label(JourneyProfile profile) => switch (this) {
    wedding => profile.plan('الزفاف', 'الزفة'),
    samra => 'السمرة',
    maqeel => 'المقيل',
    hafla => 'الحفلة',
    nashma => 'النسمة',
    aqd => 'عقد القران',
    lunch => 'الغداء',
    dinner => 'العشاء',
    custom => 'مناسبة ثانية',
  };

  IconData get icon => switch (this) {
    wedding => LucideIcons.partyPopper,
    samra || hafla => LucideIcons.moon,
    maqeel => LucideIcons.leaf,
    nashma => LucideIcons.flame,
    aqd => LucideIcons.scrollText,
    lunch || dinner => LucideIcons.soup,
    custom => LucideIcons.calendarHeart,
  };

  /// b12's icon tile: the night lilac, the afternoon mint, the wedding the
  /// plan's own colour.
  (Color, Color) colors(JourneyAccent accent) => switch (this) {
    wedding => (accent.primary, accent.primarySoft),
    samra || hafla => (AarastV3Color.lilac, AarastV3Color.lilacSoft),
    maqeel || nashma => (AarastV3Color.mint, AarastV3Color.mintSoft),
    aqd => (AarastV3Color.cobalt, AarastV3Color.cobaltSoft),
    lunch || dinner => (AarastV3Color.amber, AarastV3Color.amberSoft),
    custom => (accent.primary, accent.primarySoft),
  };
}

/// b13's times of day, with «الظهر» (C8). A day's events are ordered by
/// when each starts; the hours are Sana'a's usual ones, so «الآن» on the
/// wedding day is close, not exact.
enum PlanEventSlot {
  duha('DUHA', 'الضحى', 9 * 60),
  dhuhr('DHUHR', 'الظهر', 12 * 60),
  afterDhuhr('AFTER_DHUHR', 'بعد الظهر', 13 * 60),
  afterAsr('AFTER_ASR', 'بعد العصر', 15 * 60 + 30),
  afterMaghrib('AFTER_MAGHRIB', 'بعد المغرب', 18 * 60),
  afterIsha('AFTER_ISHA', 'بعد العشاء', 19 * 60 + 30),
  exact('EXACT', 'ساعة محددة', 0);

  const PlanEventSlot(this.wire, this.label, this.startMinutes);

  final String wire;
  final String label;
  final int startMinutes;

  static PlanEventSlot? fromWire(Object? value) {
    for (final slot in values) {
      if (slot.wire == value) return slot;
    }
    return null;
  }
}

@immutable
class PlanEvent {
  const PlanEvent({
    required this.id,
    required this.type,
    this.title,
    this.date,
    this.slot,
    this.exactTime,
    this.placeLabel,
    this.responsibleName,
    this.note,
  });

  factory PlanEvent.fromJson(Map<String, dynamic> json) {
    String? text(Object? value) {
      final trimmed = value?.toString().trim() ?? '';
      return trimmed.isEmpty ? null : trimmed;
    }

    return PlanEvent(
      id: text(json['id']),
      type: PlanEventType.fromWire(json['type']) ?? PlanEventType.custom,
      title: text(json['title']),
      date: planDayFromJson(json['date']),
      slot: PlanEventSlot.fromWire(json['timeSlot']),
      exactTime: text(json['exactTime']),
      placeLabel: text(json['placeLabel']),
      responsibleName: text(json['responsibleName']),
      note: text(json['note']),
    );
  }

  /// Null for the wedding before anything about it was saved.
  final String? id;
  final PlanEventType type;
  final String? title;

  /// A calendar day; the wedding's is the plan's date.
  final DateTime? date;
  final PlanEventSlot? slot;

  /// `HH:mm`, with [PlanEventSlot.exact] only.
  final String? exactTime;
  final String? placeLabel;
  final String? responsibleName;

  /// b12's tag («القات عند صالح»).
  final String? note;

  bool get isMain => type == PlanEventType.wedding;

  /// Its name: what the couple called it, else its kind's.
  String name(JourneyProfile profile) => title ?? type.label(profile);

  /// «بعد العصر», or the exact hour «4:30 العصر» as «16:30».
  String? get timeLabel {
    final slot = this.slot;
    if (slot == null) return null;
    if (slot == PlanEventSlot.exact) return exactTime;
    return slot.label;
  }

  /// Minutes into the day it starts by; an event without a time is last.
  int get startMinutes {
    final slot = this.slot;
    if (slot == null) return 24 * 60;
    if (slot == PlanEventSlot.exact) {
      final parts = (exactTime ?? '').split(':');
      if (parts.length == 2) {
        return (int.tryParse(parts[0]) ?? 0) * 60 +
            (int.tryParse(parts[1]) ?? 0);
      }
      return 24 * 60;
    }
    return slot.startMinutes;
  }

  bool isOn(DateTime day) {
    final date = this.date;
    return date != null &&
        date.year == day.year &&
        date.month == day.month &&
        date.day == day.day;
  }
}

/// The plan's events as b12 reads them.
@immutable
class PlanEventsView {
  const PlanEventsView({
    required this.weddingPlanId,
    required this.canEdit,
    required this.items,
    required this.suggestions,
  });

  factory PlanEventsView.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final suggestions = json['suggestions'];
    return PlanEventsView(
      weddingPlanId: json['weddingPlanId']?.toString() ?? '',
      canEdit: json['canEdit'] == true,
      items: [
        if (items is List)
          for (final item in items)
            if (item is Map)
              PlanEvent.fromJson(Map<String, dynamic>.from(item)),
      ],
      suggestions: [
        if (suggestions is List)
          for (final value in suggestions) ?PlanEventType.fromWire(value),
      ],
    );
  }

  final String weddingPlanId;

  /// The owner, or a member who may edit the plan, on a plan not archived.
  final bool canEdit;

  /// By day (an undated one last), then by the time each starts.
  final List<PlanEvent> items;

  /// b12's «اقتراحات», «مناسبة ثانية» last.
  final List<PlanEventType> suggestions;

  /// b04/y12 «برنامج الأسبوع»: the events of the wedding week, in order.
  /// The week is the stage's (`WeddingPlanStage.finalWeek`, seven days or
  /// fewer): the program covers the day the moment opens (RA-MO-211).
  List<PlanEvent> weekOf(DateTime weddingDate) {
    final day = DateUtils.dateOnly(weddingDate);
    final first = day.subtract(const Duration(days: weddingWeekDays));
    return [
      for (final event in items)
        if (event.date case final date?
            when !date.isBefore(first) && !date.isAfter(day))
          event,
    ];
  }

  /// b05 «برنامج اليوم»: the events on the wedding day, by their time.
  List<PlanEvent> dayOf(DateTime weddingDate) {
    final day = DateUtils.dateOnly(weddingDate);
    return [
      for (final event in items)
        if (event.isOn(day)) event,
    ]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  }
}

/// Where a programme item of today stands at [now] (b05): done, now, next.
enum PlanEventMoment { done, now, next }

/// b05: the item that started last is «الآن», the ones before it are done,
/// the ones after it wait. Events without a time never lead.
List<PlanEventMoment> programMoments(List<PlanEvent> program, DateTime now) {
  final minutes = now.hour * 60 + now.minute;
  var current = -1;
  for (var index = 0; index < program.length; index++) {
    if (program[index].slot != null && program[index].startMinutes <= minutes) {
      current = index;
    }
  }
  return [
    for (var index = 0; index < program.length; index++)
      index < current
          ? PlanEventMoment.done
          : index == current
          ? PlanEventMoment.now
          : PlanEventMoment.next,
  ];
}
