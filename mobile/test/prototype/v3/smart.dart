// Journey prototype v3: the five tabs as one system. A change in one tab
// shows its effect on the others, and each tab gets one smart idea.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import 'home.dart' show nextStep;

// ------------------------------------------------------------ سلسلة التأثير

/// The impact strip that rises after any edit: what moved in other tabs.
Widget impactStrip(List<(IconData, String, String, Color)> steps, {String undo = 'تراجع'}) => Container(
  margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
  decoration: BoxDecoration(
    color: K.ink,
    borderRadius: BorderRadius.circular(22),
    boxShadow: [BoxShadow(color: K.ink.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8))],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Icon(LucideIcons.gitBranch, size: 17, color: K.saffron),
          const SizedBox(width: 8),
          Expanded(child: Text('وش تأثر', style: tx(14, w: bold, c: K.saffron))),
          Text(undo, style: tx(14, w: bold, c: Colors.white)),
        ],
      ),
      gap(10),
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(steps[i].$1, size: 15, color: steps[i].$4),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(steps[i].$2, style: tx(14, c: Colors.white70))),
              Text(steps[i].$3, style: tx(14.5, w: bold, c: Colors.white)),
            ],
          ),
        ),
    ],
  ),
);

Widget vImpactChain() {
  Widget g(String name, String sub, {bool fresh = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        avatar(name.characters.first, fresh ? K.saffronInk : K.lilac, s: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: tx(15.5, w: bold)),
              Text(sub, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        if (fresh) tag('جديد', K.saffronInk, K.saffronSoft),
      ],
    ),
  );
  return Phone(
    nav: Sec.guests,
    bottom: impactStrip(const [
      (LucideIcons.users, 'الضيوف', '134 بدل 124', K.lilacSoft),
      (LucideIcons.utensils, 'الضيافة', '+130 ألف', K.saffron),
      (LucideIcons.wallet, 'ناقصك', '2.63 مليون', K.coralSoft),
      (LucideIcons.building2, 'القاعة 130 · متوقع 121', 'تكفي', K.tealMid),
    ]),
    children: [
      tabHeader('الضيوف', '134 مدعو · 86 أكدوا', sec: Sec.guests, actions: [LucideIcons.search]),
      sectionTitle('آل السقاف', action: '+10 الحين', ac: K.saffronInk),
      whiteList([
        g('حسن السقاف', 'أضافه الوالد', fresh: true),
        g('علي السقاف', 'أضافه الوالد', fresh: true),
        g('محمد السقاف', 'أضافه الوالد · معه 2', fresh: true),
        g('أحمد السقاف', 'أكّد · معه واحد'),
      ]),
    ],
  );
}

// ============================================================ الرئيسية

