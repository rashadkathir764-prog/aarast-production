// Journey prototype v3: tasks, guests, providers, family and account.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';

// ================================================================ المهام

Widget _task(
  String title,
  String meta,
  String who,
  Color whoC, {
  String? link,
  Color lf = K.sky,
  Color lb = K.skySoft,
  bool late = false,
}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: late ? K.coral : K.line, width: 2),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: tx(15.5, w: bold)),
            Text(
              meta,
              style: tx(
                12.5,
                w: late ? bold : FontWeight.w400,
                c: late ? K.coral : K.muted,
              ),
            ),
            if (link != null) ...[
              gap(8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: lb,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      link,
                      style: tx(13, w: bold, c: lf),
                    ),
                    const SizedBox(width: 4),
                    Icon(LucideIcons.arrowLeft, size: 14, color: lf),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      avatar(who, whoC),
    ],
  ),
);

Widget _sticky(String t, String n, {Color c = K.ink}) => Container(
  padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
  child: Row(
    children: [
      Text(
        t,
        style: tx(16, w: bold, c: c),
      ),
      const SizedBox(width: 8),
      Text(n, style: tx(14, c: K.muted)),
    ],
  ),
);

Widget vTasks() {
  // A task mid-swipe, showing "done" behind it.
  final swiped = SizedBox(
    height: 70,
    child: Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: K.green,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'خلصت',
                  style: tx(15, w: bold, c: Colors.white),
                ),
                const SizedBox(width: 6),
                const Icon(LucideIcons.check, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          left: 90,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: K.ink.withValues(alpha: 0.08), blurRadius: 10),
              ],
            ),
            child: _task(
              'سلّم باقي المهر',
              '15 نوفمبر · لأهل العروسة',
              'م',
              K.teal,
            ),
          ),
        ),
      ],
    ),
  );
  return Phone(
    nav: Sec.tasks,
    children: [
      tabHeader(
        'المهام',
        'باقي 3 هذا الأسبوع، وواحدة متأخرة',
        actions: [LucideIcons.share2, LucideIcons.plus],
      ),
      Row(
        children: [
          chip('لي', on: true, onBg: K.saffronInk),
          const SizedBox(width: 8),
          chip('لصالح'),
          const SizedBox(width: 8),
          chip('للوالد'),
          const Spacer(),
          Text(
            '12 من 30',
            style: tx(14, w: bold, c: K.saffronInk),
          ),
        ],
      ),
      _sticky('متأخرة', '1', c: K.coral),
      whiteList([
        _task(
          'حدد موعد عقد القران',
          'كان موعدها 12 أكتوبر',
          'م',
          K.teal,
          late: true,
          link: 'أضف الموعد',
          lf: K.teal,
          lb: K.tealSoft,
        ),
      ]),
      _sticky('هذا الأسبوع', '3'),
      whiteList([
        _task(
          'اختر المصور',
          'السبت · وصلك عرضين',
          'م',
          K.teal,
          link: 'قارن العروض',
        ),
        _task(
          'ادفع دفعة القاعة',
          'الخميس · 500 ألف',
          'م',
          K.teal,
          link: 'سجّل الدفعة',
          lf: K.teal,
          lb: K.tealSoft,
        ),
        _task('رتّب الغداء', 'الجمعة · أبو علي', 'ص', K.saffronInk),
      ]),
      _sticky('هذا الشهر', '4'),
      swiped,
      gap(8),
      Center(
        child: Text(
          'اسحب المهمة يسار لما تخلصها',
          style: tx(13, w: bold, c: K.faint),
        ),
      ),
    ],
  );
}

Widget vAddTask() => Phone(
  nav: Sec.tasks,
  sheet: sheet(
    title: 'مهمة جديدة',
    children: [
      field('وش المهمة؟', 'تذوّق الضيافة مع صالح', focused: true),
      gap(14),
      Text(
        'متى؟',
        style: tx(14, w: bold, c: K.muted),
      ),
      gap(8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('هذا الأسبوع', on: true, onBg: K.saffronInk),
          chip('هذا الشهر'),
          chip('بعد العصر', icon: LucideIcons.sun),
          chip('تاريخ', icon: LucideIcons.calendarDays),
        ],
      ),
      gap(14),
      Text(
        'لمين؟',
        style: tx(14, w: bold, c: K.muted),
      ),
      gap(8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('أنا', on: true, onBg: K.saffronInk),
          chip('صالح'),
          chip('الوالد'),
          chip('شخص ثاني', icon: LucideIcons.plus),
        ],
      ),
      gap(18),
      btn('حفظ المهمة', wide: true, v: 16, fs: 17, bg: K.saffronInk),
    ],
  ),
  children: [tabHeader('المهام', 'باقي 3 هذا الأسبوع')],
);

// ================================================================ الضيوف

