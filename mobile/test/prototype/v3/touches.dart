// Journey prototype v3: the touches that make aarast feel Yemeni. The groom
// abroad, regional exchange rates, who holds the cash, the moments between
// home stages, the father's view, and one search for everything.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import 'home.dart' show nextStep;

// ------------------------------------------------------------ shared bits

/// Seeded paper confetti for the celebration moments.
class _Confetti extends CustomPainter {
  const _Confetti();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    const colors = [K.saffron, Colors.white, K.tealMid, K.saffronSoft];
    for (var i = 0; i < 46; i++) {
      final p = Paint()..color = colors[i % colors.length].withValues(alpha: 0.85);
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height * 0.55;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rnd.nextDouble() * math.pi);
      if (i.isEven) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -2, 10, 4), const Radius.circular(2)),
          p,
        );
      } else {
        canvas.drawCircle(Offset.zero, 2.6, p);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Full-screen moment between home stages.
Widget _moment({
  required String eyebrow,
  required String title,
  required String sub,
  required Widget body,
  required String action,
  List<Color> colors = const [K.teal, K.tealDark],
  bool confetti = true,
}) => Phone(
  statusLight: true,
  gradient: LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: colors,
  ),
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
    child: btn(action, wide: true, v: 16, fs: 17, bg: Colors.white, fg: colors.last),
  ),
  children: [
    SizedBox(
      height: 230,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: QamariyaMark(alpha: 0.14, cx: 0.5, frieze: false)),
          ),
          if (confetti) const Positioned.fill(child: CustomPaint(painter: _Confetti())),
          Align(
            alignment: const Alignment(0, 0.55),
            child: Text(eyebrow, style: tx(15, w: bold, c: Colors.white70)),
          ),
        ],
      ),
    ),
    Center(
      child: Text(title, textAlign: TextAlign.center, style: tx(32, w: bold, c: Colors.white, h: 1.2)),
    ),
    gap(8),
    Center(
      child: Text(sub, textAlign: TextAlign.center, style: tx(15.5, c: Colors.white70, h: 1.5)),
    ),
    gap(26),
    body,
  ],
);

Widget _glassRow(IconData i, String a, String b) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    children: [
      Icon(i, size: 19, color: Colors.white),
      const SizedBox(width: 12),
      Expanded(child: Text(a, style: tx(15.5, w: bold, c: Colors.white))),
      Text(b, style: tx(14, c: Colors.white70)),
    ],
  ),
);

Widget _glass(List<Widget> rows) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
  ),
  child: Column(children: rows),
);

Widget _choice(IconData i, String t, String sub, {bool on = false}) => Container(
  margin: const EdgeInsets.only(bottom: 10),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: on ? K.teal : K.line, width: on ? 2 : 1),
  ),
  child: Row(
    children: [
      iconTile(i, on ? Colors.white : K.teal, on ? K.teal : K.tealSoft, s: 46),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t, style: tx(17, w: bold)),
            Text(sub, style: tx(13.5, c: K.muted)),
          ],
        ),
      ),
    ],
  ),
);

// ============================================================ المغترب

Widget vWhereAreYou() => questionScreen(
  step: 2,
  total: 6,
  q: 'أنت في اليمن،\nولا برا؟',
  help: 'كثير من العرسان يرتبون من الغربة، وأخوهم ينفّذ.',
  body: [
    _choice(LucideIcons.mapPin, 'في اليمن', 'أرتب بنفسي'),
    _choice(LucideIcons.plane, 'مغترب في السعودية', 'أرتب من بعيد، وأنزل قبل العرس', on: true),
    _choice(LucideIcons.globe, 'مكان ثاني', 'الإمارات، أمريكا، أي مكان'),
    gap(6),
    Box(
      c: K.tealSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('مين على الأرض؟', style: tx(15, w: bold, c: K.teal)),
          gap(10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip('صالح أخوي', on: true),
              chip('الوالد'),
              chip('واحد ثاني', icon: LucideIcons.plus),
            ],
          ),
          gap(10),
          Text('نضيفه مشارك، ونعطيه المهام اللي على الأرض.', style: tx(13, c: K.teal)),
        ],
      ),
    ),
  ],
);

