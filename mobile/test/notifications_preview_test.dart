// Visual preview for the notifications feed. Reconstructs _NotificationCard
// from notifications_screen.dart (private) across its tone system
// (quote / installment / sharing / overdue) and read/unread states, so the
// notification design can be inspected as a golden PNG without a backend.
//
// Regenerate with:
//   flutter test test/notifications_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';

import 'support/preview_fonts.dart';

class _Tone {
  const _Tone(this.icon, this.color, this.background);
  final IconData icon;
  final Color color;
  final Color background;
}

Widget _card({
  required String title,
  required String body,
  required String date,
  required _Tone tone,
  required bool unread,
  String? priority,
}) {
  return Builder(
    builder: (context) => AarastCard(
      color: unread ? tone.background : AppTheme.ivory,
      border: Border.all(
        color: unread
            ? tone.color.withValues(alpha: 0.1)
            : AppTheme.goldSoft.withAlpha(80),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(tone.icon, color: tone.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: tone.color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppTheme.burgundy,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  body,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (priority != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        priority,
                        style: const TextStyle(
                          color: AppTheme.burgundy,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const IconButton(
            onPressed: null,
            icon: Icon(Icons.archive_outlined, color: AppTheme.muted),
          ),
        ],
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, {required Size size}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: AppTheme.ivory,
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
                _card(
                  title: 'عرض سعر جديد',
                  body: 'قاعة اللؤلؤة أرسلت لك عرض سعر لطلبك.',
                  date: 'قبل ساعة',
                  tone: const _Tone(
                    Icons.request_quote_outlined,
                    AppTheme.burgundy,
                    AppTheme.burgundySoft,
                  ),
                  unread: true,
                  priority: 'مهم',
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'قسط قريب الاستحقاق',
                  body: 'لديك قسط بقيمة 100,000 ريال يستحق خلال 3 أيام.',
                  date: 'قبل 4 ساعات',
                  tone: const _Tone(
                    Icons.credit_card_rounded,
                    AppTheme.gold,
                    AppTheme.ivory,
                  ),
                  unread: false,
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'دعوة مشاركة جديدة',
                  body: 'انضم أحمد إلى خطة زفافك كمساهم.',
                  date: 'أمس',
                  tone: const _Tone(
                    Icons.group_add_outlined,
                    AppTheme.success,
                    AppTheme.successSoft,
                  ),
                  unread: true,
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'قسط متأخر',
                  body: 'تجاوز قسط القاعة موعد استحقاقه. يرجى المتابعة.',
                  date: 'أمس',
                  tone: const _Tone(
                    Icons.warning_amber_rounded,
                    AppTheme.danger,
                    AppTheme.burgundySoft,
                  ),
                  unread: true,
                  priority: 'عاجل',
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('notifications — tone feed (430)', (tester) async {
    await _pump(tester, size: const Size(430, 720));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/notifications_feed.png'),
    );
  });
}
