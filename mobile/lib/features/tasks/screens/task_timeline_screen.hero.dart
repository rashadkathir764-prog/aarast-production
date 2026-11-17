part of 'task_timeline_screen.dart';

// Rashad 2026-11-17: the tasks tab's hero, the home's own look and size
// (JourneyPlanHero). The open tasks as the big figure, how many are done
// under it, and the share done as the bar; the list under it names each
// one, so the hero names none. It follows the person chosen under it.

class _TasksHero extends StatelessWidget {
  const _TasksHero({required this.tasks, required this.today});

  /// What the screen shows («الكل», «لي» or one person).
  final List<WeddingTask> tasks;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final counted = [
      for (final task in tasks)
        if (task.status != 'CANCELLED') task,
    ];
    final total = counted.length;
    final done = counted.where((task) => task.isDone).length;
    final open = counted
        .where((task) => isOpenTaskGroup(taskGroupOf(task, today)))
        .length;
    // One and two are said in their word, without the figure, as the home
    // says «يومين على عرسك».
    final word = switch (open) {
      0 => 'ما فيه مهام باقية',
      1 => 'مهمة وحدة باقية',
      2 => 'مهمتين باقية',
      _ => arabicCountWord(
        open,
        one: 'مهمة باقية',
        two: 'مهمتين باقية',
        few: 'مهام باقية',
        many: 'مهمة باقية',
      ),
    };
    return JourneyPlanHero(
      key: const ValueKey('tasks-hero'),
      figure: open > 2 ? '$open' : null,
      title: word,
      subtitle: 'خلصت $done من ${_taskCountLabel(total)}',
      // The late ones, as the home's moment: saffron on the row.
      tag: switch (_lateTag(counted, today)) {
        final late? => JourneyHeroTag(
          key: const ValueKey('tasks-hero-late'),
          label: late,
        ),
        null => null,
      },
      semanticLabel:
          '${open == 0 ? word : '${_taskCountLabel(open)} باقية'}، خلصت $done من $total',
      footer: JourneyHeroBar(value: total == 0 ? 0 : done / total),
    );
  }
}