Widget vExpatHome() => Phone(
  nav: Sec.home,
  children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أهلًا محمد', style: tx(24, w: bold)),
                Row(
                  children: [
                    const Icon(LucideIcons.plane, size: 14, color: K.muted),
                    const SizedBox(width: 5),
                    Text('من الرياض · عرسك في صنعاء', style: tx(14, c: K.muted)),
                  ],
                ),
              ],
            ),
          ),
          avatar('م', K.saffron, s: 44),
        ],
      ),
    ),
    gap(14),
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [K.teal, K.tealDark]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تنزل بعد 82 يوم', style: tx(22, w: bold, c: Colors.white)),
                Text('إجازتك 7 يناير · العرس بعدها بأسبوعين', style: tx(13.5, c: Colors.white70)),
              ],
            ),
          ),
          Column(
            children: [
              Text('96', style: tx(34, w: bold, c: Colors.white, h: 1)),
              Text('للعرس', style: tx(12, c: Colors.white70)),
            ],
          ),
        ],
      ),
    ),
    gap(12),
    nextStep(
      when: 'قبل الأحد',
      title: 'حوّل 3,600 ر.س لصالح',
      sub: 'تقريبًا 500,000 ر.ي · دفعة القاعة',
      why: 'لأن صالح بيدفعها عنك الخميس، والمبلغ مو عنده',
      action: 'سجّل الحوالة',
      second: 'ذكّرني',
      icon: LucideIcons.send,
    ),
    sectionTitle('صالح على الأرض', action: 'كل اللي سواه'),
    Box(
      pad: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              avatar('ص', K.saffronInk, s: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('زار قاعة سبأ وصوّرها', style: tx(15, w: bold)),
                    Text('أمس · 6 صور', style: tx(12.5, c: K.muted)),
                  ],
                ),
              ),
              softAction('شوف'),
            ],
          ),
          const Divider(height: 22, color: K.line),
          Row(
            children: [
              const Icon(LucideIcons.listChecks, size: 18, color: K.saffronInk),
              const SizedBox(width: 10),
              Expanded(child: Text('معه 4 مهام · خلّص 2 هذا الأسبوع', style: tx(14))),
              const Icon(LucideIcons.chevronLeft, size: 16, color: K.faint),
            ],
          ),
        ],
      ),
    ),
    sectionTitle('فلوسك بالعملتين'),
    Box(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ناقصك', style: tx(13.5, c: K.muted)),
                Text('2,500,000 ر.ي', style: tx(22, w: bold, c: K.coral)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('تقريبًا', style: tx(12.5, c: K.muted)),
              Text('17,900 ر.س', style: tx(19, w: bold)),
            ],
          ),
        ],
      ),
    ),
  ],
);

