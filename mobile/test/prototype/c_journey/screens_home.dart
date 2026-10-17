// Journey prototype: the home tab across the five moments of the wedding.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'kit.dart';

const moments = ['البداية', 'التجهيز', 'أسبوع العرس', 'يوم العرس', 'بعد العرس'];

Widget homeHeader({String hello = 'أهلًا محمد'}) => Padding(
  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hello, style: tx(24, w: bold)),
            Text('عرس محمد وسلمى · صنعاء', style: tx(14, c: K.muted)),
          ],
        ),
      ),
      Stack(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.bell, size: 20, color: K.ink),
          ),
          Positioned(top: 10, left: 12, child: dot(K.coral)),
        ],
      ),
      const SizedBox(width: 8),
      Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: K.saffron,
          shape: BoxShape.circle,
        ),
        child: Text('م', style: tx(18, w: bold)),
      ),
    ],
  ),
);

Widget hero({
  required int at,
  required String big,
  required String unit,
  required String sub,
  Widget? extra,
  double bigSize = 64,
}) => Container(
  margin: const EdgeInsets.only(top: 18),
  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(28),
    gradient: const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [K.teal, K.tealDark],
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            big,
            style: tx(bigSize, w: bold, c: Colors.white, h: 0.95),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unit,
                    style: tx(18, w: bold, c: Colors.white),
                  ),
                  Text(
                    sub,
                    style: tx(14, c: Colors.white.withValues(alpha: 0.78)),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: K.saffron,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(moments[at], style: tx(13, w: bold)),
          ),
        ],
      ),
      gap(16),
      segments(
        5,
        at,
        on: Colors.white,
        now: K.saffron,
        off: Colors.white.withValues(alpha: 0.22),
      ),
      ?extra,
    ],
  ),
);

Widget pulseTiles({
  String tasks = '12',
  String tasksSub = 'من 30 مهمة',
  double tasksV = 0.4,
  String guests = '86',
  String guestsSub = 'أكدوا من 124',
  double guestsV = 0.69,
  String prov = '3',
  String provSub = 'محجوز من 7',
  double provV = 0.43,
}) {
  Widget tile(Sec s, String big, String small, double v) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: s.soft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(s.icon, size: 17, color: s.color),
              const SizedBox(width: 6),
              Text(
                s.label,
                style: tx(14, w: bold, c: s.color),
              ),
            ],
          ),
          gap(10),
          Text(big, style: tx(24, w: bold)),
          Text(small, style: tx(13, c: K.muted)),
          gap(10),
          bar(v, s.color, bg: Colors.white.withValues(alpha: 0.8), h: 5),
        ],
      ),
    ),
  );
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      tile(Sec.tasks, tasks, tasksSub, tasksV),
      const SizedBox(width: 10),
      tile(Sec.guests, guests, guestsSub, guestsV),
      const SizedBox(width: 10),
      tile(Sec.providers, prov, provSub, provV),
    ],
  );
}

Widget moneyTile() => Container(
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: K.tealSoft,
    borderRadius: BorderRadius.circular(24),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Icon(LucideIcons.wallet, size: 17, color: K.teal),
          const SizedBox(width: 6),
          Text(
            'المال',
            style: tx(14, w: bold, c: K.teal),
          ),
          const Spacer(),
          Text('العرس بـ 10 مليون', style: tx(13, c: K.muted)),
        ],
      ),
      gap(10),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ناقصك', style: tx(14, c: K.muted)),
                Text(
                  '1.3 مليون ر.ي',
                  style: tx(28, w: bold, c: K.coral),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('باقي تدفع 5.4', style: tx(14, w: bold)),
              Text(
                'معك 4.1',
                style: tx(14, w: bold, c: K.teal),
              ),
            ],
          ),
        ],
      ),
      gap(12),
      moneyBar(0.46, 0.41, 0.13),
    ],
  ),
);

// ------------------------------------------------------------ 1 · البداية