Widget _guestHead() => tabHeader(
  'الضيوف',
  '124 مدعو · 86 أكدوا · 20 ما ردّوا',
  actions: [LucideIcons.search, LucideIcons.plus],
);

Widget vGuestsMen() {
  Widget fam(String n, int all, int yes, String who) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        iconTile(LucideIcons.users, K.lilac, K.lilacSoft, s: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n, style: tx(15.5, w: bold)),
              Text(who, style: tx(12.5, c: K.muted)),
              gap(6),
              bar(yes / all, K.lilac, h: 5),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$yes/$all', style: tx(15, w: bold)),
            Text('أكدوا', style: tx(12, c: K.muted)),
          ],
        ),
      ],
    ),
  );
  return Phone(
    nav: Sec.guests,
    children: [
      _guestHead(),
      Box(
        pad: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'قاعة سبأ تتسع 150 · باقي 26 مقعد',
              style: tx(13, w: bold, c: K.muted),
            ),
            gap(8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('86', style: tx(36, w: bold, h: 1)),
                Text('  أكدوا من 124', style: tx(15, c: K.muted)),
                const Spacer(),
                Text(
                  '20 ما ردّوا',
                  style: tx(15, w: bold, c: K.saffronInk),
                ),
              ],
            ),
            gap(12),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    Expanded(flex: 86, child: Container(color: K.lilac)),
                    const SizedBox(width: 2),
                    Expanded(flex: 20, child: Container(color: K.saffron)),
                    const SizedBox(width: 2),
                    Expanded(flex: 18, child: Container(color: K.line)),
                  ],
                ),
              ),
            ),
            gap(14),
            btn(
              'ذكّر الـ 20 على واتساب',
              bg: K.lilac,
              wide: true,
              icon: LucideIcons.send,
            ),
          ],
        ),
      ),
      sectionTitle('حسب العائلة', ac: K.lilac, action: 'بطاقة الدعوة'),
      whiteList([
        fam('آل الحمدي', 38, 30, 'أهل العريس · يرسل لهم الوالد'),
        fam('آل السقاف', 22, 14, 'أهل العروسة'),
        fam('زملاء العمل', 24, 18, 'محمد'),
        fam('الأصحاب', 28, 16, 'محمد'),
        fam('الجيران', 12, 8, 'الوالد'),
      ]),
    ],
  );
}

Widget vContacts() {
  Widget c(String n, String p, bool on, {bool warn = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    child: Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: on ? K.lilac : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? K.lilac : K.line, width: 2),
          ),
          child: on
              ? const Icon(LucideIcons.check, size: 15, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n, style: tx(15, w: bold)),
              Text(
                warn ? '$p · موجود من قبل' : p,
                style: tx(
                  12.5,
                  w: warn ? bold : FontWeight.w400,
                  c: warn ? K.saffronInk : K.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget fam(String name, String count, List<Widget> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
        child: Row(
          children: [
            Text(name, style: tx(15, w: bold)),
            const SizedBox(width: 8),
            Text(count, style: tx(13, c: K.muted)),
            const Spacer(),
            Text(
              'اختر العائلة',
              style: tx(13.5, w: bold, c: K.lilac),
            ),
          ],
        ),
      ),
      whiteList(rows, dividers: false),
    ],
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      child: btn('أضف 7 ضيوف لعرسك', wide: true, v: 16, fs: 17, bg: K.lilac),
    ),
    children: [
      subHeader('من جهات الاتصال', sub: 'رتبناهم لك حسب العائلة'),
      field('ابحث', 'الاسم أو الرقم', icon: LucideIcons.search),
      fam('آل الحمدي', '6 من جهاتك', [
        c('أحمد الحمدي', ltr('777 210 334'), true),
        c('علي الحمدي', ltr('771 908 120'), true),
        c('عبدالله الحمدي', ltr('733 455 001'), false, warn: true),
        c('هاني الحمدي', ltr('770 112 889'), true),
      ]),
      fam('آل الأهدل', '3 من جهاتك', [
        c('ياسر الأهدل', ltr('735 660 210'), true),
        c('مراد الأهدل', ltr('777 881 002'), true),
      ]),
    ],
  );
}