Widget vRemit() {
  Widget region(String c, String rate, {bool on = false}) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: on ? K.teal : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: on ? null : Border.all(color: K.line),
      ),
      child: Column(
        children: [
          Text(c, style: tx(15, w: bold, c: on ? Colors.white : K.ink)),
          Text(rate, style: tx(12.5, c: on ? Colors.white70 : K.muted)),
        ],
      ),
    ),
  );
  return Phone(
    nav: Sec.money,
    sheet: sheet(
      title: 'حوالة لصالح',
      sub: 'من الرياض إلى صنعاء',
      children: [
        amountField('كم حوّلت؟', '3,600', 'ثلاثة آلاف وستمية ريال سعودي', unit: 'ر.س'),
        gap(12),
        Text('صرفها في', style: tx(14, w: bold, c: K.muted)),
        gap(8),
        Row(
          children: [
            region('صنعاء', '1 ر.س = 140', on: true),
            const SizedBox(width: 8),
            region('عدن', '1 ر.س = 425'),
          ],
        ),
        gap(12),
        Box(
          c: K.tealSoft,
          pad: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(child: Text('يوصل صالح تقريبًا', style: tx(14.5, c: K.teal))),
              Text('504,000 ر.ي', style: tx(20, w: bold, c: K.teal)),
            ],
          ),
        ),
        gap(8),
        Row(
          children: [
            const Icon(LucideIcons.pencil, size: 14, color: K.teal),
            const SizedBox(width: 6),
            Text('صرفها بسعر ثاني؟ عدّل السعر', style: tx(13.5, w: bold, c: K.teal)),
          ],
        ),
        gap(10),
        Text('السعر يختلف بين صنعاء وعدن، فنحسب بسعر مدينة عرسك. صالح يأكد كم استلم فعلًا.',
            style: tx(13, c: K.muted, h: 1.45)),
        gap(16),
        btn('سجّل الحوالة', wide: true, v: 16, fs: 17),
      ],
    ),
    children: [tabHeader('المال', 'ماشية، بس ناقصك 2.5 مليون')],
  );
}

// ============================================================ العهدة

Widget vCustody() {
  Widget holder(String l, Color c, String name, String forWhat, double spent, String have, String sub) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Column(
      children: [
        Row(
          children: [
            avatar(l, c, s: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: tx(16, w: bold)),
                  Text(forWhat, style: tx(12.5, c: K.muted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(have, style: tx(17, w: bold)),
                Text('معه الحين', style: tx(12, c: K.muted)),
              ],
            ),
          ],
        ),
        gap(10),
        bar(spent, K.saffronInk, bg: K.saffronSoft, h: 7),
        gap(6),
        Row(
          children: [
            Expanded(child: Text(sub, style: tx(12.5, c: K.muted))),
          ],
        ),
      ],
    ),
  );
  return Phone(
    nav: Sec.money,
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: btn('سلّم كاش لأحد', wide: true, v: 15, fs: 16, icon: LucideIcons.coins),
    ),
    children: [
      subHeader('العهدة', sub: 'مين معه كاش أسبوع العرس'),
      Box(
        pad: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('طلع من يدك', style: tx(13.5, c: K.muted)),
                  Text('750,000 ر.ي', style: tx(26, w: bold)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('انصرف 390 ألف', style: tx(14, w: bold, c: K.saffronInk)),
                Text('باقي برا 360 ألف', style: tx(13, c: K.muted)),
              ],
            ),
          ],
        ),
      ),
      gap(12),
      whiteList([
        holder('ص', K.saffronInk, 'صالح', 'السمرة والمقيل', 0.65, '120,000',
            'استلم 350 ألف · صرف 230 ألف على القات والضيافة'),
        holder('ع', K.teal, 'الوالد', 'الزفاف', 0.4, '240,000',
            'استلم 400 ألف · صرف 160 ألف عربون الفرقة'),
      ]),
      gap(12),
      Box(
        c: K.greenSoft,
        pad: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(LucideIcons.checkCircle2, color: K.green),
            const SizedBox(width: 10),
            Expanded(
              child: Text('بعد العرس كل واحد يرجّع الباقي، والعهدة تتقفل.',
                  style: tx(14, w: bold, c: K.green)),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget vHandCash() => Phone(
  nav: Sec.money,
  sheet: sheet(
    title: 'سلّم كاش',
    sub: 'ينكتب عهدة باسمه لين يرجّع الباقي',
    children: [
      Row(
        children: [
          Expanded(child: chip('صالح', on: true, icon: LucideIcons.user)),
          const SizedBox(width: 8),
          Expanded(child: chip('الوالد', icon: LucideIcons.user)),
          const SizedBox(width: 8),
          Expanded(child: chip('ثاني', icon: LucideIcons.plus)),
        ],
      ),
      gap(12),
      amountField('كم؟', '350,000', 'ثلاثمية وخمسين ألف ريال'),
      gap(12),
      Text('لإيش؟', style: tx(14, w: bold, c: K.muted)),
      gap(8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('السمرة', on: true),
          chip('المقيل', on: true),
          chip('الزفاف'),
          chip('الغداء'),
        ],
      ),
      gap(12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: K.tealSoft, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            const Icon(LucideIcons.smartphone, size: 18, color: K.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text('صالح يأكد الاستلام من جواله، وأي صرف يسجله ينخصم من عهدته.',
                  style: tx(13.5, w: bold, c: K.teal, h: 1.45)),
            ),
          ],
        ),
      ),
      gap(16),
      btn('سلّمته', wide: true, v: 16, fs: 17),
    ],
  ),
  children: [subHeader('العهدة')],
);