Widget homeFresh() {
  Widget step(
    int i,
    IconData ic,
    Sec s,
    String title,
    String sub, {
    bool done = false,
    bool now = false,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: card(
      c: now ? Colors.white : Colors.white.withValues(alpha: 0.65),
      border: now ? K.teal : null,
    ),
    child: Row(
      children: [
        done
            ? Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: K.green,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(LucideIcons.check, color: Colors.white),
              )
            : iconTile(ic, s.color, s.soft, s: 48, r: 16),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                done ? 'خلصت · الخطوة $i' : 'الخطوة $i',
                style: tx(12.5, w: bold, c: done ? K.green : K.muted),
              ),
              Text(
                title,
                style: tx(17, w: bold, c: done ? K.muted : K.ink),
              ),
              Text(sub, style: tx(13.5, c: K.muted)),
            ],
          ),
        ),
        if (now)
          btn('كمّل', v: 10)
        else if (!done)
          const Icon(LucideIcons.chevronLeft, color: K.faint, size: 20),
      ],
    ),
  );
  return Phone(
    nav: Sec.home,
    children: [
      homeHeader(),
      hero(at: 0, big: '96', unit: 'يوم على عرسك', sub: 'الخميس 21 يناير'),
      gap(24),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text('ثلاث خطوات وعرسك منظم', style: tx(22, w: bold)),
      ),
      gap(8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            Text(
              'خلصت 1 من 3',
              style: tx(14, w: bold, c: K.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: segments(
                3,
                1,
                on: K.green,
                now: K.teal,
                off: Colors.white,
              ),
            ),
          ],
        ),
      ),
      gap(14),
      step(
        1,
        LucideIcons.wallet,
        Sec.money,
        'ميزانيتك',
        '10 مليون موزعة على 14 بند',
        done: true,
      ),
      step(
        2,
        LucideIcons.building2,
        Sec.providers,
        'أهم الحجوزات',
        'القاعة أولًا، ثم التصوير والفرقة',
        now: true,
      ),
      step(
        3,
        LucideIcons.users,
        Sec.guests,
        'قائمة الضيوف',
        'من جهات الاتصال بضغطة',
      ),
    ],
  );
}

// ------------------------------------------------------------ 2 · التجهيز

const upcoming = [
  (
    LucideIcons.camera,
    Sec.providers,
    'التصوير: وصلك عرضين',
    'السبت · قارن واختر قبل ما ترتفع الأسعار',
    'قارن',
  ),
  (
    LucideIcons.users,
    Sec.guests,
    '20 ضيف ما ردّوا',
    'الأحد · أرسل لهم تذكير على واتساب',
    'ذكّرهم',
  ),
  (
    LucideIcons.music,
    Sec.tasks,
    'الفرقة ما انحجزت',
    'هذا الأسبوع · العرس بعد 3 أشهر',
    'ابحث',
  ),
];

Widget upcomingList() => whiteList([
  for (final u in upcoming)
    listRow(
      icon: u.$1,
      fg: u.$2.color,
      soft: u.$2.soft,
      title: u.$3,
      sub: u.$4,
      trailing: softAction(u.$5),
    ),
], dividers: false);

Widget homeActive() => Phone(
  nav: Sec.home,
  children: [
    homeHeader(),
    hero(at: 1, big: '96', unit: 'يوم على عرسك', sub: 'الخميس 21 يناير'),
    gap(14),
    nextCard(
      eyebrow: 'الخطوة الجاية · بعد 5 أيام',
      title: 'دفعة القاعة: 500,000 ر.ي',
      sub: 'قاعة سبأ · الدفعة الثانية من ثلاث',
      action: 'سجّل الدفعة',
      second: 'ذكّرني',
    ),
    gap(14),
    moneyTile(),
    gap(10),
    pulseTiles(),
    sectionTitle('بعدها'),
    upcomingList(),
  ],
);

// ------------------------------------------------------------ 3 · أسبوع العرس