Widget vWeeklyDigest() {
  Widget line(IconData i, Color c, Color soft, String t, String sub) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        iconTile(i, c, soft, s: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: tx(15, w: bold)),
              Text(sub, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: btn('أرسله للوالد على واتساب', wide: true, v: 16, fs: 16, bg: K.green, icon: LucideIcons.send),
    ),
    children: [
      subHeader('ملخص الجمعة', sub: 'من 12 إلى 18 أكتوبر'),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [K.teal, K.tealDark]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('أسبوع زين', style: tx(26, w: bold, c: Colors.white)),
            gap(4),
            Text('خلّصت 4 مهام، وانحجز مزود، والناقص نزل 300 ألف.',
                style: tx(14.5, c: Colors.white70, h: 1.45)),
            gap(14),
            Row(
              children: [
                for (final s in const [('4', 'مهام'), ('1', 'حجز'), ('-300', 'ألف ناقص')])
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ltr(s.$1), style: tx(24, w: bold, c: Colors.white)),
                        Text(s.$2, style: tx(12.5, c: Colors.white70)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      sectionTitle('اللي صار'),
      whiteList([
        line(LucideIcons.store, K.sky, K.skySoft, 'انحجزت فرقة الأفراح', 'الخميس 21 يناير · العربون بعد أسبوع'),
        line(LucideIcons.wallet, K.teal, K.tealSoft, 'صالح دفع للغداء 200 ألف', 'لأبو علي · من عهدته'),
        line(LucideIcons.users, K.lilac, K.lilacSoft, '12 أكدوا حضورهم', 'صاروا 86 من 124'),
      ]),
      sectionTitle('الأسبوع الجاي'),
      whiteList([
        line(LucideIcons.calendarClock, K.saffronInk, K.saffronSoft, 'حدد موعد عقد القران', 'متأخرة · كلّم الأمين الشرعي'),
        line(LucideIcons.camera, K.sky, K.skySoft, 'اختر المصور', 'عرضين ينتظرونك'),
      ]),
    ],
  );
}

// ============================================================ المال

Widget vCashflow() {
  // Projected money in hand at the end of each month, in millions.
  const months = [
    ('أكتوبر', 2.4),
    ('نوفمبر', 1.4),
    ('ديسمبر', -0.4),
    ('يناير', -2.5),
    ('فبراير', -2.2),
    ('مارس', -1.9),
  ];
  const maxAbs = 2.5;
  const up = 92.0, down = 92.0;
  Widget col((String, double) m, {bool focus = false}) {
    final v = m.$2;
    final hBar = (v.abs() / maxAbs) * (up - 22);
    final c = v >= 0 ? K.teal : K.coral;
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            height: up,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: v >= 0
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (focus || v == 2.4) Text(v.toStringAsFixed(1), style: tx(12, w: bold, c: K.ink)),
                        gap(3),
                        Container(
                          width: 20,
                          height: hBar,
                          decoration: BoxDecoration(
                            color: c,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
          Container(height: 1.5, color: K.ink.withValues(alpha: 0.35)),
          SizedBox(
            height: down,
            child: Align(
              alignment: Alignment.topCenter,
              child: v < 0
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20,
                          height: hBar,
                          decoration: BoxDecoration(
                            color: focus ? c : c.withValues(alpha: 0.45),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                          ),
                        ),
                        gap(3),
                        if (focus) Text(ltr('-0.4'), style: tx(12, w: bold, c: K.ink)),
                      ],
                    )
                  : null,
            ),
          ),
          gap(6),
          FittedBox(
            child: Text(m.$1, style: tx(12, w: focus ? bold : FontWeight.w400, c: focus ? K.ink : K.muted)),
          ),
        ],
      ),
    );
  }

  return Phone(
    nav: Sec.money,
    children: [
      tabHeader('المال', 'ماشية، بس ناقصك 2.5 مليون', actions: [LucideIcons.share2]),
      topTabs(const ['الملخص', 'البنود', 'الدفعات', 'شهر بشهر'], 3),
      gap(14),
      Box(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('اللي معك آخر كل شهر', style: tx(16, w: bold)),
            Text('بالمليون · بعد الدفعات والموعود اللي يوصل', style: tx(12.5, c: K.muted)),
            gap(14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final m in months) col(m, focus: m.$1 == 'ديسمبر'),
              ],
            ),
            gap(8),
            Row(
              children: [
                const Icon(LucideIcons.alertTriangle, size: 15, color: K.coral),
                const SizedBox(width: 6),
                Text('تحت الخط = ناقص', style: tx(12, c: K.muted)),
                const Spacer(),
                Text('يناير شهر العرس', style: tx(12, c: K.muted)),
              ],
            ),
          ],
        ),
      ),
      gap(12),
      nextStep(
        when: 'قبل ديسمبر',
        title: 'ديسمبر بيضيق عليك',
        sub: 'آخر دفعة للقاعة والضيافة في نفس الأسبوع',
        why: 'لو أجّلت دفعة الضيافة لـ 5 يناير، بعد ما توصل فلوس عادل، ديسمبر يعدّي',
        action: 'اطلب التأجيل',
        second: 'الدفعات',
        icon: LucideIcons.calendarClock,
        fg: K.coral,
        soft: K.coralSoft,
      ),
    ],
  );
}

