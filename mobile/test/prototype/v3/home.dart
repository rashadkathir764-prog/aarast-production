// Journey prototype v3: the home tab, men's and women's weddings side by side.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import '../c_journey/screens_home.dart' show hero, homeHeader;

const hijriSub = 'الخميس 21 يناير · 13 شعبان';

/// The next step card with a side marker and a "why" line.
Widget nextStep({
  required String when,
  required String title,
  required String sub,
  required String why,
  required String action,
  String? second,
  IconData icon = LucideIcons.calendarDays,
  Color fg = K.saffronInk,
  Color soft = K.saffronSoft,
  Color actionBg = K.teal,
}) => Box(
  pad: const EdgeInsets.all(18),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      iconTile(icon, fg, soft, s: 48, r: 16),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الخطوة الجاية · $when',
              style: tx(13, w: bold, c: fg),
            ),
            gap(4),
            Text(title, style: tx(18.5, w: bold)),
            Text(sub, style: tx(14, c: K.muted)),
            gap(8),
            Row(
              children: [
                const Icon(LucideIcons.sparkles, size: 14, color: K.teal),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    why,
                    style: tx(12.5, w: bold, c: K.teal),
                  ),
                ),
              ],
            ),
            gap(14),
            Row(
              children: [
                btn(action, bg: actionBg),
                if (second != null) ...[
                  const SizedBox(width: 10),
                  btn(second, bg: K.bg, fg: K.muted),
                ],
              ],
            ),
          ],
        ),
      ),
    ],
  ),
);

Widget _mahrLine() => Box(
  pad: const EdgeInsets.fromLTRB(14, 12, 14, 12),
  child: Row(
    children: [
      iconTile(LucideIcons.heartHandshake, K.teal, K.tealSoft, s: 40, r: 13),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الاتفاق مع أهل العروسة', style: tx(12.5, c: K.muted)),
            Text(
              'سلّمت 2 من 3 مليون · الباقي 15 نوفمبر',
              style: tx(14, w: bold),
            ),
          ],
        ),
      ),
      SizedBox(width: 54, child: bar(0.67, K.teal, h: 6)),
    ],
  ),
);

Widget moneyTile3() => Container(
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
          const Icon(LucideIcons.eyeOff, size: 17, color: K.muted),
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
                  '2.5 مليون ر.ي',
                  style: tx(28, w: bold, c: K.coral),
                ),
                Text(
                  'وإذا وصل الموعود: 1.3',
                  style: tx(13, w: bold, c: K.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('باقي تدفع 5.4', style: tx(14, w: bold)),
              Text(
                'معك 2.9',
                style: tx(14, w: bold, c: K.teal),
              ),
              Text(
                'موعود 1.2',
                style: tx(14, w: bold, c: K.lilac),
              ),
            ],
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
              Expanded(flex: 46, child: Container(color: K.teal)),
              const SizedBox(width: 3),
              Expanded(flex: 29, child: Container(color: K.tealMid)),
              const SizedBox(width: 3),
              Expanded(
                flex: 12,
                child: Container(color: const Color(0xFFB9A8DA)),
              ),
              const SizedBox(width: 3),
              Expanded(flex: 13, child: Container(color: K.coral)),
            ],
          ),
        ),
      ),
      gap(12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.target, size: 16, color: K.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'حط 450 ألف كل شهر، ومع الموعود تقفل الناقص قبل العرس',
                style: tx(13.5, w: bold, c: K.tealDark),
              ),
            ),
          ],
        ),
      ),
    ],
  ),
);

