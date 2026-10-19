// Bride journey prototype: the start questions and the home in its moments.
// Sanaa's women's wedding runs about a week: the bath, al-dhubal, the naqsh,
// the hall party, al-nasma, then the zaffa. After it: al-thalith, al-shakma
// and the seventh day.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import 'common.dart';

// ============================================================ البداية

Widget bName() => questionScreen(
  step: 0,
  total: 5,
  q: 'اسمك؟',
  help: 'واسم العريس، عشان نسمّي خطتك.',
  body: [
    field('اسمك', 'سلمى', focused: true),
    gap(10),
    field('العريس', 'محمد'),
    gap(14),
    note('خطتك خاصة فيك. ما يشوفها أحد إلا اللي تضيفينه أنتِ، حتى العريس.',
        i: LucideIcons.lock),
  ],
);

Widget bWeek() {
  Widget d(String day, String n, String name, {bool on = false, bool main = false}) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: main ? B.rose : K.line, width: main ? 2 : 1),
    ),
    child: Row(
      children: [
        SizedBox(width: 84, child: Text('$day $n', style: tx(13.5, c: K.muted))),
        Expanded(child: Text(name, style: tx(15.5, w: bold))),
        Icon(on ? LucideIcons.checkCircle2 : LucideIcons.circle, size: 20, color: on ? B.rose : K.faint),
      ],
    ),
  );
  return questionScreen(
    step: 1,
    total: 5,
    q: 'أسبوع عرسك',
    help: 'الزفة الخميس 21 يناير. رتّبنا لك الأسبوع على عادة صنعاء، شيلي اللي ما تسوونه.',
    body: [
      d('السبت', '16', 'الحمام', on: true),
      d('الأحد', '17', 'الذبال', on: true),
      d('الاثنين', '18', 'النقش', on: true),
      d('الثلاثاء', '19', 'الحفلة', on: true),
      d('الأربعاء', '20', 'النسمة', on: true),
      d('الخميس', '21', 'الزفة', on: true, main: true),
      gap(4),
      Center(child: Text('+ أضيفي يوم ثاني', style: tx(14, w: bold, c: B.rose))),
    ],
  );
}

Widget bMahr() => questionScreen(
  step: 2,
  total: 5,
  q: 'المهر',
  help: 'اللي اتفقوا عليه أهلك مع العريس. منه تجهزين.',
  body: [
    amountField('المهر', '3,000,000', 'ثلاثة مليون ريال'),
    gap(10),
    Row(
      children: [
        Expanded(child: field('استلمتوا', '2,000,000', icon: LucideIcons.checkCircle2)),
        const SizedBox(width: 8),
        Expanded(child: field('الباقي', '15 نوفمبر', icon: LucideIcons.calendarDays)),
      ],
    ),
    gap(12),
    note('نذكّرك بموعد الباقي، وما نكلّم العريس عنك. الاتصال بينكم.',
        i: LucideIcons.heartHandshake),
  ],
);

Widget bBudget() {
  Widget src(String t, String v, {bool on = true}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(on ? LucideIcons.checkCircle2 : LucideIcons.plusCircle, size: 20, color: on ? B.rose : K.faint),
        const SizedBox(width: 10),
        Expanded(child: Text(t, style: tx(15.5, w: bold, c: on ? K.ink : K.muted))),
        Text(v, style: tx(15, w: bold, c: on ? K.ink : K.faint)),
      ],
    ),
  );
  return questionScreen(
    step: 3,
    total: 5,
    q: 'من وين تجهزين؟',
    help: 'المهر غالبًا هو الأساس، ويساعد الأهل.',
    body: [
      Box(
        pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          children: [
            src('المهر', '3,000,000'),
            src('مساعدة الوالد', '1,500,000'),
            src('مدخراتي', 'أضيفي', on: false),
            src('هدايا ونقوط', 'بعدين', on: false),
          ],
        ),
      ),
      gap(12),
      Box(
        c: B.roseSoft,
        child: Row(
          children: [
            Expanded(child: Text('ميزانيتك تقريبًا', style: tx(15, c: B.roseDark))),
            Text('4,500,000 ر.ي', style: tx(22, w: bold, c: B.roseDark)),
          ],
        ),
      ),
    ],
  );
}

Widget bReady() {
  Widget r(IconData i, String t, String sub) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        iconTile(i, B.rose, B.roseSoft, s: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: tx(16, w: bold)),
              Text(sub, style: tx(13, c: K.muted)),
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: btn('ادخلي خطتك', wide: true, v: 16, fs: 17, bg: B.rose),
    ),
    children: [
      gap(30),
      Center(child: iconTile(LucideIcons.sparkles, Colors.white, B.rose, s: 80, r: 26)),
      gap(18),
      Center(child: Text('خطتك جاهزة يا سلمى', style: tx(28, w: bold))),
      gap(6),
      Center(child: Text('على أسبوع عرسك وميزانيتك', style: tx(15.5, c: K.muted))),
      gap(24),
      Box(
        child: Column(
          children: [
            r(LucideIcons.calendarHeart, '6 أيام لعرسك', 'من الحمام إلى الزفة، وبعدها الثالث والشكمة'),
            r(LucideIcons.gem, 'الذهب والجهاز والفساتين', 'بنود جاهزة، تحددين لها مبالغ'),
            r(LucideIcons.listChecks, '26 مهمة على موعدك', 'من البروفة إلى حجز المزينة'),
          ],
        ),
      ),
    ],
  );
}