Widget vReceiptScan() => Phone(
  nav: Sec.money,
  sheet: sheet(
    title: 'قرينا الإيصال',
    sub: 'تأكد وخلاص',
    children: [
      Container(
        height: 120,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF7EE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: K.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('فرقة الأفراح', style: tx(15, w: bold)),
                  gap(6),
                  for (final w in const [0.8, 0.6, 0.7]) ...[
                    FractionallySizedBox(
                      widthFactor: w,
                      child: Container(height: 5, color: K.line),
                    ),
                    gap(6),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: K.teal, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('100,000', style: tx(16, w: bold, c: K.teal)),
            ),
          ],
        ),
      ),
      gap(12),
      Box(
        pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (final r in const [
              ('المبلغ', '100,000 ر.ي', true),
              ('لمين', 'فرقة الأفراح · العربون', true),
              ('متى', '24 أكتوبر', true),
              ('من وين', 'مدخراتي', false),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    SizedBox(width: 64, child: Text(r.$1, style: tx(14, c: K.muted))),
                    Expanded(child: Text(r.$2, style: tx(15, w: bold))),
                    Icon(r.$3 ? LucideIcons.sparkles : LucideIcons.pencil,
                        size: 15, color: r.$3 ? K.teal : K.faint),
                  ],
                ),
              ),
          ],
        ),
      ),
      gap(6),
      Row(
        children: [
          const Icon(LucideIcons.sparkles, size: 14, color: K.teal),
          const SizedBox(width: 6),
          Text('قريناها من الإيصال · "من وين" اخترها أنت', style: tx(12.5, c: K.muted)),
        ],
      ),
      gap(14),
      btn('سجّل الدفعة', wide: true, v: 16, fs: 17),
    ],
  ),
  children: [tabHeader('المال', 'ماشية، بس ناقصك 2.5 مليون')],
);

// ============================================================ المهام

Widget vSmartTasks() {
  Widget t(String title, String meta, {String? badge, Color bc = K.sky, Color bb = K.skySoft, bool locked = false, String who = 'م', Color wc = K.teal}) =>
      Padding(
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
                color: locked ? K.bg : null,
                border: Border.all(color: K.line, width: 2),
              ),
              child: locked ? const Icon(LucideIcons.lock, size: 12, color: K.faint) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: tx(15.5, w: bold, c: locked ? K.faint : K.ink)),
                  Text(meta, style: tx(12.5, c: K.muted)),
                  if (badge != null) ...[
                    gap(6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: bb, borderRadius: BorderRadius.circular(9)),
                      child: Text(badge, style: tx(12, w: bold, c: bc)),
                    ),
                  ],
                ],
              ),
            ),
            avatar(who, wc),
          ],
        ),
      );
  return Phone(
    nav: Sec.tasks,
    children: [
      tabHeader('المهام', '6 هذا الشهر · 2 متأخرة', sec: Sec.tasks, actions: [LucideIcons.plus]),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: K.saffronSoft, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            const Icon(LucideIcons.scale, color: K.saffronInk),
            const SizedBox(width: 10),
            Expanded(
              child: Text('صالح عنده 7 مهام والوالد وحدة. تحوّل للوالد اثنتين؟',
                  style: tx(14, w: bold, c: K.saffronInk, h: 1.45)),
            ),
            const SizedBox(width: 8),
            btn('وزّعها', bg: K.saffronInk, v: 8, fs: 13),
          ],
        ),
      ),
      sectionTitle('هذا الأسبوع'),
      whiteList([
        t('ادفع عربون فرقة الأفراح', '100 ألف · قبل 25 أكتوبر',
            badge: 'جات لحالها من المزودين'),
        t('أكّد عدد الضيافة', '112 متوقع · قبل نوفمبر',
            badge: 'جات لحالها من الضيوف', bc: K.lilac, bb: K.lilacSoft),
        t('حجز سيارات الزفة', 'لصالح', who: 'ص', wc: K.saffronInk),
      ]),
      sectionTitle('تنتظر غيرها'),
      whiteList([
        t('أرسل الدعوات', 'تنفتح لما تحدد موعد عقد القران', locked: true,
            badge: 'تنتظر: حدد موعد عقد القران', bc: K.muted, bb: K.bg),
      ]),
    ],
  );
}

// ============================================================ الضيوف