Widget vInvite() => Phone(
  bg: const Color(0xFFE9EEEC),
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
    child: Column(
      children: [
        btn(
          'أرسلها لـ 124 ضيف',
          wide: true,
          v: 16,
          fs: 17,
          bg: K.green,
          icon: LucideIcons.send,
        ),
        gap(8),
        Text(
          'كل ضيف يوصله رابط خاص يرد منه بضغطة',
          style: tx(13.5, c: K.muted),
        ),
      ],
    ),
  ),
  children: [
    subHeader('بطاقة الدعوة', sub: 'بدون صور'),

    Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [K.tealDark, K.teal],
        ),
      ),
      child: CustomPaint(
        painter: const QamariyaMark(alpha: 0.12, cx: 0.5),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Column(
            children: [
              Text('يتشرف', style: tx(15, c: Colors.white70)),
              Text(
                'عبدالرحمن الحمدي',
                style: tx(20, w: bold, c: Colors.white),
              ),
              Text(
                'بدعوتكم لحضور حفل زفاف نجله',
                style: tx(15, c: Colors.white),
              ),
              gap(14),
              Text(
                'محمد',
                style: tx(42, w: bold, c: Colors.white, h: 1.1),
              ),
              gap(14),
              Container(height: 1, color: Colors.white24),
              gap(14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final c in const [
                    ('الخميس', '21 يناير'),
                    ('13 شعبان', 'بعد العصر'),
                    ('المكان', 'قاعة سبأ'),
                  ])
                    Column(
                      children: [
                        Text(c.$1, style: tx(13, c: Colors.white70)),
                        Text(
                          c.$2,
                          style: tx(16, w: bold, c: Colors.white),
                        ),
                      ],
                    ),
                ],
              ),
              gap(18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: K.saffron,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('أكّد حضورك', style: tx(16, w: bold)),
              ),
            ],
          ),
        ),
      ),
    ),
  ],
);

/// What a guest sees in the browser when they open their link.
Widget vRsvp() => Phone(
  bg: Colors.white,
  pad: false,
  children: [
    Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: K.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            const Icon(LucideIcons.lock, size: 14, color: K.green),
            const SizedBox(width: 6),
            Text('aarast.app/rsvp/…', style: tx(14, c: K.muted)),
          ],
        ),
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: wordmark(s: 22)),
          gap(20),
          Text('أهلًا أحمد', style: tx(26, w: bold)),
          Text('عبدالرحمن الحمدي يدعوك لزفاف محمد', style: tx(16, c: K.muted)),
          gap(16),
          Box(
            c: K.tealSoft,
            child: Column(
              children: [
                for (final r in const [
                  (LucideIcons.calendarDays, 'الخميس 21 يناير · 13 شعبان'),
                  (LucideIcons.clock, 'بعد العصر'),
                  (LucideIcons.mapPin, 'قاعة سبأ · حدة، صنعاء'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(r.$1, size: 18, color: K.teal),
                        const SizedBox(width: 10),
                        Text(r.$2, style: tx(15.5, w: bold)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          gap(18),
          Text('بتحضر؟', style: tx(18, w: bold)),
          gap(10),
          btn(
            'إن شاء الله حاضر',
            wide: true,
            v: 16,
            fs: 17,
            icon: LucideIcons.check,
          ),
          gap(10),
          btn('أعتذر', wide: true, v: 14, bg: K.bg, fg: K.muted),
          gap(16),
          Text(
            'كم معك؟',
            style: tx(15, w: bold, c: K.muted),
          ),
          gap(8),
          Wrap(
            spacing: 8,
            children: [
              chip('لحالي', on: true),
              chip('+1'),
              chip('+2'),
              chip('+3'),
            ],
          ),
          gap(18),
          Center(
            child: Text('ما تحتاج تنزل أي تطبيق', style: tx(13, c: K.faint)),
          ),
        ],
      ),
    ),
  ],
);

// ================================================================ المزودين

const _provTabs = ['طلباتي', 'استكشف', 'المحادثات', 'المفضلة'];

Widget _stage(int at) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    for (var i = 0; i < 4; i++) ...[
      Container(
        width: 18,
        height: 5,
        decoration: BoxDecoration(
          color: i < at ? (at == 4 ? K.green : K.sky) : K.line,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      if (i < 3) const SizedBox(width: 3),
    ],
  ],
);

Widget vProvRequests() {
  Widget svc(IconData i, String name, String who, int st, Widget tr) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        iconTile(i, K.sky, K.skySoft, s: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: tx(15.5, w: bold)),
              Text(who, style: tx(12.5, c: K.muted)),
              gap(6),
              _stage(st),
            ],
          ),
        ),
        tr,
      ],
    ),
  );
  return Phone(
    nav: Sec.providers,
    children: [
      tabHeader(
        'المزودين',
        'محجوز 3 من 6 · عرضين ينتظرونك',
        actions: [LucideIcons.search],
      ),
      topTabs(_provTabs, 0, c: K.sky),
      gap(14),
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
        child: Row(
          children: [
            Expanded(
              child: Text('خدمات عرسك', style: tx(17, w: bold)),
            ),
            Text('طلب · عرض · طلب حجز · محجوز', style: tx(12.5, c: K.muted)),
          ],
        ),
      ),
      whiteList([
        svc(
          LucideIcons.building2,
          'القاعة',
          'قاعة سبأ · أكّدت 21 يناير',
          4,
          tag('محجوز', K.green, K.greenSoft),
        ),
        svc(
          LucideIcons.utensils,
          'الضيافة',
          'ضيافة الأصالة · أكّدت',
          4,
          tag('محجوز', K.green, K.greenSoft),
        ),
        svc(
          LucideIcons.soup,
          'الغداء',
          'أبو علي · خارج اعّرست',
          4,
          tag('محجوز', K.green, K.greenSoft),
        ),
        svc(
          LucideIcons.camera,
          'التصوير',
          'عرضين وصلوا',
          2,
          softAction('قارن', fg: K.sky, bg: K.skySoft),
        ),
        svc(
          LucideIcons.leaf,
          'القات',
          'طلبت من 2 · ينتظر الرد',
          1,
          tag('بعد يومين', K.muted, K.bg),
        ),
        svc(
          LucideIcons.music,
          'الفنان والفرقة',
          'ما بدأت',
          0,
          softAction('ابحث', fg: K.sky, bg: K.skySoft),
        ),
      ]),
    ],
  );
}