Widget pulse3() {
  Widget tile(Sec s, String big, String small, String two, double v) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: s.soft,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(s.icon, size: 16, color: s.color),
                  const SizedBox(width: 5),
                  Text(
                    s.label,
                    style: tx(13.5, w: bold, c: s.color),
                  ),
                ],
              ),
              gap(8),
              Text(big, style: tx(23, w: bold)),
              Text(small, style: tx(12.5, c: K.muted)),
              Text(
                two,
                style: tx(12, w: bold, c: s.color),
              ),
              gap(8),
              bar(v, s.color, bg: Colors.white.withValues(alpha: 0.8), h: 5),
            ],
          ),
        ),
      );
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      tile(Sec.tasks, '12', 'من 30 مهمة', '1 متأخرة', 0.4),
      const SizedBox(width: 8),
      tile(Sec.guests, '86', 'أكدوا من 124', '20 ما ردّوا', 0.69),
      const SizedBox(width: 8),
      tile(Sec.providers, '3', 'محجوز من 6', 'عرضين ينتظرونك', 0.5),
    ],
  );
}

Widget upcoming3() => whiteList([
  listRow(
    icon: LucideIcons.camera,
    fg: K.sky,
    soft: K.skySoft,
    title: 'التصوير: وصلك عرضين',
    sub: 'السبت · العرضين ينتهون بعد 6 أيام',
    trailing: softAction('قارن'),
  ),
  listRow(
    icon: LucideIcons.users,
    fg: K.lilac,
    soft: K.lilacSoft,
    title: '20 ضيف ما ردّوا',
    sub: 'الأحد · تذكير على واتساب',
    trailing: softAction('ذكّرهم'),
  ),
  listRow(
    icon: LucideIcons.heartHandshake,
    fg: K.teal,
    soft: K.tealSoft,
    title: 'باقي المهر: مليون',
    sub: '15 نوفمبر · لأهل العروسة',
    trailing: softAction('ذكّرني'),
  ),
], dividers: false);

// ---------------------------------------------------------------- screens

Widget vHomeFresh() {
  Widget step(
    int i,
    IconData ic,
    Color fg,
    Color soft,
    String title,
    String sub, {
    bool done = false,
    bool now = false,
    Side? side,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: card(
      c: now ? Colors.white : Colors.white.withValues(alpha: 0.65),
      border: now ? K.teal : null,
    ),
    child: Row(
      children: [
        done
            ? Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: K.green,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(LucideIcons.check, color: Colors.white),
              )
            : iconTile(ic, fg, soft, s: 46, r: 15),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    done ? 'خلصت · الخطوة $i' : 'الخطوة $i',
                    style: tx(12.5, w: bold, c: done ? K.green : K.muted),
                  ),
                  if (side != null) ...[
                    const SizedBox(width: 6),
                    sideTag(side),
                  ],
                ],
              ),
              Text(
                title,
                style: tx(16.5, w: bold, c: done ? K.muted : K.ink),
              ),
              Text(sub, style: tx(13, c: K.muted)),
            ],
          ),
        ),
        if (now) btn('كمّل', v: 10),
      ],
    ),
  );
  return Phone(
    nav: Sec.home,
    children: [
      homeHeader(),
      hero(at: 0, big: '96', unit: 'يوم على عرسك', sub: hijriSub),
      gap(22),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text('أربع خطوات وعرسك منظم', style: tx(22, w: bold)),
      ),
      gap(8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            Text(
              'خلصت 2 من 4',
              style: tx(14, w: bold, c: K.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: segments(
                4,
                2,
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
        K.teal,
        K.tealSoft,
        'ميزانيتك',
        '10 مليون: 3 للاتفاق و7 لعرسك',
        done: true,
      ),
      step(
        2,
        LucideIcons.heartHandshake,
        K.teal,
        K.tealSoft,
        'المهر',
        '3 مليون لأهل العروسة · سلّمت 2',
        done: true,
      ),
      step(
        3,
        LucideIcons.building2,
        K.sky,
        K.skySoft,
        'القاعة',
        'أهم حجز، والقاعات تمتلي قبل رمضان',
        now: true,
      ),
      step(
        4,
        LucideIcons.users,
        K.lilac,
        K.lilacSoft,
        'ضيوفك',
        'من جهات الاتصال بضغطة',
      ),
    ],
  );
}

Widget vHomeActive() => Phone(
  nav: Sec.home,
  children: [
    homeHeader(),
    hero(at: 1, big: '96', unit: 'يوم على عرسك', sub: hijriSub),
    gap(12),
    quickInput(),
    gap(12),
    nextStep(
      when: 'بعد 5 أيام',
      title: 'دفعة القاعة: 500,000 ر.ي',
      sub: 'قاعة سبأ · الدفعة الثانية من ثلاث',
      why: 'لأن موعدها قريب، والمبلغ في مدخراتك',
      action: 'سجّل الدفعة',
      second: 'ذكّرني',
    ),
    gap(10),
    _mahrLine(),
    gap(10),
    moneyTile3(),
    gap(10),
    pulse3(),
    sectionTitle('بعدها'),
    upcoming3(),
  ],
);

Widget vQuickEntry() => Phone(
  nav: Sec.home,
  sheet: sheet(
    title: 'فهمتك',
    sub: 'راجع وأكّد، أو عدّل اللي غلط',
    children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: K.teal, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'دفعت للمصور عربون 150 ألف من مدخراتي',
                style: tx(16, w: bold),
              ),
            ),
            const Icon(LucideIcons.mic, size: 18, color: K.teal),
          ],
        ),
      ),
      gap(14),
      Box(
        child: Column(
          children: [
            Row(
              children: [
                iconTile(LucideIcons.wallet, K.teal, K.tealSoft, s: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'دفعة جديدة',
                        style: tx(13, w: bold, c: K.teal),
                      ),
                      Text('150,000 ر.ي', style: tx(24, w: bold)),
                      Text('مية وخمسين ألف ريال', style: tx(13, c: K.muted)),
                    ],
                  ),
                ),
              ],
            ),
            gap(12),
            for (final r in const [
              ('البند', 'التصوير'),
              ('المزود', 'استوديو ضوء صنعاء'),
              ('النوع', 'عربون'),
              ('من وين', 'مدخراتي'),
              ('متى', 'اليوم'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(r.$1, style: tx(14, c: K.muted)),
                    ),
                    Expanded(
                      child: Text(r.$2, style: tx(15, w: bold)),
                    ),
                    const Icon(LucideIcons.pencil, size: 15, color: K.faint),
                  ],
                ),
              ),
          ],
        ),
      ),
      gap(14),
      btn('تمام، احفظها', wide: true, v: 16, fs: 17),
    ],
  ),
  children: [
    homeHeader(),
    hero(at: 1, big: '96', unit: 'يوم على عرسك', sub: hijriSub),
  ],
);

