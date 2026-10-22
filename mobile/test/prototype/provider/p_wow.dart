// Provider journey prototype: the touches that make اعّرست worth opening
// every day. Each one solves a real Yemeni market pain: late arrival, the
// night's logistics, slow replies, empty nights, money owed, and showing
// your work where people already are (WhatsApp status, TikTok).
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import 'pkit.dart';

/// The night's run sheet: every booking, who goes, where, who to call, and
/// «في الطريق» / «وصلنا» that the couple sees live.
Widget p44RunSheet() {
  Widget job(String time, String t, String sub, String team, String who, Widget end, {bool now = false}) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: now ? Border.all(color: P.c, width: 2) : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text(time, style: tx(15, w: bold, c: P.c, f: fPlex)),
          const SizedBox(width: 10),
          Expanded(child: Text(t, style: tx(15.5, w: bold))),
          end,
        ]),
        Text(sub, style: tx(13, c: K.muted)),
        gap(6),
        Row(children: [
          const Icon(LucideIcons.users, size: 15, color: K.muted),
          const SizedBox(width: 6),
          Text(team, style: tx(13, w: bold)),
          const Spacer(),
          const Icon(LucideIcons.phone, size: 15, color: K.muted),
          const SizedBox(width: 6),
          Text(who, style: tx(13, w: bold)),
        ]),
      ],
    ),
  );
  return pPhone(
    tab: PTab.home,
    action: pBtn('وصلنا قاعة سبأ', icon: LucideIcons.mapPin),
    children: [
      pTop('شغل الليلة', 'الخميس 21 يناير · 4 أعراس'),
      job('4:00', 'مقيل عرس ناصر', 'بيت آل الشامي · السبعين', 'فريق 3', 'أبو ناصر', tag('خلص', K.green, K.greenSoft)),
      job('7:30', 'زفة محمد الحمدي', 'قاعة سبأ · القاعة الكبرى · من دخول العريس', 'فريق 2 · ياسر', 'أبو فهد (القاعة)', tag('في الطريق', K.saffronInk, K.saffronSoft), now: true),
      job('8:00', 'زفة عادل الريمي', 'قاعة الماسة · حدة', 'فريق 1 · سامي', 'عادل', tag('وصلوا', K.green, K.greenSoft)),
      job('8:00', 'حفلة سلمى', 'صالة الياسمين · التصوير ممنوع للجوالات', 'فريق النساء · أم ريم', 'أم سلمى', tag('جاهزين', P.c, P.soft)),
      gap(4),
      pNote('العريس يشوف «في الطريق» و«وصلنا» أول بأول، بدون ما يتصل.', i: LucideIcons.radio),
    ],
  );
}

/// One tap from a request to a priced offer, built from a package.
Widget p45QuickOffer() => pPhone(
  sheet: sheet(
    title: 'رد سريع',
    sub: 'محمد الحمدي · الزفة · الخميس 21 يناير',
    children: [
      for (final o in const [
        ('صور فقط', '350,000', 'آخر 5 عرسان مثله اختاروا هذي 1 مرة'),
        ('صور وفيديو', '550,000', 'آخر 5 عرسان مثله اختاروا هذي 4 مرات'),
      ])
        pOption('${o.$1} · ${o.$2}', sub: o.$3, on: o.$1 == 'صور وفيديو'),
      gap(4),
      Row(children: [
        Expanded(child: Text('ليلة الخميس في الموسم', style: tx(14, c: K.muted))),
        Text('سعر الموسم 620,000؟', style: tx(14, w: bold, c: K.saffronInk)),
      ]),
      gap(12),
      Row(children: [
        Expanded(child: pBtn('أرسل', icon: LucideIcons.send, v: 15, fs: 16)),
        const SizedBox(width: 10),
        btn('', bg: P.soft, fg: P.c, icon: LucideIcons.mic, v: 15),
      ]),
      gap(8),
      Text('أو سجّل فويس يوصل مع العرض. العرسان يحبون يسمعون صوتك.', style: tx(12.5, c: K.muted)),
    ],
  ),
  children: [pTop('الطلبات', '')],
);

