part of 'task_details_screen.dart';

/// A reminder's day and time in the app's words.
String _reminderWords(DateTime at) {
  final local = at.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  // RA-MO-187: 12:30 at noon was said «12:30 المساء».
  final half = local.hour < 12
      ? 'الصبح'
      : local.hour < 15
      ? 'الظهر'
      : local.hour < 18
      ? 'العصر'
      : 'المساء';
  return '${formatArabicWeekdayDayMonth(local)} · $hour:$minute $half';
}

/// G36: the task's reminder, set, moved and taken off from the page.
extension _TaskReminder on _TaskDetailsScreenState {
  Future<void> _removeReminder(
    TaskTimelineProvider provider,
    WeddingTask task,
  ) async {
    final ok = await provider.setTaskReminder(widget.weddingPlanId, task, null);
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(context, 'انشال التذكير');
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'ما قدرنا نشيل التذكير',
      );
    }
  }

  /// A day and a time to be reminded; clearing it removes the reminder.
  Future<void> _pickReminder(
    TaskTimelineProvider provider,
    WeddingTask task,
  ) async {
    final current = task.reminderAt?.toLocal();
    final day = await pickTaskDate(context, initial: current ?? task.dueDate);
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final at = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    if (!at.isAfter(appNow())) {
      AarastToast.showError(
        context,
        context.say('اختر وقت جاي، مو فات', 'اختاري وقت جاي، مو فات'),
      );
      return;
    }
    final ok = await provider.setTaskReminder(widget.weddingPlanId, task, at);
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(context, 'بنذكّرك ${_reminderWords(at)}');
    } else {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'ما قدرنا نحفظ التذكير',
      );
    }
  }
}