Widget vHomeWeek() {
  Widget day(
    String d,
    String n,
    String name,
    String place,
    String time, {
    bool today = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: today ? K.teal : K.tealSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                d,
                style: tx(12, w: bold, c: today ? Colors.white : K.muted),
              ),
              Text(
                n,
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
                  Text(name, style: tx(16, w: bold)),
                  if (today) ...[
                    const SizedBox(width: 8),
                    tag('الليلة', K.saffronInk, K.saffronSoft),
                  ],
                ],
              ),
              Text('$place · $time', style: tx(13, c: K.muted)),
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    nav: Sec.home,
    children: [
      homeHeader(hello: 'باقي يومين يا محمد'),
      hero(at: 2, big: '2', unit: 'يوم على عرسك', sub: hijriSub),
      gap(12),
      nextStep(
        when: 'اليوم',
        title: 'فرقة الأفراح ما أكّدت',
        sub: 'أرسل لهم تأكيد الموعد على واتساب',
        why: 'آخر مزود ما أكّد، والعرس بعد يومين',
        action: 'أرسل التأكيد',
        icon: LucideIcons.music,
        fg: K.sky,
        soft: K.skySoft,
      ),
      sectionTitle('برنامج الأسبوع', action: 'تعديل'),
      whiteList([
        day('الثلاثاء', '19', 'السمرة', 'الديوان', 'بعد العشاء', today: true),
        day('الأربعاء', '20', 'المقيل', 'بيت الوالد', 'بعد الظهر'),
        day('الخميس', '21', 'الزفاف', 'قاعة سبأ', 'بعد العصر'),
      ]),
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
                  'القاعة، التصوير، الضيافة، الغداء',
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
                    '750,000 ر.ي',
                    style: tx(26, w: bold, c: K.teal),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('السمرة 100 ألف', style: tx(13, c: K.muted)),
                Text('المقيل 250 ألف', style: tx(13, c: K.muted)),
                Text('الزفاف 400 ألف', style: tx(13, c: K.muted)),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

Widget vHomeDay() {
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
          width: 74,
          child: Text(
            time,
            style: tx(13, w: bold, c: now ? K.teal : (done ? K.faint : K.ink)),
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
    children: [
      homeHeader(hello: 'مبروك يا عريس'),
      hero(at: 3, big: 'اليوم', bigSize: 46, unit: 'يوم عرسك', sub: '13 شعبان'),
      gap(12),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: K.saffron,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
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
                    'يشتغل بدون نت · يكتب معك صالح',
                    style: tx(13.5, c: K.ink.withValues(alpha: 0.7)),
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
              'الظهر',
              'الغداء',
              'بيت الوالد · أبو علي',
              done: true,
            ),
            slot(
              'بعد العصر',
              'المقيل',
              'الديوان · القات عند أخوك صالح',
              now: true,
            ),
            slot('بعد المغرب', 'الزفة', 'قاعة سبأ · فرقة الأفراح'),
            slot('بعد العشاء', 'العشاء', 'قاعة سبأ · ضيافة الأصالة'),
          ],
        ),
      ),
    ],
  );
}