/// Empty nights next week: offer them to couples who still need that date.
Widget p46EmptyNights() => pPhone(
  tab: PTab.calendar,
  action: pBtn('اعرضها', icon: LucideIcons.megaphone),
  children: [
    subHeader('ليالي فاضية قريبة'),
    Box(
      child: Column(
        children: [
          for (final d in const [('الأربعاء 27 يناير', 'باقي 3 فرق', true), ('الخميس 28 يناير', 'باقي فريق', true), ('الأربعاء 3 فبراير', 'باقي 4 فرق', false)])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Icon(d.$3 ? LucideIcons.checkSquare : LucideIcons.square, color: d.$3 ? P.c : K.faint),
                const SizedBox(width: 10),
                Expanded(child: Text(d.$1, style: tx(15, w: bold))),
                Text(d.$2, style: tx(13, c: K.muted)),
              ]),
            ),
        ],
      ),
    ),
    gap(12),
    pField('خصم لهذي الليالي (اختياري)', '15%', suffix: 'من الباقات'),
    gap(12),
    Box(
      pad: const EdgeInsets.all(14),
      child: Row(children: [
        const Icon(LucideIcons.users, color: P.c),
        const SizedBox(width: 10),
        Expanded(child: Text('9 عرسان في صنعاء عرسهم في هذي الليالي وما حجزوا مصور', style: tx(14, w: bold, h: 1.45))),
      ]),
    ),
    gap(10),
    pNote('يوصلهم في «اقتراحات لعرسك»، مرة وحدة، بدون إزعاج. ما نعطيك أسماءهم.', i: LucideIcons.lock),
  ],
);

/// Money the provider is owed, from the bookings he confirmed.
Widget p47Income() {
  Widget row(String n, String sub, String v, Widget t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(n, style: tx(15, w: bold)), Text(sub, style: tx(12.5, c: K.muted))])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(v, style: tx(15, w: bold)), t]),
    ]),
  );
  return pPhone(
    tab: PTab.me,
    children: [
      subHeader('حساباتك', sub: 'يناير · من حجوزاتك المؤكدة'),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: P.c, borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('وصلك', style: tx(13, c: Colors.white70)),
            Text('1.1 مليون', style: tx(24, w: bold, c: Colors.white)),
          ])),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('باقي لك', style: tx(13, c: Colors.white70)),
            Text('2.6 مليون', style: tx(24, w: bold, c: K.saffron)),
          ])),
        ]),
      ),
      gap(6),
      Text('ريال صنعاء. والدولار والسعودي لحالهم تحت.', style: tx(12.5, c: K.muted)),
      sectionTitle('يستحق هذا الأسبوع'),
      whiteList([
        row('محمد الحمدي', 'الباقي يوم العرس · الخميس', '450,000', tag('يوم العرس', K.saffronInk, K.saffronSoft)),
        row('عادل الريمي', 'الباقي يوم العرس · الخميس', '300,000', tag('يوم العرس', K.saffronInk, K.saffronSoft)),
        row('ناصر الشامي', 'تأخر 5 أيام', '150,000', tag('ذكّره', K.coral, K.coralSoft)),
      ]),
      gap(10),
      pNote('هذا دفترك، مو محفظة: تسجّل اللي وصلك بيدك أو اللي سجّله العريس وأكّدته.', i: LucideIcons.bookOpen),
    ],
  );
}