// ============================================================ لحظات

Widget vMomentWeek() => _moment(
  eyebrow: 'الخميس 14 يناير',
  title: 'دخلت أسبوع عرسك',
  sub: 'سبعة أيام، وكل شي مرتب.\nمن اليوم الرئيسية تمشي معك ليلة ليلة.',
  action: 'وريني برنامج الأسبوع',
  confetti: false,
  body: _glass([
    _glassRow(LucideIcons.moon, 'السمرة', 'الثلاثاء · الديوان'),
    _glassRow(LucideIcons.leaf, 'المقيل', 'الأربعاء · بيت الوالد'),
    _glassRow(LucideIcons.partyPopper, 'الزفاف', 'الخميس · قاعة سبأ'),
    const Divider(color: Colors.white24, height: 16),
    _glassRow(LucideIcons.store, 'المزودين', '5 من 6 أكّدوا'),
    _glassRow(LucideIcons.wallet, 'الكاش', '750 ألف للأيام الثلاثة'),
  ]),
);

Widget vMomentDay() => _moment(
  eyebrow: 'الخميس 21 يناير · 13 شعبان',
  title: 'اليوم عرسك يا محمد',
  sub: 'بارك الله لكما، وبارك عليكما،\nوجمع بينكما في خير.',
  action: 'ابدأ يومك',
  colors: const [K.saffron, K.saffronInk],
  body: _glass([
    _glassRow(LucideIcons.soup, 'الغداء', 'الظهر · بيت الوالد'),
    _glassRow(LucideIcons.partyPopper, 'الزفاف', 'بعد العصر · قاعة سبأ'),
    _glassRow(LucideIcons.gem, 'الرفد', 'صالح يكتبه'),
  ]),
);

Widget vMomentMahr() => _moment(
  eyebrow: 'الاتفاق مع أهل العروسة',
  title: 'سلّمت المهر كامل',
  sub: 'ثلاثة مليون ريال، وصلت كلها.\nهذا الجزء من عرسك خلص، ألف مبروك.',
  action: 'تمام',
  body: Column(
    children: [
      _glass([
        _glassRow(LucideIcons.checkCircle2, 'يوم العقد', '2,000,000'),
        _glassRow(LucideIcons.checkCircle2, 'الباقي · 15 نوفمبر', '1,000,000'),
      ]),
      gap(14),
      Text('نخفي بطاقة المهر من الرئيسية، وتلقاها في المال.',
          style: tx(13.5, c: Colors.white70)),
    ],
  ),
);

Widget vMomentBooked() => _moment(
  eyebrow: 'طلب الحجز انقبل',
  title: 'فرقة الأفراح\nمحجوزة ليلتك',
  sub: 'الخميس 21 يناير · بعد العصر',
  action: 'سجّل العربون',
  colors: const [K.sky, Color(0xFF1D4E73)],
  body: Column(
    children: [
      _glass([
        _glassRow(LucideIcons.music, 'الفنان والفرقة', '400,000'),
        _glassRow(LucideIcons.calendarClock, 'العربون', '100,000 قبل أسبوع'),
      ]),
      gap(16),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 6; i++)
            Container(
              width: 34,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i < 4 ? Colors.white : Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
      gap(8),
      Text('صار محجوز 4 من 6', style: tx(14, w: bold, c: Colors.white)),
    ],
  ),
);