Widget vRafd() => Phone(
  nav: Sec.home,
  sheet: sheet(
    title: 'سجّل رفد',
    sub: 'ينحفظ في جوالك، ويوصل لما يرجع النت',
    children: [
      field('من؟', 'عبدالله الحمدي', icon: LucideIcons.user),
      gap(10),
      amountField('كم؟', '20,000', 'عشرين ألف ريال'),
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
      gap(8),
      numPad(),
      gap(10),
      btn(
        'حفظ وسجّل التالي',
        wide: true,
        v: 16,
        fs: 17,
        bg: K.saffron,
        fg: K.ink,
      ),
    ],
  ),
  children: [homeHeader(hello: 'مبروك يا عريس')],
);

Widget vHomeAfter() => Phone(
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
    gap(12),
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFCEFD8), Color(0xFFF8E6EE)],
        ),
      ),
      child: Row(
        children: [
          iconTile(
            LucideIcons.heartHandshake,
            K.saffronInk,
            Colors.white,
            s: 50,
            r: 16,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اشكر اللي رفدوك', style: tx(18, w: bold)),
                Text(
                  '112 شخص · رسالة شكر باسم كل واحد على واتساب',
                  style: tx(13, c: K.muted),
                ),
              ],
            ),
          ),
          btn('اشكرهم', bg: K.saffronInk, v: 10),
        ],
      ),
    ),
    gap(12),
    nextStep(
      when: 'بعد 9 أيام',
      title: 'قسط خالك: 150,000 ر.ي',
      sub: 'القسط 3 من 4 · سلفة العرس',
      why: 'أقرب قسط عليك',
      action: 'سجّل السداد',
      icon: LucideIcons.wallet,
      fg: K.teal,
      soft: K.tealSoft,
    ),
    Box(
      child: Row(
        children: [
          iconTile(LucideIcons.star, K.saffronInk, K.saffronSoft, s: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('قيّم مزودينك', style: tx(16, w: bold)),
                Text(
                  '6 مزودين · تقييمك يساعد العرسان الجايين',
                  style: tx(13, c: K.muted),
                ),
              ],
            ),
          ),
          btn('قيّم', bg: K.saffronInk, v: 10),
        ],
      ),
    ),
    sectionTitle('الرفد', action: 'الدفتر'),
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
                Text('من 112 شخص', style: tx(12.5, c: K.muted)),
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
                Text('ترده قريب', style: tx(14, c: K.muted)),
                Text('عرس سالم', style: tx(22, w: bold)),
                Text('رفدك 20 ألف · الشهر الجاي', style: tx(12.5, c: K.muted)),
              ],
            ),
          ),
        ),
      ],
    ),
    gap(12),
    Box(
      child: Row(
        children: [
          iconTile(LucideIcons.bookOpen, K.teal, K.tealSoft, s: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('كتاب عرسك', style: tx(16, w: bold)),
                Text('يجهز لما تسدد آخر قسط', style: tx(13, c: K.muted)),
              ],
            ),
          ),
          segments(
            4,
            2,
            on: K.teal,
            now: K.saffron,
          ).let((w) => SizedBox(width: 70, child: w)),
        ],
      ),
    ),
  ],
);

