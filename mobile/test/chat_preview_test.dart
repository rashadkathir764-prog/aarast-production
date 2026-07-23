// Visual preview for the chat thread (quote conversation). Reconstructs the
// header + message bubbles + composer exactly as chat_screen.dart builds them
// (the sub-widgets there are private), so the messaging design language can be
// inspected as a golden PNG without a backend or realtime socket.
//
// Regenerate with:
//   flutter test test/chat_preview_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';

import 'support/preview_fonts.dart';

Widget _header() {
  return Builder(
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 8),
      child: Row(
        children: [
          const IconButton(
            onPressed: null,
            icon: Icon(LucideIcons.arrowRight, color: AppTheme.ink),
          ),
          const CircleAvatar(
            backgroundColor: AppTheme.burgundySoft,
            child: Icon(LucideIcons.store, color: AppTheme.burgundy),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'قاعة اللؤلؤة للأفراح',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'خطة زفاف رشا ومحمد · طلبان',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.moreVertical, color: AppTheme.ink),
        ],
      ),
    ),
  );
}

Widget _bubble({required String body, required bool mine, bool read = false}) {
  return Align(
    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 320),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: mine ? AppTheme.burgundy : AppTheme.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
        border: mine ? null : Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            body,
            style: TextStyle(
              color: mine ? Colors.white : AppTheme.ink,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (read) ...[
            const SizedBox(height: 5),
            Text(
              'تمت القراءة',
              style: TextStyle(
                color: mine ? Colors.white70 : AppTheme.muted,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget _eventCard(String label, IconData icon) {
  return Align(
    child: Container(
      constraints: const BoxConstraints(maxWidth: 360),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppTheme.burgundy),
          const SizedBox(width: 9),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(LucideIcons.chevronLeft, size: 17, color: AppTheme.muted),
        ],
      ),
    ),
  );
}

Widget _composer() {
  return Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    decoration: const BoxDecoration(
      color: AppTheme.surface,
      border: Border(top: BorderSide(color: AppTheme.border)),
    ),
    child: Row(
      children: [
        const IconButton(
          onPressed: null,
          icon: Icon(LucideIcons.imagePlus, color: AppTheme.ink),
        ),
        Expanded(
          child: TextField(
            enabled: false,
            decoration: const InputDecoration(
              hintText: 'اكتب رسالتك...',
              counterText: '',
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(onPressed: () {}, icon: const Icon(LucideIcons.send)),
      ],
    ),
  );
}

Widget _conversationTile({
  required String name,
  required String contextLabel,
  required String preview,
  required int unread,
  bool providerJoined = true,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: AarastCard(
      child: Row(
        children: [
          const CircleAvatar(
            radius: 27,
            backgroundColor: AppTheme.burgundySoft,
            child: Icon(LucideIcons.store, color: AppTheme.burgundy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  contextLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  providerJoined ? preview : 'المورد لم ينضم بعد',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: providerJoined ? AppTheme.muted : AppTheme.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (unread > 0)
            Container(
              constraints: const BoxConstraints(minWidth: 24),
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: AppTheme.burgundy,
                borderRadius: BorderRadius.circular(999),
              ),
              alignment: Alignment.center,
              child: Text(
                '$unread',
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            )
          else
            const Icon(LucideIcons.chevronLeft, color: AppTheme.muted),
        ],
      ),
    ),
  );
}

Future<void> _pumpList(WidgetTester tester, {required Size size}) async {
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
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                const AarastSectionHeader(
                  title: 'الرسائل',
                  subtitle: 'محادثة واحدة مع كل مورد داخل الخطة.',
                  icon: LucideIcons.messagesSquare,
                ),
                const SizedBox(height: 18),
                _conversationTile(
                  name: 'قاعة اللؤلؤة للأفراح',
                  contextLabel: 'خطة زفاف رشا ومحمد · طلبان',
                  preview: 'أرسلت لك عرض السعر التفصيلي في الطلب.',
                  unread: 12,
                ),
                _conversationTile(
                  name: 'استوديو نجمة للتصوير',
                  contextLabel: 'خطة زفاف رشا ومحمد · طلب واحد',
                  preview: 'شكراً، سنؤكد الموعد قريباً.',
                  unread: 3,
                ),
                _conversationTile(
                  name: 'ضيافة الأصالة',
                  contextLabel: 'طلب مستقل عن الخطة · طلب واحد',
                  preview: 'بانتظار انضمام المورد',
                  unread: 0,
                  providerJoined: false,
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
            body: Column(
              children: [
                _header(),
                const Divider(height: 1, color: AppTheme.border),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                    children: [
                      _bubble(
                        body: 'السلام عليكم، هل القاعة متاحة يوم 30 أغسطس؟',
                        mine: true,
                        read: true,
                      ),
                      _eventCard('وصل عرض سعر جديد', LucideIcons.mailCheck),
                      _bubble(
                        body:
                            'وعليكم السلام، نعم متاحة. تتسع لـ 400 ضيف مع تنسيق كامل للإضاءة.',
                        mine: false,
                      ),
                      _bubble(
                        body: 'ممتاز. ما هي الباقة التي تنصحون بها للعدد هذا؟',
                        mine: true,
                        read: true,
                      ),
                      _bubble(
                        body:
                            'أرسلت لك عرض السعر التفصيلي في الطلب. يشمل القاعة والضيافة والتنسيق.',
                        mine: false,
                      ),
                    ],
                  ),
                ),
                _composer(),
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

  testWidgets('chat — quote conversation thread (420)', (tester) async {
    await _pump(tester, size: const Size(420, 820));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/chat_thread.png'),
    );
  });

  testWidgets('chat — conversation list with unread pills (420)', (
    tester,
  ) async {
    await _pumpList(tester, size: const Size(420, 620));
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/chat_conversations.png'),
    );
  });
}