Widget homeWeek() {
  Widget day(
    String d,
    String name,
    String detail, {
    bool today = false,
    bool done = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Container(
          width: 58,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: today ? K.teal : (done ? K.bg : K.tealSoft),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                d.split(' ').first,
                style: tx(12, w: bold, c: today ? Colors.white : K.muted),
              ),
              Text(
                d.split(' ').last,
                style: tx(20, w: bold, c: today ? Colors.white : K.ink),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    name,
                    style: tx(16, w: bold, c: done ? K.muted : K.ink),
                  ),
                  if (today) ...[
                    const SizedBox(width: 8),
                    tag('الليلة', K.saffronInk, K.saffronSoft),
                  ],
                ],
              ),
              Text(detail, style: tx(13, c: K.muted)),
            ],
          ),
        ),
        if (done)
          const Icon(LucideIcons.checkCircle2, color: K.green, size: 20),
      ],
    ),
  );

  return Phone(
    nav: Sec.home,
    children: [
      homeHeader(hello: 'باقي يومين يا محمد'),
      hero(at: 2, big: '2', unit: 'يوم على عرسك', sub: 'الخميس 21 يناير'),
      gap(14),
      nextCard(
        eyebrow: 'الخطوة الجاية · اليوم',
        title: 'فرقة الأفراح ما أكّدت',
        sub: 'أرسل لهم تأكيد الموعد على واتساب',
        action: 'أرسل التأكيد',
        icon: LucideIcons.music,
        fg: K.sky,
        soft: K.skySoft,
      ),
      sectionTitle('برنامج الأسبوع', action: 'تعديل'),
      whiteList([
        day('الاثنين 18', 'تجهيز البيت', 'خلص · الأثاث وصل', done: true),
        day('الثلاثاء 19', 'الحناء', 'بيت العروسة · 8 مساءً', today: true),
        day('الأربعاء 20', 'المقيل', 'بيت الوالد · 2 ظهرًا'),
        day('الخميس 21', 'الزفاف', 'قاعة سبأ · 7 مساءً'),
      ], dividers: false),
      sectionTitle('المزودين'),
      Box(
        pad: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('أكّدوا 4 من 5', style: tx(16, w: bold)),
                ),
                Text(
                  'القاعة، التصوير، الكوشة، الضيافة',
                  style: tx(12.5, c: K.muted),
                ),
              ],
            ),
            gap(10),
            segments(5, 4, on: K.sky, now: K.coral, off: K.line),
          ],
        ),
      ),
      sectionTitle('الكاش اللي تحتاجه'),
      Box(
        c: K.tealSoft,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('للأيام الثلاثة', style: tx(14, c: K.muted)),
                  Text(
                    '850,000 ر.ي',
                    style: tx(26, w: bold, c: K.teal),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('الحناء 150 ألف', style: tx(13, c: K.muted)),
                Text('المقيل 200 ألف', style: tx(13, c: K.muted)),
                Text('الزفاف 500 ألف', style: tx(13, c: K.muted)),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

// ------------------------------------------------------------ 4 · يوم العرس

Widget homeDay({bool withSheet = false}) {
  Widget slot(
    String time,
    String what,
    String who, {
    bool now = false,
    bool done = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    child: Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            time,
            style: tx(14, w: bold, c: now ? K.teal : (done ? K.faint : K.ink)),
          ),
        ),
        dot(now ? K.saffron : (done ? K.line : K.tealMid), 10),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                what,
                style: tx(15.5, w: bold, c: done ? K.faint : K.ink),
              ),
              Text(who, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        if (now) tag('الحين', K.saffronInk, K.saffronSoft),
      ],
    ),
  );

  return Phone(
    nav: Sec.home,
    sheet: withSheet ? rafdSheet() : null,
    children: [
      homeHeader(hello: 'مبروك يا عريس'),
      hero(
        at: 3,
        big: 'اليوم',
        bigSize: 46,
        unit: 'يوم عرسك',
        sub: 'قاعة سبأ · 7 مساءً',
      ),
      gap(14),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: K.saffron,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(LucideIcons.gem, size: 26, color: K.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('سجّل رفد', style: tx(22, w: bold)),
                  Text(
                    'اسم ومبلغ، ويشتغل بدون نت',
                    style: tx(14, c: K.ink.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('47 رفد', style: tx(15, w: bold)),
                Text(
                  '1.2 مليون',
                  style: tx(13, c: K.ink.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ],
        ),
      ),
      sectionTitle('برنامج اليوم'),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: card(),
        child: Column(
          children: [
            slot(
              '1:00',
              'الغداء',
              'بيت الوالد · الذبائح من أبو علي',
              done: true,
            ),
            slot('3:00', 'المقيل', 'الديوان · القات عند أخوك صالح', now: true),
            slot('7:00', 'الزفة', 'قاعة سبأ · فرقة الأفراح'),
            slot('10:00', 'العشاء', 'قاعة سبأ · ضيافة الأصالة'),
          ],
        ),
      ),
      sectionTitle('أرقام اليوم'),
      whiteList([
        listRow(
          icon: LucideIcons.phoneCall,
          fg: K.sky,
          soft: K.skySoft,
          title: 'قاعة سبأ · أبو فهد',
          sub: ltr('777 300 120'),
          trailing: softAction('اتصل', fg: K.sky, bg: K.skySoft),
        ),
        listRow(
          icon: LucideIcons.phoneCall,
          fg: K.sky,
          soft: K.skySoft,
          title: 'فرقة الأفراح',
          sub: ltr('733 455 900'),
          trailing: softAction('اتصل', fg: K.sky, bg: K.skySoft),
        ),
      ], dividers: false),
    ],
  );
}

