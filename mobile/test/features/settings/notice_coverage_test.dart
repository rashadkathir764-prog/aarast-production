import 'package:aarast_mobile/core/l10n/aarast_text.dart';
import 'package:aarast_mobile/features/settings/models/preference_coverage.dart';
import 'package:aarast_mobile/features/settings/utils/notice_coverage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/notification_settings_harness.dart';

// REFINEMENT_SPEC 2.5: each switch says what it silences from the server's
// one rule (`preferenceCoverage`), never from a list typed on the phone. The
// fixture is the server's own answer, kept by the backend's
// `reminder-schedule.test.ts`: a notice type added on the server lands here
// and fails the first test until it has words.

PreferenceCoverage _coverage() =>
    PreferenceCoverage.fromResponse(serverScheduleAnswer())!;

final _groom = NoticeReader.couple(
  ownsPlan: true,
  memberOfPlan: false,
  hasProviderProfile: false,
);
final _participant = NoticeReader.couple(
  ownsPlan: false,
  memberOfPlan: true,
  hasProviderProfile: false,
);

void main() {
  test('every notice type the server names has words on the phone', () {
    final coverage = _coverage();
    final types = [
      for (final types in coverage.switches.values) ...types,
      ...coverage.always,
    ];
    expect(types, isNotEmpty);
    final missing = [
      for (final type in types)
        if (noticeGroupsOf(type).isEmpty) type,
    ];
    expect(
      missing,
      isEmpty,
      reason:
          'give each a NoticeGroup in notice_coverage.dart and words in '
          'settings.arb',
    );
    for (final group in NoticeGroup.values) {
      expect(group.words(aarastText).trim(), isNotEmpty, reason: '$group');
    }
  });

  test('a switch\'s coverage is read whole, or not at all', () {
    final answer = serverScheduleAnswer();
    expect(PreferenceCoverage.fromResponse(answer), isNotNull);
    (answer['preferenceCoverage'] as Map<String, dynamic>)['switches'] = {
      'taskRemindersEnabled': ['TASK_ASSIGNED'],
    };
    expect(PreferenceCoverage.fromResponse(answer), isNull);
    expect(PreferenceCoverage.fromResponse({'reminderSchedule': {}}), isNull);
    // The table and the coverage are read apart: one missing leaves the other.
    final noCoverage = serverScheduleAnswer()..remove('preferenceCoverage');
    final schedule = NotificationSchedule.fromResponse(noCoverage);
    expect(schedule.coverage, isNull);
    expect(schedule.reminders, isNotNull);
  });

  test('the owner hears of loans, promised money and the budget; a '
      'participant only of payments', () {
    final money = _coverage().switches[NotificationSwitch.money]!;
    expect(
      coverageIncludesLine(money, _groom),
      'يشمل مواعيد الدفعات، وسداد السُّلف، والمال الموعود، وتجاوز الميزانية '
      'في بند.',
    );
    expect(coverageIncludesLine(money, _participant), 'يشمل مواعيد الدفعات.');
  });

  test('each switch says what it covers for the couple', () {
    final switches = _coverage().switches;
    expect(
      coverageIncludesLine(switches[NotificationSwitch.tasks]!, _groom),
      'يشمل إسناد مهمة إليك، وتذكيرات المهام، والعدّ إلى العرس.',
    );
    expect(
      coverageIncludesLine(
        switches[NotificationSwitch.bookingReminders]!,
        _groom,
      ),
      'يشمل الحجوزات المؤكَّدة.',
    );
    // The review's finding: «العروض والمحادثات» hid that it also silences
    // a booking cancelled.
    expect(
      coverageIncludesLine(switches[NotificationSwitch.providers]!, _groom),
      'يشمل عروض المزوّدين وردودهم، والمحادثات، وتغيّر الحجز أو إلغاءه، '
      'والردّ على تقييمك.',
    );
  });

  test('an account with a provider profile hears of its customers under the '
      'providers\' switch', () {
    final providers = _coverage().switches[NotificationSwitch.providers]!;
    final groomAndProvider = NoticeReader.couple(
      ownsPlan: true,
      memberOfPlan: false,
      hasProviderProfile: true,
    );
    expect(
      coverageIncludesLine(providers, groomAndProvider),
      endsWith('والردّ على تقييمك، وطلبات عملائك ورسائلهم.'),
    );
    expect(coverageIncludesLine(providers, _groom), isNot(contains('عملائك')));
    // The provider's own page says his side only.
    expect(
      coverageIncludesLine(providers, NoticeReader.provider),
      'يشمل طلبات العرض والحجز، ورسائل العملاء، وقبول عروضك أو رفضها، '
      'وتغيّر الحجوزات أو إلغاءها، والتقييمات الجديدة.',
    );
    // The tasks are never his.
    expect(
      coverageIncludesLine(
        _coverage().switches[NotificationSwitch.tasks]!,
        NoticeReader.provider,
      ),
      isNull,
    );
  });

  test('what always comes, by reader', () {
    final always = _coverage().always;
    expect(
      coverageAlwaysLine(always, _groom),
      'تصلك دائمًا: الدعوات وملخص ردود الضيوف.',
    );
    // The guests follow the plan's side, not the reader (LANGUAGE.md §3).
    expect(
      coverageAlwaysLine(
        always,
        NoticeReader.couple(
          ownsPlan: true,
          memberOfPlan: false,
          hasProviderProfile: false,
          bridePlan: true,
        ),
      ),
      'تصلك دائمًا: الدعوات وملخص ردود الضيفات.',
    );
    expect(
      coverageAlwaysLine(always, _participant),
      'تصلك دائمًا: الدعوات، وملخص ردود الضيوف، وتغيّر صلاحياتك في الخطة، '
      'وتوقّف الخطة أو عودتها.',
    );
    expect(
      coverageAlwaysLine(always, NoticeReader.provider),
      'تصلك دائمًا: قرارات الفريق على ملفك وصورك وتغيّر ظهورك المميّز.',
    );
  });

  test('a type this phone does not know is left out, never guessed', () {
    expect(noticeGroupsOf('SOMETHING_NEW'), isEmpty);
    expect(coverageIncludesLine(const ['SOMETHING_NEW'], _groom), isNull);
  });
}