Widget _photo(
  List<Color> cs,
  IconData i, {
  double h = 120,
  double r = 18,
  bool saver = false,
}) => Container(
  height: h,
  width: double.infinity,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(r),
    gradient: saver ? null : LinearGradient(colors: cs),
    color: saver ? K.bg : null,
  ),
  child: saver
      ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.image, color: K.faint),
            gap(4),
            Text(
              'اضغط لعرض الصور · 1.2 ميجا',
              style: tx(13, w: bold, c: K.muted),
            ),
          ],
        )
      : Icon(i, size: h * 0.32, color: Colors.white.withValues(alpha: 0.55)),
);

Widget vProvExplore() {
  Widget pcard(
    String name,
    String area,
    String rating,
    String price,
    List<Color> cs,
    IconData i,
    List<Widget> badges, {
    bool saver = false,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _photo(cs, i, h: 120, r: 22, saver: saver),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name, style: tx(17, w: bold)),
                  ),
                  const Icon(LucideIcons.star, size: 15, color: K.saffron),
                  Text(' $rating', style: tx(14, w: bold)),
                ],
              ),
              Text(area, style: tx(13, c: K.muted)),
              gap(6),
              Wrap(spacing: 6, runSpacing: 6, children: badges),
              gap(6),
              Text(
                price,
                style: tx(15, w: bold, c: K.sky),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    nav: Sec.providers,
    children: [
      tabHeader('المزودين', 'محجوز 3 من 6', actions: [LucideIcons.search]),
      topTabs(_provTabs, 1, c: K.sky),
      gap(12),
      SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            chip('فنانين وفرق', on: true, onBg: K.sky, icon: LucideIcons.music),
            const SizedBox(width: 8),
            chip('تصوير', icon: LucideIcons.camera),
            const SizedBox(width: 8),
            chip('قات', icon: LucideIcons.leaf),
            const SizedBox(width: 8),
            chip('ضيافة', icon: LucideIcons.utensils),
          ],
        ),
      ),
      gap(12),
      Box(
        c: K.skySoft,
        pad: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(LucideIcons.sparkles, size: 18, color: K.sky),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'قريبين من بندك 500 ألف، وفاضيين ليلة الزفاف 21 يناير',
                style: tx(14, w: bold, c: K.sky),
              ),
            ),
          ],
        ),
      ),
      gap(12),
      pcard(
        'فرقة الأفراح',
        'صنعاء · حدة',
        '4.9 (88)',
        '350 - 450 ألف ر.ي',
        const [Color(0xFF2F6E9E), Color(0xFF6A4FA3)],
        LucideIcons.music,
        [
          tag('ضمن بندك', K.green, K.greenSoft),
          tag('باقي فرقة وحدة ليلة 21', K.saffronInk, K.saffronSoft),
          tag('موثّق', K.sky, K.skySoft),
        ],
      ),
      pcard(
        'الفنان أيمن الآنسي',
        'صنعاء · الأصبحي',
        '4.7 (41)',
        '500 - 700 ألف ر.ي',
        const [Color(0xFF0B6E69), Color(0xFF2F6E9E)],
        LucideIcons.mic,
        [tag('اسأل عن التوفر', K.muted, K.line), tag('ما حدّث تقويمه من شهر', K.muted, K.line)],
        saver: true,
      ),
    ],
  );
}