extension _Let on Widget {
  Widget let(Widget Function(Widget) f) => f(this);
}

Widget vNotifications() {
  Widget n(
    IconData i,
    Color fg,
    Color bg,
    String t,
    String s,
    String when, {
    bool unread = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        iconTile(i, fg, bg, s: 40, r: 13),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: tx(15, w: bold)),
              Text(s, style: tx(13, c: K.muted)),
              Text(when, style: tx(12, c: K.faint)),
            ],
          ),
        ),
        if (unread) dot(K.coral),
      ],
    ),
  );
  return Phone(
    children: [
      subHeader(
        'التنبيهات',
        trailing: Text(
          'قراءة الكل',
          style: tx(14, w: bold, c: K.teal),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
        child: Text(
          'اليوم',
          style: tx(14, w: bold, c: K.muted),
        ),
      ),
      whiteList([
        n(
          LucideIcons.camera,
          K.sky,
          K.skySoft,
          'وصلك عرض تصوير ثاني',
          'عدسة سبأ · 480 ألف',
          'قبل ساعة',
          unread: true,
        ),
        n(
          LucideIcons.checkCircle2,
          K.saffronInk,
          K.saffronSoft,
          'صالح خلّص مهمتين',
          'استلم البدلة · رتّب الغداء',
          'قبل 3 ساعات',
          unread: true,
        ),
        n(
          LucideIcons.calendarClock,
          K.saffronInk,
          K.saffronSoft,
          'دفعة القاعة بعد 5 أيام',
          '500,000 ر.ي · قاعة سبأ',
          'الصبح',
        ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
        child: Text(
          'هذا الأسبوع',
          style: tx(14, w: bold, c: K.muted),
        ),
      ),
      whiteList([
        n(
          LucideIcons.checkCircle2,
          K.green,
          K.greenSoft,
          'قاعة سبأ أكدت حجز 21 يناير',
          'محجوز · بدون أي دفع داخل التطبيق',
          'الاثنين',
        ),
        n(
          LucideIcons.moon,
          K.saffronInk,
          K.saffronSoft,
          'جمعة مباركة',
          'هذا الأسبوع: دفعة وحدة، و3 مهام، و5 ضيوف ردّوا',
          'الجمعة',
        ),
      ]),
      gap(12),
      Box(
        c: K.tealSoft,
        pad: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(LucideIcons.lock, size: 17, color: K.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'على شاشة القفل تطلع بدون أسماء ولا مبالغ.',
                style: tx(13.5, w: bold, c: K.tealDark),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

/// The Android home screen with the countdown widget.
Widget vWidget() {
  Widget app(Color c, IconData i, String l) => Column(
    children: [
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(i, color: Colors.white, size: 26),
      ),
      gap(6),
      Text(l, style: tx(12, c: Colors.white)),
    ],
  );
  return Phone(
    statusLight: true,
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF3A4E63), Color(0xFF1E2A36)],
    ),
    children: [
      gap(30),
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [K.teal, K.tealDark],
          ),
        ),
        child: CustomPaint(
          painter: const QamariyaMark(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    wordmark(s: 16, c: Colors.white),
                    const Spacer(),
                    Text('13 شعبان', style: tx(13, c: Colors.white70)),
                  ],
                ),
                gap(8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '96',
                      style: tx(54, w: bold, c: Colors.white, h: 0.95),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        'يوم على عرسك',
                        style: tx(17, w: bold, c: Colors.white),
                      ),
                    ),
                  ],
                ),
                gap(12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.calendarDays,
                        size: 17,
                        color: K.saffron,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'دفعة القاعة بعد 5 أيام',
                          style: tx(14.5, w: bold, c: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      gap(40),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          app(const Color(0xFF25D366), LucideIcons.messageCircle, 'واتساب'),
          app(const Color(0xFF5B6CFF), LucideIcons.camera, 'الكاميرا'),
          app(K.teal, LucideIcons.heart, 'اعّرست'),
          app(const Color(0xFFF2A93B), LucideIcons.calendarDays, 'التقويم'),
        ],
      ),
      gap(26),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          app(const Color(0xFF3C8DFF), LucideIcons.phone, 'الهاتف'),
          app(const Color(0xFFE2574C), LucideIcons.image, 'الصور'),
          app(const Color(0xFF7A8794), LucideIcons.settings, 'الإعدادات'),
          app(const Color(0xFF2E8A5E), LucideIcons.music, 'الموسيقى'),
        ],
      ),
    ],
  );
}