Widget rafdSheet() {
  Widget key(String k) => Expanded(
    child: Container(
      height: 52,
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(k, style: tx(22, w: bold)),
    ),
  );
  return sheet(
    title: 'سجّل رفد',
    sub: 'ينحفظ في جوالك، ويوصل لما يرجع النت',
    children: [
      field('من؟', 'عبدالله الحمدي', icon: LucideIcons.user),
      gap(10),
      field('كم؟', '20,000', big: true, focused: true, suffix: 'ر.ي'),
      gap(10),
      Wrap(
        spacing: 8,
        children: [
          chip('5,000'),
          chip('10,000'),
          chip('20,000', on: true),
          chip('50,000'),
        ],
      ),
      gap(10),
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            Row(children: [key('1'), key('2'), key('3')]),
            Row(children: [key('4'), key('5'), key('6')]),
          ],
        ),
      ),
      gap(12),
      btn(
        'حفظ وسجّل التالي',
        wide: true,
        v: 16,
        fs: 17,
        bg: K.saffron,
        fg: K.ink,
      ),
    ],
  );
}

// ------------------------------------------------------------ 5 · بعد العرس

Widget homeAfter() => Phone(
  nav: Sec.home,
  children: [
    homeHeader(hello: 'ألف مبروك يا محمد'),
    hero(
      at: 4,
      big: '1.9',
      unit: 'مليون باقي عليك',
      sub: 'تخلص منها في يونيو',
      extra: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          'سددت 2.3 من 4.2 مليون بعد العرس',
          style: tx(13.5, c: Colors.white.withValues(alpha: 0.85)),
        ),
      ),
    ),
    gap(14),
    nextCard(
      eyebrow: 'الخطوة الجاية · بعد 9 أيام',
      title: 'قسط خالك: 150,000 ر.ي',
      sub: 'القسط 3 من 4 · سلفة العرس',
      action: 'سجّل السداد',
      icon: LucideIcons.wallet,
      fg: K.teal,
      soft: K.tealSoft,
    ),
    sectionTitle('اللي عليك'),
    whiteList([
      listRow(
        icon: LucideIcons.user,
        fg: K.teal,
        soft: K.tealSoft,
        title: 'سلفة خالي أحمد',
        sub: 'باقي 300 ألف من 600 · قسطين',
        trailing: Text(
          'مارس',
          style: tx(14, w: bold, c: K.muted),
        ),
      ),
      listRow(
        icon: LucideIcons.building2,
        fg: K.sky,
        soft: K.skySoft,
        title: 'باقي قاعة سبأ',
        sub: 'باقي 400 ألف · اتفقتوا على فبراير',
        trailing: Text(
          'فبراير',
          style: tx(14, w: bold, c: K.muted),
        ),
      ),
      listRow(
        icon: LucideIcons.user,
        fg: K.teal,
        soft: K.tealSoft,
        title: 'دين صاحبي عادل',
        sub: '1.2 مليون · بدون موعد',
        trailing: Text(
          'يونيو',
          style: tx(14, w: bold, c: K.muted),
        ),
      ),
    ]),
    sectionTitle('الرفد', action: 'الدفتر كامل'),
    Row(
      children: [
        Expanded(
          child: Box(
            c: K.saffronSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('وصلك', style: tx(14, c: K.muted)),
                Text('1.8 مليون', style: tx(22, w: bold)),
                Text('من 112 شخص', style: tx(13, c: K.muted)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Box(
            c: K.lilacSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تذكير', style: tx(14, c: K.muted)),
                Text('عرس سالم', style: tx(22, w: bold)),
                Text('رفدك 20 ألف · الشهر الجاي', style: tx(13, c: K.muted)),
              ],
            ),
          ),
        ),
      ],
    ),
  ],
);