Widget vProvPage() => Phone(
  pad: false,
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
    child: Row(
      children: [
        Expanded(child: btn('اطلب عرض سعر', bg: K.sky, v: 16, fs: 17)),
        const SizedBox(width: 10),
        btn(
          'واتساب',
          bg: K.greenSoft,
          fg: K.green,
          v: 16,
          fs: 16,
          icon: LucideIcons.messageCircle,
        ),
      ],
    ),
  ),
  children: [
    Stack(
      children: [
        _photo(
          const [Color(0xFF2F6E9E), Color(0xFF13211F)],
          LucideIcons.camera,
          h: 220,
          r: 0,
        ),
        Positioned(
          top: 12,
          right: 16,
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.arrowRight, size: 20, color: K.ink),
          ),
        ),
        Positioned(
          bottom: 14,
          left: 16,
          child: tag('1 / 24 صورة', Colors.white, Colors.black45),
        ),
      ],
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('استوديو ضوء صنعاء', style: tx(24, w: bold)),
              ),
              const Icon(LucideIcons.badgeCheck, color: K.sky, size: 22),
            ],
          ),
          Row(
            children: [
              const Icon(LucideIcons.star, size: 16, color: K.saffron),
              Text(' 4.8', style: tx(15, w: bold)),
              Text(' (63) · صنعاء، حدة', style: tx(14, c: K.muted)),
            ],
          ),
          gap(10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              tag('يرد عادة خلال ساعتين', K.green, K.greenSoft),
              tag('فاضي ليلة 21 · باقي فريقين', K.sky, K.skySoft),
              tag('عنده فريق مصوّرات', K.coral, K.coralSoft),
            ],
          ),
          gap(12),
          Box(
            c: K.skySoft,
            pad: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('عرسان دفعوا فعلًا', style: tx(13, c: K.muted)),
                          Text(
                            '450 - 600 ألف ر.ي',
                            style: tx(19, w: bold, c: K.sky),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      LucideIcons.checkCircle2,
                      size: 16,
                      color: K.green,
                    ),
                    Text(
                      ' ضمن بندك',
                      style: tx(14, w: bold, c: K.green),
                    ),
                  ],
                ),
                gap(4),
                Text(
                  'من 11 عرس · آخر تحديث للسعر قبل 3 أسابيع',
                  style: tx(12.5, c: K.muted),
                ),
              ],
            ),
          ),
          sectionTitle('الباقات', ac: K.sky),
          whiteList([
            listRow(
              icon: LucideIcons.camera,
              fg: K.sky,
              soft: K.skySoft,
              title: 'صور فقط',
              sub: 'مصور واحد · 300 صورة',
              trailing: Text('350 ألف', style: tx(15, w: bold)),
            ),
            listRow(
              icon: LucideIcons.video,
              fg: K.sky,
              soft: K.skySoft,
              title: 'صور وفيديو',
              sub: 'مصورين · فيلم 10 دقائق · ألبوم',
              trailing: Text('550 ألف', style: tx(15, w: bold)),
            ),
          ]),
        ],
      ),
    ),
  ],
);

Widget vCompare() {
  Widget col(
    String name,
    String price,
    List<(String, bool)> incl,
    String rating,
    String pay, {
    bool best = false,
  }) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: card(border: best ? K.sky : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (best) ...[tag('أنسب لك', K.sky, K.skySoft), gap(8)],
          Text(name, style: tx(15.5, w: bold)),
          gap(8),
          Text(price, style: tx(22, w: bold)),
          Text('ر.ي', style: tx(12.5, c: K.muted)),
          gap(10),
          for (final r in incl)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    r.$2 ? LucideIcons.check : LucideIcons.x,
                    size: 16,
                    color: r.$2 ? K.green : K.faint,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      r.$1,
                      style: tx(13.5, c: r.$2 ? K.ink : K.faint),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              const Icon(LucideIcons.star, size: 14, color: K.saffron),
              Text(' $rating', style: tx(13.5, w: bold)),
            ],
          ),
          Text(pay, style: tx(12.5, c: K.muted)),
          gap(12),
          btn(
            'اختر هذا',
            bg: best ? K.sky : K.skySoft,
            fg: best ? Colors.white : K.sky,
            wide: true,
            v: 11,
          ),
        ],
      ),
    ),
  );
  return Phone(
    children: [
      subHeader('قارن عروض التصوير', sub: 'بندك 600 ألف · 21 يناير'),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          col(
            'ضوء صنعاء',
            '550 ألف',
            const [
              ('مصورين اثنين', true),
              ('فيلم 10 دقائق', true),
              ('ألبوم مطبوع', true),
              ('تصوير جوي', false),
            ],
            '4.8 (63)',
            'يتفقون على الدفع معك مباشرة',
            best: true,
          ),
          const SizedBox(width: 10),
          col(
            'عدسة سبأ',
            '480 ألف',
            const [
              ('مصور واحد', true),
              ('فيلم 5 دقائق', true),
              ('ألبوم مطبوع', false),
              ('تصوير جوي', false),
            ],
            '4.5 (29)',
            'يتفقون على الدفع معك مباشرة',
          ),
        ],
      ),
      gap(12),
      Box(
        c: K.tealSoft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.wallet, color: K.teal, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'لما تختار، يصير بند في المال، ونطلب منهم حجز يوم عرسك.',
                style: tx(14.5, c: K.tealDark),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget vBookSheet() => Phone(
  sheet: sheet(
    title: 'نطلب الحجز؟',
    sub: 'استوديو ضوء صنعاء · صور وفيديو · 550 ألف',
    children: [
      Box(
        child: Column(
          children: [
            for (final r in const [
              (LucideIcons.calendarDays, 'الخميس 21 يناير · 13 شعبان'),
              (LucideIcons.clock, 'بعد العصر لين العشاء'),
              (LucideIcons.mapPin, 'قاعة سبأ · حدة'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(r.$1, size: 18, color: K.sky),
                    const SizedBox(width: 10),
                    Text(r.$2, style: tx(15.5, w: bold)),
                  ],
                ),
              ),
          ],
        ),
      ),
      gap(12),
      for (final s in const [
        ('1', 'يوصلهم طلب الحجز الحين، ويردون خلال يومين'),
        ('2', 'يأكدون الليلة ويحددون الفريق، وتوصلك رسالة'),
        ('3', 'يصير "محجوز"، ونذكركم قبل بأسبوع وبيوم'),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: K.skySoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  s.$1,
                  style: tx(13, w: bold, c: K.sky),
                ),
              ),
              const SizedBox(width: 10),
              Text(s.$2, style: tx(14.5)),
            ],
          ),
        ),
      gap(4),
      Box(
        c: K.saffronSoft,
        pad: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(LucideIcons.info, size: 17, color: K.saffronInk),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ما فيه دفع داخل اعّرست. الدفعة المقدمة تدفعها لهم مباشرة وتسجلها هنا، وهم يأكدون إنها وصلت.',
                style: tx(13, w: bold, c: K.saffronInk),
              ),
            ),
          ],
        ),
      ),
      gap(14),
      btn('اطلب الحجز', wide: true, v: 16, fs: 17, bg: K.sky),
    ],
  ),
  children: [subHeader('قارن عروض التصوير')],
);