Widget vAttendance() {
  Widget seg(int n, Color c, String label) => Expanded(
    flex: n,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 14, margin: const EdgeInsets.only(left: 2), color: c),
        gap(6),
        Text('$n', style: tx(15, w: bold)),
        Text(label, style: tx(11.5, c: K.muted)),
      ],
    ),
  );
  return Phone(
    nav: Sec.guests,
    children: [
      tabHeader('الضيوف', '124 مدعو · 86 أكدوا', sec: Sec.guests, actions: [LucideIcons.search]),
      Box(
        pad: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('كم بيحضر فعلًا؟', style: tx(14, c: K.muted)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('112', style: tx(44, w: bold, c: K.lilac, h: 1)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('تقريبًا مع المرافقين', style: tx(15, w: bold)),
                ),
              ],
            ),
            gap(16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  seg(86, K.lilac, 'أكدوا'),
                  seg(20, K.lilac.withValues(alpha: 0.45), 'ما ردّوا'),
                  seg(18, K.line, 'اعتذروا'),
                ],
              ),
            ),
            gap(14),
            Text('86 أكدوا ومعهم 16 مرافق، ومن اللي ما ردّوا يجي عادة النص تقريبًا.',
                style: tx(13, c: K.muted, h: 1.5)),
          ],
        ),
      ),
      gap(12),
      nextStep(
        when: 'قبل نوفمبر',
        title: 'اطلب الضيافة لـ 118 مو 124',
        sub: '112 متوقع، و6 احتياط',
        why: 'تقريبًا 75 ألف توفير، وعندك احتياط لو جوا زيادة',
        action: 'عدّل العدد',
        second: 'خلّه',
        icon: LucideIcons.utensils,
        fg: K.lilac,
        soft: K.lilacSoft,
      ),
      gap(10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: K.tealSoft, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            const Icon(LucideIcons.building2, size: 19, color: K.teal),
            const SizedBox(width: 10),
            Expanded(child: Text('القاعة 130 · تكفي ومعك 18 كرسي', style: tx(14, w: bold, c: K.teal))),
          ],
        ),
      ),
    ],
  );
}

// ============================================================ المزودين

Widget vAgreement() {
  Widget term(String s, {bool open = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(open ? LucideIcons.helpCircle : LucideIcons.checkCircle2,
            size: 18, color: open ? K.saffronInk : K.green),
        const SizedBox(width: 10),
        Expanded(child: Text(s, style: tx(15, h: 1.45))),
      ],
    ),
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: Row(
        children: [
          Expanded(child: btn('افتحه يوم العرس', bg: K.sky, v: 15, fs: 15, icon: LucideIcons.fileText)),
          const SizedBox(width: 8),
          btn('شارك', bg: K.skySoft, fg: K.sky, v: 15, fs: 15),
        ],
      ),
    ),
    children: [
      subHeader('اللي اتفقنا عليه', sub: 'فرقة الأفراح · الخميس 21 يناير'),
      Box(
        c: K.greenSoft,
        pad: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(LucideIcons.shieldCheck, color: K.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text('الفرقة أكّدت هذي النقاط من حسابها · 18 أكتوبر',
                  style: tx(14, w: bold, c: K.green)),
            ),
          ],
        ),
      ),
      gap(12),
      Box(
        pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          children: [
            term('من 4 العصر لين المغرب، في قاعة سبأ'),
            term('فنان واحد وأربعة عازفين، مع الطبل والمزمار'),
            term('السعر 400 ألف: عربون 100، والباقي يوم العرس'),
            term('لو تأخروا أكثر من نص ساعة، ينخصم 50 ألف'),
            term('الصوتيات من القاعة ولا منهم؟', open: true),
          ],
        ),
      ),
      gap(10),
      Row(
        children: [
          const Icon(LucideIcons.sparkles, size: 14, color: K.sky),
          const SizedBox(width: 6),
          Expanded(
            child: Text('طلّعناها من محادثتكم. النقطة الأخيرة ما اتفقتوا عليها بعد.',
                style: tx(12.5, c: K.muted)),
          ),
        ],
      ),
      gap(8),
      Center(child: softAction('اسألهم عن الصوتيات', fg: K.saffronInk, bg: K.saffronSoft)),
    ],
  );
}