/// A card made from the profile, to post where Yemenis already look.
Widget p48ShareCard() => pPhone(
  action: Row(children: [
    Expanded(child: pBtn('حالة واتساب', icon: LucideIcons.messageCircle, v: 14, fs: 15, bg: K.green)),
    const SizedBox(width: 8),
    Expanded(child: pBtn('تيك توك', icon: LucideIcons.music2, v: 14, fs: 15)),
  ]),
  children: [
    subHeader('شارك ملفك'),
    Container(
      height: 470,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), color: P.dark),
      child: Stack(
        children: [
          Positioned.fill(child: Container(
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFF6E7F8C), P.dark])),
          )),
          Positioned(
            left: 20, right: 20, bottom: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('استوديو ضوء صنعاء', style: tx(28, w: bold, c: Colors.white)),
                Text('تصوير أعراس · صنعاء · فريق مصوّرات', style: tx(14, c: Colors.white70)),
                gap(12),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  tag('★ 4.7 من 38 عريس', P.dark, K.saffron),
                  tag('موثّق في اعّرست', P.dark, Colors.white),
                ]),
                gap(14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    Container(width: 54, height: 54, color: K.line, child: const Icon(LucideIcons.qrCode, size: 40)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('ليالي فاضية في يناير: 9', style: tx(14.5, w: bold)),
                      Text('اطلب عرضك من اعّرست', style: tx(12.5, c: K.muted)),
                    ])),
                  ]),
                ),
              ],
            ),
          ),
          Positioned(top: 16, right: 18, child: wordmark(s: 20, c: Colors.white)),
        ],
      ),
    ),
    gap(10),
    Text('الليالي الفاضية تتحدث لحالها من تقويمك.', style: tx(13, c: K.muted)),
  ],
);

/// Staff: each team leader sees only the run sheet of his team.
Widget p49Staff() => pPhone(
  tab: PTab.me,
  children: [
    subHeader('فريق العمل', sub: 'كل واحد يشوف شغله بس'),
    whiteList([
      listRow(icon: LucideIcons.crown, fg: P.c, soft: P.soft, title: 'علي الشامي', sub: 'صاحب الحساب · كل شيء'),
      listRow(icon: LucideIcons.user, fg: P.c, soft: P.soft, title: 'ياسر', sub: 'رئيس فريق 2 · شغل الليلة و«وصلنا»'),
      listRow(icon: LucideIcons.user, fg: P.c, soft: P.soft, title: 'سامي', sub: 'رئيس فريق 1 · شغل الليلة و«وصلنا»'),
      listRow(icon: LucideIcons.user, fg: K.coral, soft: K.coralSoft, title: 'أم ريم', sub: 'فريق النساء · شغل الليلة بس'),
      listRow(icon: LucideIcons.messageCircle, fg: P.c, soft: P.soft, title: 'هدى', sub: 'الرسائل والطلبات · بدون الحسابات'),
    ]),
    gap(12),
    pBtn('أضف واحد من الفريق', icon: LucideIcons.userPlus, bg: P.soft, fg: P.c, v: 14, fs: 15),
    gap(10),
    pNote('الأسعار وحساباتك ما يشوفها إلا أنت، وإلا اللي تعطيه.', i: LucideIcons.lock),
  ],
);

/// After the wedding: deliver the photos with a link the couple confirms.
Widget p50Deliver() => pPhone(
  action: pBtn('سلّم لمحمد', icon: LucideIcons.packageCheck),
  children: [
    subHeader('التسليم', sub: 'محمد الحمدي · الزفة 21 يناير'),
    Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('وعدت خلال 30 يوم', style: tx(15, w: bold))),
            Text('باقي 6 أيام', style: tx(14, w: bold, c: K.saffronInk)),
          ]),
          gap(8),
          bar(0.8, K.saffronInk, h: 8),
        ],
      ),
    ),
    gap(12),
    Box(
      child: Column(children: [
        Row(children: [const Icon(LucideIcons.checkSquare, color: P.c), const SizedBox(width: 10), Expanded(child: Text('300 صورة معدّلة', style: tx(15)))]),
        gap(10),
        Row(children: [const Icon(LucideIcons.checkSquare, color: P.c), const SizedBox(width: 10), Expanded(child: Text('فيلم 10 دقايق', style: tx(15)))]),
        gap(10),
        Row(children: [const Icon(LucideIcons.square, color: K.faint), const SizedBox(width: 10), Expanded(child: Text('الألبوم المطبوع · بعد أسبوع', style: tx(15, c: K.muted)))]),
      ]),
    ),
    gap(10),
    pField('رابط التحميل', 'drive.google.com/…', icon: LucideIcons.link),
    gap(10),
    pNote('محمد يأكد إنه استلم. وبعدها يوصله طلب التقييم، والتقييم اللي يجي بعد تسليم مأكد يبان عليه «استلم».', i: LucideIcons.shieldCheck),
  ],
);