Widget vChat() {
  Widget bubble(String t, bool me, String time) => Align(
    alignment: me ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 270),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: me ? K.sky : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: tx(15, c: me ? Colors.white : K.ink)),
          Text(time, style: tx(11, c: me ? Colors.white70 : K.faint)),
        ],
      ),
    ),
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text('اكتب رسالتك…', style: tx(15, c: K.faint)),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: K.sky,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.send, color: Colors.white, size: 19),
          ),
        ],
      ),
    ),
    children: [
      subHeader('استوديو ضوء صنعاء', sub: 'يرد عادة خلال ساعتين'),
      bubble(
        'السلام عليكم، نبغى تصوير زفاف يوم 21 يناير في قاعة سبأ',
        true,
        '10:12',
      ),
      bubble(
        'وعليكم السلام، مبروك مقدمًا. اليوم فاضي عندنا، أرسلنا لك العرض',
        false,
        '10:40',
      ),
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: card(border: K.sky),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                tag('وصلك عرض', K.sky, K.skySoft),
                const Spacer(),
                Text('ينتهي بعد 6 أيام', style: tx(12.5, c: K.muted)),
              ],
            ),
            gap(8),
            Text('صور وفيديو · 550,000 ر.ي صنعاء', style: tx(18, w: bold)),
            Text('نسخة 2 · أضافوا الألبوم بنفس السعر', style: tx(12.5, w: bold, c: K.saffronInk)),
            Text(
              'مصورين · فيلم 10 دقائق · ألبوم مطبوع',
              style: tx(13.5, c: K.muted),
            ),
            gap(12),
            Row(
              children: [
                Expanded(child: btn('اقبل العرض', bg: K.sky, v: 10)),
                const SizedBox(width: 8),
                Expanded(
                  child: btn('قارن', bg: K.skySoft, fg: K.sky, v: 10),
                ),
              ],
            ),
          ],
        ),
      ),
      bubble('ممكن تضيفون تصوير جوي؟', true, '11:02'),
    ],
  );
}

// ================================================================ عائلتي وحسابي