/// Night mode: the same home in the dark palette.
Widget vDarkHome() {
  const bg = Color(0xFF0E1817);
  const surf = Color(0xFF172322);
  const ink = Color(0xFFE8F1EF);
  const muted = Color(0xFF9DB0AB);
  const teal = Color(0xFF3FB3A9);
  Widget tile(String l, String b, String s, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l,
            style: tx(13.5, w: bold, c: c),
          ),
          gap(6),
          Text(
            b,
            style: tx(22, w: bold, c: ink),
          ),
          Text(s, style: tx(12, c: muted)),
          gap(8),
          bar(0.5, c, bg: const Color(0xFF243331), h: 5),
        ],
      ),
    ),
  );
  return Phone(
    bg: bg,
    statusLight: true,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مساء الخير يا محمد',
                    style: tx(24, w: bold, c: ink),
                  ),
                  Text('عرس محمد وسلمى · صنعاء', style: tx(14, c: muted)),
                ],
              ),
            ),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: surf,
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.moon, size: 20, color: K.saffron),
            ),
          ],
        ),
      ),
      Container(
        margin: const EdgeInsets.only(top: 18),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF0B5A56), Color(0xFF062F2C)],
          ),
        ),
        child: CustomPaint(
          painter: const QamariyaMark(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '96',
                      style: tx(64, w: bold, c: Colors.white, h: 0.95),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'يوم على عرسك',
                              style: tx(18, w: bold, c: Colors.white),
                            ),
                            Text(hijriSub, style: tx(14, c: Colors.white70)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                gap(16),
                segments(
                  5,
                  1,
                  on: Colors.white,
                  now: K.saffron,
                  off: Colors.white.withValues(alpha: 0.18),
                ),
              ],
            ),
          ),
        ),
      ),
      gap(12),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الخطوة الجاية · بعد 5 أيام',
              style: tx(13, w: bold, c: K.saffron),
            ),
            gap(4),
            Text(
              'دفعة القاعة: 500,000 ر.ي',
              style: tx(18.5, w: bold, c: ink),
            ),
            Text('قاعة سبأ · الدفعة الثانية من ثلاث', style: tx(14, c: muted)),
            gap(14),
            btn('سجّل الدفعة', bg: teal, fg: bg),
          ],
        ),
      ),
      gap(12),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ناقصك', style: tx(14, c: muted)),
                  Text(
                    '2.5 مليون ر.ي',
                    style: tx(26, w: bold, c: const Color(0xFFEF8A72)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'باقي تدفع 5.4',
                  style: tx(14, w: bold, c: ink),
                ),
                Text(
                  'معك 2.9',
                  style: tx(14, w: bold, c: teal),
                ),
              ],
            ),
          ],
        ),
      ),
      gap(10),
      Row(
        children: [
          tile('المهام', '12', 'من 30', const Color(0xFFF2B75A)),
          const SizedBox(width: 8),
          tile('الضيوف', '86', 'من 124', const Color(0xFFA993D6)),
          const SizedBox(width: 8),
          tile('المزودين', '3', 'من 6', const Color(0xFF7FB3DC)),
        ],
      ),
    ],
  );
}