// ============================================================ الوالد

Widget vFatherHome() {
  Widget big(IconData i, String t, String sub, Color c, Color soft) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
    child: Row(
      children: [
        iconTile(i, c, soft, s: 54, r: 18),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: tx(19, w: bold)),
              Text(sub, style: tx(15, c: K.muted)),
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
        child: Row(
          children: [
            Expanded(child: Text('عرس محمد', style: tx(30, w: bold))),
            tag('خط كبير', K.teal, K.tealSoft),
          ],
        ),
      ),
      gap(14),
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: K.teal, borderRadius: BorderRadius.circular(26)),
        child: Column(
          children: [
            Text('بعد 96 يوم', style: tx(36, w: bold, c: Colors.white)),
            Text('الخميس 21 يناير · قاعة سبأ', style: tx(17, c: Colors.white70)),
          ],
        ),
      ),
      gap(18),
      Text('مطلوب منك', style: tx(20, w: bold)),
      gap(10),
      big(LucideIcons.phone, 'كلّم الأمين الشرعي', 'عن موعد العقد', K.saffronInk, K.saffronSoft),
      big(LucideIcons.users, 'أكّد عدد آل السقاف', 'كم بيحضر منهم؟', K.lilac, K.lilacSoft),
      gap(8),
      Text('الضيوف', style: tx(20, w: bold)),
      gap(10),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Row(
          children: [
            Text('86', style: tx(40, w: bold, c: K.lilac, h: 1)),
            const SizedBox(width: 14),
            Expanded(child: Text('أكّدوا من 124 مدعو', style: tx(18, c: K.muted))),
          ],
        ),
      ),
    ],
  );
}

// ============================================================ البحث

Widget vSearch() {
  Widget group(String t) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
    child: Text(t, style: tx(14, w: bold, c: K.muted)),
  );
  Widget hit(IconData i, Color c, Color soft, String t, String sub, {String? end}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        iconTile(i, c, soft, s: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: tx(15.5, w: bold)),
              Text(sub, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        if (end != null) Text(end, style: tx(14, w: bold, c: c)),
      ],
    ),
  );
  return Phone(
    children: [
      gap(6),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: K.teal, width: 2),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.search, size: 19, color: K.teal),
            const SizedBox(width: 10),
            Expanded(child: Text('عبدالله', style: tx(17, w: bold))),
            const Icon(LucideIcons.x, size: 18, color: K.faint),
          ],
        ),
      ),
      gap(10),
      Text('4 نتائج في كل خطتك', style: tx(13.5, c: K.muted)),
      group('الضيوف'),
      whiteList([
        hit(LucideIcons.user, K.lilac, K.lilacSoft, 'عبدالله الحمدي', 'آل الحمدي · أكّد', end: 'رفده 20,000'),
      ]),
      group('الناس'),
      whiteList([
        hit(LucideIcons.fileText, K.saffronInk, K.saffronSoft, 'الشيخ عبدالله المطري', 'الأمين الشرعي · ${ltr('771 220 914')}'),
      ]),
      group('المهام'),
      whiteList([
        hit(LucideIcons.listChecks, K.saffronInk, K.saffronSoft, 'حدد موعد عقد القران', 'فيها الأمين الشرعي · متأخرة'),
      ]),
      group('الرفد'),
      whiteList([
        hit(LucideIcons.gem, K.saffronInk, K.saffronSoft, 'عرس عبدالله الحمدي', 'ترده الخميس 14 مارس', end: '20,000'),
      ]),
    ],
  );
}