Widget vFamily() {
  Widget m(String n, String rel, String can, Color c, {String? l}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        avatar(l ?? n.characters.first, c, s: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(n, style: tx(15.5, w: bold)),
                  const SizedBox(width: 8),
                  Text(rel, style: tx(13, c: K.muted)),
                ],
              ),
              Text(can, style: tx(13, c: K.muted)),
            ],
          ),
        ),
        const Icon(LucideIcons.chevronLeft, color: K.faint, size: 18),
      ],
    ),
  );
  return Phone(
    children: [
      subHeader('المشاركين', sub: 'مين يساعدك في عرسك'),
      whiteList([
        m(
          'صالح',
          'أخوي',
          'يساعد في المهام والضيوف · ويكتب الرفد',
          K.saffronInk,
        ),
        m('الوالد', '', 'يشوف ملخص شهري بدون تفاصيل', K.teal, l: 'ع'),
        m(
          'العروسة',
          '',
          'تشوف الموعد والبرنامج · بدون المال',
          const Color(0xFF8E5A9E),
          l: 'ع',
        ),
      ]),
      gap(10),
      Box(
        c: K.tealSoft,
        pad: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.info, size: 18, color: K.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'العروسة لها خطتها لجانبها، وتقدر تضيفك فيها مشارك بنفس الطريقة. كل واحد يشوف بس اللي يسمح له الثاني.',
                style: tx(13.5, w: bold, c: K.tealDark),
              ),
            ),
          ],
        ),
      ),
      sectionTitle('أضف مشارك', action: 'من جهات الاتصال'),
      for (final r in const [
        ('مساعد', 'المهام والضيوف، والرفد إذا بغيت', LucideIcons.listChecks),
        ('أهل', 'المهام والضيوف، ويشوف المال إذا سمحت', LucideIcons.users),
        ('كاتب الرفد', 'يسجل الرفد يوم العرس بس', LucideIcons.gem),
        ('يشوف بس', 'الموعد والملخص بدون تفاصيل الفلوس', LucideIcons.eye),
      ])
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(13),
          decoration: card(r: 18),
          child: Row(
            children: [
              Icon(r.$3, color: K.teal, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.$1, style: tx(15, w: bold)),
                    Text(r.$2, style: tx(12.5, c: K.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

Widget vAccount() {
  Widget row(
    IconData i,
    String t,
    String v, {
    bool toggle = false,
    bool on = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        Icon(i, size: 20, color: K.teal),
        const SizedBox(width: 12),
        Expanded(
          child: Text(t, style: tx(15, w: bold)),
        ),
        if (toggle)
          Container(
            width: 44,
            height: 26,
            padding: const EdgeInsets.all(3),
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: on ? K.teal : K.line,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          )
        else ...[
          Text(v, style: tx(14, c: K.muted)),
          const SizedBox(width: 4),
          const Icon(LucideIcons.chevronLeft, size: 17, color: K.faint),
        ],
      ],
    ),
  );
  Widget group(String t, List<Widget> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
        child: Text(
          t,
          style: tx(14, w: bold, c: K.muted),
        ),
      ),
      whiteList(rows, dividers: false),
    ],
  );
  return Phone(
    children: [
      subHeader('حسابي'),
      Box(
        child: Row(
          children: [
            avatar('م', K.saffron, s: 54),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('محمد الحمدي', style: tx(19, w: bold)),
                  Text(ltr('777 123 456'), style: tx(14, c: K.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
      group('عرسي', [
        row(LucideIcons.calendarDays, 'موعد العرس', '21 يناير'),
        row(LucideIcons.users, 'المشاركين', '3'),
        row(LucideIcons.calendarClock, 'تأجيل العرس', ''),
      ]),
      group('شكل التطبيق', [
        row(
          LucideIcons.moon,
          'التاريخ الهجري جنب الميلادي',
          '',
          toggle: true,
          on: true,
        ),
        row(LucideIcons.hash, 'الأرقام', '123'),
        row(LucideIcons.type, 'خط كبير', '', toggle: true),
        row(LucideIcons.sunMoon, 'الوضع الليلي', 'تلقائي'),
        row(LucideIcons.image, 'توفير البيانات', '', toggle: true, on: true),
      ]),
      group('الأمان والخصوصية', [
        row(LucideIcons.eyeOff, 'أخفِ المبالغ', '', toggle: true),
        row(LucideIcons.lock, 'قفل التطبيق', 'رمز'),
        row(LucideIcons.smartphone, 'تغيير رقم الجوال', ''),
      ]),
    ],
  );
}

Widget vPostpone() => Phone(
  sheet: sheet(
    title: 'تأجيل العرس',
    sub: 'نرتب كل شيء على الموعد الجديد',
    children: [
      Row(
        children: [
          Expanded(
            child: field('كان', '21 يناير', icon: LucideIcons.calendarX),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: field(
              'صار',
              '15 أبريل',
              icon: LucideIcons.calendarCheck,
              focused: true,
            ),
          ),
        ],
      ),
      gap(8),
      Text(
        'بعد العيد · 27 شوال',
        style: tx(13.5, w: bold, c: K.teal),
      ),
      gap(14),
      Box(
        child: Column(
          children: [
            for (final r in const [
              (
                LucideIcons.listChecks,
                K.saffronInk,
                '18 مهمة تنتقل 84 يوم',
                'المنجز ما يتغير',
              ),
              (
                LucideIcons.building2,
                K.sky,
                '2 حجوزات على اليوم القديم',
                'نطلب منهم اليوم الجديد',
              ),
              (
                LucideIcons.wallet,
                K.teal,
                'الدفعات ما تتغير',
                'لأنها اتفاق مع المزود',
              ),
              (
                LucideIcons.send,
                K.lilac,
                'الضيوف',
                'نرسل لهم الموعد الجديد إذا تبغى',
              ),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Icon(r.$1, size: 19, color: r.$2),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.$3, style: tx(15, w: bold)),
                          Text(r.$4, style: tx(12.5, c: K.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      gap(14),
      btn('أجّل العرس', wide: true, v: 16, fs: 17),
    ],
  ),
  children: [subHeader('حسابي')],
);

Widget vBook() => Phone(
  gradient: const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF7F1E6), K.bg],
  ),
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
    child: Row(
      children: [
        Expanded(
          child: btn('احفظه', v: 16, fs: 17, icon: LucideIcons.download),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: btn(
            'ساعد صاحبك',
            bg: K.saffron,
            fg: K.ink,
            v: 16,
            fs: 15,
            icon: LucideIcons.gift,
          ),
        ),
      ],
    ),
  ),
  children: [
    subHeader('كتاب عرسك'),
    Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(colors: [K.teal, K.tealDark]),
      ),
      child: CustomPaint(
        painter: const QamariyaMark(alpha: 0.13, cx: 0.5),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
          child: Column(
            children: [
              Text(
                'سددت كل ديون عرسك',
                style: tx(15, w: bold, c: K.saffron),
              ),
              gap(8),
              Text(
                'عرس محمد',
                style: tx(28, w: bold, c: Colors.white),
              ),
              Text(
                '21 يناير 2027 · 13 شعبان 1448 · صنعاء',
                style: tx(13.5, c: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    ),
    gap(12),
    GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        for (final s in const [
          ('9.6 مليون', 'كلّف العرس', K.tealSoft, K.teal),
          ('118', 'ضيف حضروا', K.lilacSoft, K.lilac),
          ('1.8 مليون', 'رفد من 112 شخص', K.saffronSoft, K.saffronInk),
          ('6', 'مزودين · قيّمتهم كلهم', K.skySoft, K.sky),
        ])
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: s.$3,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  s.$1,
                  style: tx(22, w: bold, c: s.$4),
                ),
                Text(s.$2, style: tx(13, c: K.muted)),
              ],
            ),
          ),
      ],
    ),
    gap(12),
    Box(
      child: Row(
        children: [
          iconTile(LucideIcons.gift, K.saffronInk, K.saffronSoft, s: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'صاحبك بيتزوج؟ أرسل له خطتك جاهزة: البنود والأسعار والمزودين اللي عجبوك.',
              style: tx(14, c: K.muted),
            ),
          ),
        ],
      ),
    ),
  ],
);

Widget vRate() {
  Widget stars(int n, {double s = 26}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 5; i++)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(
            Icons.star_rounded,
            size: s,
            color: i < n ? K.saffron : K.line,
          ),
        ),
    ],
  );
  Widget done(String name, String what, int n) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        iconTile(LucideIcons.checkCircle2, K.green, K.greenSoft, s: 38, r: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: tx(15, w: bold)),
              Text(what, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        stars(n, s: 15),
      ],
    ),
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: btn(
        'أرسل التقييم والتالي',
        wide: true,
        v: 16,
        fs: 17,
        bg: K.saffronInk,
      ),
    ),
    children: [
      subHeader('قيّم مزودينك', sub: '2 من 6 · تقييمك يساعد العرسان الجايين'),
      Box(
        pad: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                iconTile(LucideIcons.camera, K.sky, K.skySoft, s: 46, r: 15),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('استوديو ضوء صنعاء', style: tx(17, w: bold)),
                      Text('التصوير · دفعت 550 ألف', style: tx(13, c: K.muted)),
                    ],
                  ),
                ),
              ],
            ),
            gap(16),
            Center(child: stars(4, s: 36)),
            gap(6),
            Center(
              child: Text(
                'ممتاز',
                style: tx(15, w: bold, c: K.saffronInk),
              ),
            ),
            gap(16),
            Text(
              'وش عجبك؟',
              style: tx(14, w: bold, c: K.muted),
            ),
            gap(8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                chip('التزم بالموعد', on: true, onBg: K.saffronInk),
                chip('السعر مثل الاتفاق', on: true, onBg: K.saffronInk),
                chip('شغل نظيف'),
                chip('سلّم في وقته', on: true, onBg: K.saffronInk),
                chip('أنصح فيه'),
              ],
            ),
            gap(14),
            field(
              'كلمة للعرسان الجايين (اختياري)',
              'الفيلم وصل بعد أسبوعين بالضبط',
            ),
            gap(10),
            Row(
              children: [
                const Icon(LucideIcons.lock, size: 15, color: K.muted),
                const SizedBox(width: 6),
                Text('يطلع باسمك الأول بس: محمد', style: tx(13, c: K.muted)),
              ],
            ),
          ],
        ),
      ),
      sectionTitle('قيّمتهم'),
      whiteList([done('قاعة سبأ', 'القاعة', 5)], dividers: false),
    ],
  );
}