// ============================================================ الرئيسية

Widget _pulse(List<(Sec, String, String, double)> t) => Row(
  children: [
    for (var i = 0; i < t.length; i++) ...[
      if (i > 0) const SizedBox(width: 8),
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(t[i].$1.icon, size: 18, color: t[i].$1.color),
              gap(6),
              Text(t[i].$2, style: tx(20, w: bold)),
              Text(t[i].$3, style: tx(11.5, c: K.muted)),
              gap(8),
              bar(t[i].$4, t[i].$1.color, h: 5),
            ],
          ),
        ),
      ),
    ],
  ],
);

Widget bHomeFresh() {
  Widget s(int n, String t, String sub, {bool done = false, bool now = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: done ? B.rose : (now ? B.roseSoft : K.bg), shape: BoxShape.circle),
          child: done
              ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
              : Text('$n', style: tx(14, w: bold, c: now ? B.rose : K.muted)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: tx(15.5, w: bold, c: done ? K.muted : K.ink)),
              Text(sub, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    nav: Sec.home,
    children: [
      brideHeader(),
      brideHero(big: '96', unit: 'يوم على زفتك', sub: 'الخميس 21 يناير · 13 شعبان', moment: 'البداية', at: 0),
      sectionTitle('نبدأ بأربع', action: '1 من 4'),
      whiteList([
        s(1, 'المهر', 'استلمتوا 2 مليون من 3', done: true),
        s(2, 'احجزي الصالة النسائية', 'تنحجز قبل بشهرين، وتحدد عدد ضيفاتك', now: true),
        s(3, 'ابدئي قائمة الجهاز', 'نعطيك قائمة جاهزة وتشيلين اللي ما تحتاجينه'),
        s(4, 'الذهب', 'طقم ولا قطع؟ بالجرام والعيار'),
      ]),
    ],
  );
}

Widget bHomeActive() => Phone(
  nav: Sec.home,
  children: [
    brideHeader(),
    brideHero(big: '62', unit: 'يوم على زفتك', sub: 'الخميس 21 يناير · 13 شعبان', moment: 'التجهيز', at: 1),
    gap(12),
    quickInput(text: 'اكتبي وش صار… مثل: اشتريت الطقم 18 جرام'),
    gap(12),
    brideNext(
      when: 'السبت',
      title: 'بروفة فستان الزفة',
      sub: 'أتيليه الأميرة · شارع جمال · 4 العصر',
      why: 'البروفة الأولى قبل شهرين، عشان التعديل يلحق',
      action: 'تمام',
      second: 'غيّري الموعد',
      icon: LucideIcons.shirt,
    ),
    gap(10),
    _pulse(const [
      (Sec.money, '2.9', 'صرفتِ من 4.5', 0.64),
      (Sec.tasks, '11', 'من 26 مهمة', 0.42),
      (Sec.guests, '96', 'أكّدن من 150', 0.64),
    ]),
    sectionTitle('بعدها'),
    whiteList([
      listRow(icon: LucideIcons.gem, fg: B.gold, soft: B.goldSoft, title: 'باقي الذهب: الخاتم والحلق', sub: 'تقريبًا 6 جرام · قبل ديسمبر'),
      listRow(icon: LucideIcons.wallet, fg: K.teal, soft: K.tealSoft, title: 'باقي المهر مليون', sub: 'موعده 15 نوفمبر'),
    ]),
  ],
);

/// The bride's wedding week: each day with its dress, who is coming and who
/// does what. One strand of lights for each day that has passed.
Widget bHomeWeek() {
  Widget day(String d, String n, String name, String dress, String sub, {bool done = false, bool today = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    child: Row(
      children: [
        Container(
          width: 54,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: today ? B.plum : (done ? K.bg : B.roseSoft),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(d, style: tx(11, c: today ? B.goldSoft : K.muted)),
              Text(n, style: tx(18, w: bold, c: today ? Colors.white : (done ? K.faint : B.rose))),
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
                  Text(name, style: tx(16, w: bold, c: done ? K.faint : K.ink)),
                  if (today) ...[const SizedBox(width: 8), tag('اليوم', B.gold, B.goldSoft)],
                ],
              ),
              Text(sub, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        Row(
          children: [
            const Icon(LucideIcons.shirt, size: 14, color: K.faint),
            const SizedBox(width: 4),
            Text(dress, style: tx(12.5, c: K.muted)),
          ],
        ),
      ],
    ),
  );
  return Phone(
    nav: Sec.home,
    children: [
      brideHeader(hello: 'أسبوعك يا سلمى'),
      brideHero(
        big: '3',
        unit: 'أيام على زفتك',
        sub: 'كل يوم ينوّر حبل · 3 من 6',
        moment: 'أسبوع العرس',
        at: 2,
        night: true,
        lit: 3,
        h: 260,
      ),
      gap(12),
      brideNext(
        when: 'اليوم 4 العصر',
        title: 'النقاشة جاية البيت',
        sub: 'أم فهد · نقش اليدين والرجلين',
        why: 'باقي لها 30 ألف تدفعينها بعد النقش',
        action: 'جهزت المبلغ',
        icon: LucideIcons.palette,
      ),
      sectionTitle('أيامك'),
      whiteList([
        day('السبت', '16', 'الحمام', 'تراثي', 'حمام الميدان · ورجعة بزفة', done: true),
        day('الأحد', '17', 'الذبال', 'من أهله', 'أهل العريس جابوا الأزياء', done: true),
        day('الاثنين', '18', 'النقش', 'أخضر', 'في البيت · النقاشة 4 العصر', today: true),
        day('الثلاثاء', '19', 'الحفلة', 'سهرة', 'صالة الياسمين · 150 ضيفة'),
        day('الأربعاء', '20', 'النسمة', 'خفيف', 'نقش ثاني وراحة في البيت'),
        day('الخميس', '21', 'الزفة', 'الأبيض', 'المزينة 10 الصبح'),
      ]),
    ],
  );
}

Widget bHomeDay() {
  Widget slot(String time, String what, String who, {bool now = false, bool done = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
    child: Row(
      children: [
        SizedBox(width: 78, child: Text(time, style: tx(13, w: bold, c: now ? B.rose : (done ? K.faint : K.ink)))),
        dot(now ? B.gold : (done ? K.line : B.rose.withValues(alpha: 0.5)), 10),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(what, style: tx(15.5, w: bold, c: done ? K.faint : K.ink)),
              Text(who, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        if (now) tag('الحين', B.gold, B.goldSoft),
      ],
    ),
  );
  return Phone(
    nav: Sec.home,
    children: [
      brideHeader(hello: 'مبروك يا عروسة'),
      brideHero(
        big: 'اليوم',
        unit: 'يوم زفتك',
        sub: '13 شعبان · الخميس',
        moment: 'يوم الزفة',
        at: 3,
        night: true,
        lit: 7,
        h: 260,
      ),
      gap(12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: B.goldSoft, borderRadius: BorderRadius.circular(22)),
        child: Row(
          children: [
            iconTile(LucideIcons.gift, Colors.white, B.gold, s: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('سجّلي هدية', style: tx(18, w: bold)),
                  Text('أختك نورة تكتبها عنك · يشتغل بدون نت', style: tx(12.5, c: K.muted)),
                ],
              ),
            ),
            Column(
              children: [
                Text('23', style: tx(18, w: bold, c: B.gold)),
                Text('هدية', style: tx(11.5, c: K.muted)),
              ],
            ),
          ],
        ),
      ),
      sectionTitle('برنامج اليوم'),
      whiteList([
        slot('10 الصبح', 'المزينة', 'صالون لمسة · في البيت', done: true),
        slot('بعد العصر', 'التصوير', 'المصورة رنا · صور خاصة لك', now: true),
        slot('بعد المغرب', 'الزفة', 'من البيت · أمك وأخواتك'),
        slot('بعد العشاء', 'إلى بيت العريس', 'مع أهلك'),
      ]),
    ],
  );
}

Widget bHomeAfter() {
  Widget p(String t, String sub, String when, {bool done = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Icon(done ? LucideIcons.checkCircle2 : LucideIcons.circle, size: 20, color: done ? B.rose : K.faint),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: tx(15.5, w: bold, c: done ? K.muted : K.ink)),
              Text(sub, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        Text(when, style: tx(12.5, c: K.muted)),
      ],
    ),
  );
  return Phone(
    nav: Sec.home,
    children: [
      brideHeader(hello: 'مبروك يا سلمى'),
      brideHero(big: '3', unit: 'أيام من زفتك', sub: 'الله يتمم عليكم بخير', moment: 'بعد العرس', at: 4),
      sectionTitle('اللي باقي'),
      whiteList([
        p('الثالث', 'حفلة عند أهل العريس', 'السبت', done: true),
        p('الشكمة', 'أمك تسويها في بيتكم', 'الاثنين'),
        p('السابع', 'أهلك يزورونك في بيتك', 'الخميس 28'),
      ]),
      gap(12),
      Row(
        children: [
          Expanded(
            child: Box(
              pad: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.heart, color: B.rose),
                  gap(6),
                  Text('اشكري المهديات', style: tx(15, w: bold)),
                  Text('23 هدية · رسالة باسم كل وحدة', style: tx(12, c: K.muted)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Box(
              pad: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.star_rounded, color: B.gold),
                  gap(6),
                  Text('قيّمي مزوداتك', style: tx(15, w: bold)),
                  Text('المزينة والمصورة والصالة', style: tx(12, c: K.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
      gap(10),
      note('فساتين التأجير: فستان الحفلة يرجع للأتيليه الأحد، والعربون 20 ألف يرجع لك.',
          c: B.gold, bg: B.goldSoft, i: LucideIcons.shirt),
    ],
  );
}
