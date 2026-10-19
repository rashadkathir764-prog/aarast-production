// Bride journey prototype: money (gold by the gram, the trousseau, the
// dresses of the week, gifts), tasks and beauty appointments, women guests,
// women providers, and who sees what in her private plan.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import '../v3/lights.dart' show Lights;
import 'common.dart';

// Same money tabs as the groom; gold, the trousseau and the outfits open as
// item details from the items list.
Widget _moneyTabs(int i) => topTabs(const ['الملخص', 'البنود', 'الدفعات', 'من وين'], i);

// ============================================================ المال

Widget bMoney() {
  Widget g(IconData i, Color c, Color soft, String t, String sub, double v, String amt) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Column(
      children: [
        Row(
          children: [
            iconTile(i, c, soft, s: 38),
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
            Text(amt, style: tx(15, w: bold)),
          ],
        ),
        gap(8),
        bar(v, c, h: 6),
      ],
    ),
  );
  return Phone(
    nav: Sec.money,
    children: [
      tabHeader('المال', 'ماشية، ومعك 600 ألف', actions: [LucideIcons.eyeOff]),
      _moneyTabs(0),
      gap(14),
      Box(
        pad: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('وصلك', style: tx(14, c: K.muted)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('3,500,000', style: tx(30, w: bold)),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text('من 4.5 مليون', style: tx(14, c: K.muted)),
                ),
              ],
            ),
            gap(10),
            Row(
              children: [
                Expanded(child: kv(LucideIcons.heartHandshake, 'المهر', '2 من 3 · الباقي 15 نوفمبر')),
              ],
            ),
            kv(LucideIcons.user, 'الوالد', '1.5 مليون · وصلت'),
          ],
        ),
      ),
      sectionTitle('وين تروح'),
      whiteList([
        g(LucideIcons.gem, B.gold, B.goldSoft, 'الذهب', '18 من 24.5 جرام', 0.75, '1,116,000'),
        g(LucideIcons.package, B.rose, B.roseSoft, 'الجهاز', '23 من 41 غرض', 0.55, '640,000'),
        g(LucideIcons.shirt, K.lilac, K.lilacSoft, 'فساتين الأسبوع', '4 من 6 جاهزة', 0.7, '390,000'),
        g(LucideIcons.partyPopper, K.teal, K.tealSoft, 'عرس النساء', 'الصالة والضيافة والمزينة', 0.4, '750,000'),
      ]),
    ],
  );
}

Widget bGold() {
  Widget piece(String name, String g, String k, String sub, {bool gift = false, bool pending = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: pending
                ? null
                : const LinearGradient(colors: [Color(0xFFE8C66A), B.gold]),
            color: pending ? K.bg : null,
            border: pending ? Border.all(color: B.gold, width: 1.5) : null,
          ),
          child: Icon(gift ? LucideIcons.gift : LucideIcons.gem, size: 19, color: pending ? B.gold : Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: tx(15.5, w: bold, c: pending ? K.muted : K.ink)),
              Text(sub, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            grams(g),
            gap(3),
            Text('عيار $k', style: tx(11.5, c: K.muted)),
          ],
        ),
      ],
    ),
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: btn('أضيفي قطعة', wide: true, v: 15, fs: 16, bg: B.gold, icon: LucideIcons.plus),
    ),
    children: [
      subHeader('الذهب', sub: 'بند من تجهيزك · بالجرام والعيار'),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFF6E3B4), B.goldSoft]),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ذهبك', style: tx(14, c: B.gold)),
                  Text('20.5 جرام', style: tx(30, w: bold, c: K.ink)),
                  Text('من 24.5 ناويتها · باقي الخاتم', style: tx(13, c: K.muted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('دفعتِ', style: tx(12.5, c: K.muted)),
                Text('1,116,000', style: tx(17, w: bold)),
              ],
            ),
          ],
        ),
      ),
      sectionTitle('القطع'),
      whiteList([
        piece('الطقم', '18 جم', '21', 'قلادة وحلق · ذهب الصائغ · 62 ألف للجرام'),
        piece('حلق صغير', '2.5 جم', '21', 'هدية من محمد · أضافها هو', gift: true),
        piece('الخاتم', '4 جم', '21', 'باقي · قبل ديسمبر', pending: true),
      ]),
      gap(12),
      note('الذهب بالجرام والعيار، مو بالريال بس. ولو أهديتِ قطعة أو انباعت، تسجلينها هنا.',
          c: B.gold, bg: B.goldSoft, i: LucideIcons.scale),
    ],
  );
}

Widget bAddGold() => Phone(
  sheet: sheet(
    title: 'قطعة ذهب',
    sub: 'اشتريتيها، أو جتك هدية',
    children: [
      field('القطعة', 'الخاتم', focused: true),
      gap(10),
      Row(
        children: [
          Expanded(child: field('الوزن', '4 جرام', icon: LucideIcons.scale)),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: K.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('العيار', style: tx(12.5, c: K.muted)),
                  gap(6),
                  Row(
                    children: [
                      for (final k in const ['18', '21', '24'])
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: chip(k, on: k == '21', onBg: B.gold, fs: 13),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      gap(10),
      amountField('سعر الجرام يوم الشراء', '62,000', 'اثنين وستين ألف ريال', focused: false),
      gap(10),
      Box(
        c: B.goldSoft,
        pad: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(child: Text('المجموع', style: tx(14.5, c: B.gold))),
            Text('248,000 ر.ي', style: tx(20, w: bold)),
          ],
        ),
      ),
      gap(10),
      Row(
        children: [
          Expanded(child: chip('اشتريتها', on: true, onBg: B.gold)),
          const SizedBox(width: 8),
          Expanded(child: chip('هدية')),
          const SizedBox(width: 8),
          Expanded(child: chip('من ذهب أمي')),
        ],
      ),
      gap(16),
      btn('أضيفي القطعة', wide: true, v: 16, fs: 17, bg: B.gold),
    ],
  ),
  children: [subHeader('الذهب', sub: 'بند من تجهيزك · بالجرام والعيار')],
);

Widget bJahaz() {
  Widget cat(IconData i, String t, int done, int all, String amt) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Column(
      children: [
        Row(
          children: [
            iconTile(i, B.rose, B.roseSoft, s: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t, style: tx(15.5, w: bold)),
                  Text('$done من $all · $amt', style: tx(12.5, c: K.muted)),
                ],
              ),
            ),
            if (done == all) tag('خلص', K.green, K.greenSoft) else const Icon(LucideIcons.chevronLeft, size: 18, color: K.faint),
          ],
        ),
        gap(8),
        bar(done / all, done == all ? K.green : B.rose, h: 5),
      ],
    ),
  );
  return Phone(
    children: [
      subHeader('الجهاز', sub: 'بند من تجهيزك · قائمة بالأنواع'),
      Box(
        pad: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('قائمة الجهاز', style: tx(14, c: K.muted)),
                  Text('23 من 41', style: tx(28, w: bold)),
                  Text('صرفتِ 640 ألف من 1.2 مليون', style: tx(13, c: K.muted)),
                ],
              ),
            ),
            btn('شاركيها مع أمك', bg: B.roseSoft, fg: B.rose, v: 10, fs: 14, icon: LucideIcons.share2),
          ],
        ),
      ),
      sectionTitle('حسب النوع', action: 'أضيفي'),
      whiteList([
        cat(LucideIcons.shirt, 'ملابسك', 12, 18, '310 ألف'),
        cat(LucideIcons.utensils, 'المطبخ', 6, 12, '180 ألف'),
        cat(LucideIcons.bed, 'المفارش والستاير', 2, 6, '90 ألف'),
        cat(LucideIcons.sparkles, 'العطور والبخور', 3, 3, '60 ألف'),
        cat(LucideIcons.briefcase, 'الشنط والجزم', 0, 2, 'ما بدأت'),
      ]),
    ],
  );
}

Widget outfits({bool bride = true}) {
  Widget d(String day, String name, String how, Widget state, {Color c = K.lilac}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 56,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(LucideIcons.shirt, color: c),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(day, style: tx(12.5, c: K.muted)),
              Text(name, style: tx(15.5, w: bold)),
              Text(how, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        state,
      ],
    ),
  );
  return Phone(
    children: [
      subHeader(
        bride ? 'فساتين الأسبوع' : 'لبس المناسبات',
        sub: bride ? 'بند من تجهيزك · فستان لكل يوم' : 'بند من عرسك · لكل ليلة لبسها',
      ),
      note(
        bride
            ? 'لكل يوم فستان. اللي بالتأجير نذكّرك بالبروفة، وبإرجاعه، وبالعربون اللي يرجع لك.'
            : 'لكل ليلة لبسها. اللي بالتفصيل نذكّرك بالبروفة وموعد الاستلام.',
        c: K.lilac,
        bg: K.lilacSoft,
        i: LucideIcons.shirt,
      ),
      gap(12),
      if (bride)
        whiteList([
          d('الحمام', 'التراثي الصنعاني', 'من أمي · استعارة', tag('جاهز', K.green, K.greenSoft), c: B.gold),
          d('الذبال', 'من أهل العريس', 'يجيبونه يوم الذبال', tag('عندهم', K.muted, K.bg), c: B.gold),
          d('النقش', 'الأخضر', 'اشتريته · 60 ألف', tag('جاهز', K.green, K.greenSoft), c: K.green),
          d('الحفلة', 'فستان سهرة', 'تأجير 80 ألف · عربون 20', tag('بروفة السبت', K.saffronInk, K.saffronSoft)),
          d('الزفة', 'الأبيض', 'تأجير 250 ألف · بروفة 2 من 3', tag('يرجع الأحد', B.rose, B.roseSoft), c: B.rose),
        ])
      else
        whiteList([
          d('السمرة', 'الثوب والجنبية والشال', 'من عندي', tag('جاهز', K.green, K.greenSoft), c: K.teal),
          d('المقيل', 'الثوب والكوت', 'شراء · 45 ألف', tag('جاهز', K.green, K.greenSoft), c: K.teal),
          d('الزفاف', 'البدلة والشال والجنبية', 'تفصيل 300 ألف · دفعت 200', tag('استلام 15 يناير', K.saffronInk, K.saffronSoft), c: B.gold),
        ]),
    ],
  );
}

Widget bGifts() {
  Widget g(String l, String name, String what, String back, {bool gold = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        avatar(l, gold ? B.gold : B.rose, s: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: tx(15.5, w: bold)),
              Text(back, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        gold ? grams(what) : Text(what, style: tx(15, w: bold)),
      ],
    ),
  );
  return Phone(
    nav: Sec.money,
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: btn('اشكريهن على واتساب', wide: true, v: 15, fs: 16, bg: B.rose, icon: LucideIcons.heart),
    ),
    children: [
      subHeader('دفتر الهدايا', sub: 'كتبته نورة يوم الحفلة والزفة'),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: B.rose, borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('وصلك', style: tx(13.5, c: Colors.white70)),
                  Text('640,000 ر.ي', style: tx(26, w: bold, c: Colors.white)),
                  Text('و 7 جرام ذهب', style: tx(14, w: bold, c: B.goldSoft)),
                ],
              ),
            ),
            Column(
              children: [
                Text('23', style: tx(28, w: bold, c: Colors.white)),
                Text('هدية', style: tx(12, c: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
      sectionTitle('الهدايا'),
      whiteList([
        g('ع', 'عمتي فاطمة', '5 جم', 'خاتم · تردينها في عرس بنتها', gold: true),
        g('خ', 'خالتي أمل', '50,000', 'تردينها في عرس بنتها'),
        g('ج', 'جارتنا أم علي', '20,000', 'ما عندها عرس قريب'),
        g('ص', 'صاحبتي ريم', '2 جم', 'حلق · عرسها الصيف', gold: true),
      ]),
    ],
  );
}

// ============================================================ المهام

Widget bAppointments() {
  Widget a(String day, String time, String what, String who, IconData i, {bool done = false, bool next = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        SizedBox(
          width: 70,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(day, style: tx(13, w: bold, c: next ? B.rose : (done ? K.faint : K.ink))),
              Text(time, style: tx(12, c: K.muted)),
            ],
          ),
        ),
        iconTile(i, done ? K.faint : B.rose, done ? K.bg : B.roseSoft, s: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(what, style: tx(15, w: bold, c: done ? K.faint : K.ink)),
              Text(who, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        if (next) tag('الجاي', B.rose, B.roseSoft),
      ],
    ),
  );
  return Phone(
    nav: Sec.tasks,
    children: [
      tabHeader('المهام', '6 مواعيد قبل الزفة', sec: Sec.tasks, actions: [LucideIcons.plus]),
      topTabs(const ['المهام', 'مواعيدي'], 1, c: K.saffronInk),
      gap(12),
      whiteList([
        a('السبت 9', '4 العصر', 'بروفة فستان الزفة 2', 'أتيليه الأميرة · شارع جمال', LucideIcons.shirt, done: true),
        a('السبت 16', '8 الصبح', 'الحمام', 'حمام الميدان · مع أمي وأخواتي', LucideIcons.droplets, next: true),
        a('الاثنين 18', '4 العصر', 'النقش', 'أم فهد · في البيت', LucideIcons.palette),
        a('الثلاثاء 19', '2 الظهر', 'المزينة للحفلة', 'صالون لمسة', LucideIcons.sparkles),
        a('الأربعاء 20', 'العصر', 'النسمة', 'نقش ثاني · أم فهد', LucideIcons.palette),
        a('الخميس 21', '10 الصبح', 'المزينة للزفة', 'صالون لمسة · في البيت', LucideIcons.sparkles),
      ]),
      gap(12),
      note('قبل كل موعد بيوم نذكّرك ومن معك، ونذكّرك بالمبلغ اللي باقي للمزودة.',
          c: K.saffronInk, bg: K.saffronSoft, i: LucideIcons.bellRing),
    ],
  );
}

Widget bTasks() => Phone(
  nav: Sec.tasks,
  children: [
    tabHeader('المهام', '11 من 26 · 1 متأخرة', sec: Sec.tasks, actions: [LucideIcons.plus]),
    topTabs(const ['المهام', 'مواعيدي'], 0, c: K.saffronInk),
    sectionTitle('هذا الأسبوع'),
    whiteList([
      check('احجزي النقاشة', sub: 'متأخرة يومين · الاثنين 18 و الأربعاء 20', c: K.saffronInk),
      check('أكّدي عدد الضيافة مع الصالة', sub: '120 متوقعة · نورة', c: K.saffronInk),
      check('بروفة فستان الحفلة', sub: 'السبت · أتيليه الأميرة', c: K.saffronInk, done: true),
    ]),
    sectionTitle('قبل الأسبوع'),
    whiteList([
      check('وزّعي الدعوات', sub: 'أمي ترسلها باسمها', c: K.saffronInk),
      check('اشتري الخاتم', sub: 'باقي 4 جرام من الذهب', c: K.saffronInk),
      check('رتبي الحمام', sub: 'حمام الميدان · السبت 16', c: K.saffronInk),
    ]),
  ],
);

// ============================================================ الضيوف

Widget bGuests() {
  Widget fam(String name, int all, int yes, {String? who}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        iconTile(LucideIcons.users, K.lilac, K.lilacSoft, s: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: tx(15.5, w: bold)),
              Text(who ?? '$yes أكدن من $all', style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        SizedBox(width: 60, child: bar(yes / all, K.lilac, h: 5)),
      ],
    ),
  );
  return Phone(
    nav: Sec.guests,
    children: [
      tabHeader('الضيفات', '150 مدعوة · 96 أكدن', sec: Sec.guests, actions: [LucideIcons.search]),
      Box(
        pad: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('متوقع يحضرن', style: tx(13.5, c: K.muted)),
                  Text('120 تقريبًا', style: tx(26, w: bold, c: K.lilac)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('صالة الياسمين', style: tx(13.5, c: K.muted)),
                Text('تكفي 180', style: tx(16, w: bold, c: K.green)),
              ],
            ),
          ],
        ),
      ),
      sectionTitle('حسب العائلة', action: 'أضيفي'),
      whiteList([
        fam('أهلي', 46, 38),
        fam('أهل العريس', 40, 22, who: '22 أكدن · أم محمد ترسل لهن'),
        fam('الجارات', 30, 18),
        fam('صاحباتي', 34, 18),
      ]),
    ],
  );
}

Widget bInvite() => Phone(
  bg: B.pearl,
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
    child: btn('أرسليها لـ 150', wide: true, v: 16, fs: 17, bg: K.green, icon: LucideIcons.send),
  ),
  children: [
    subHeader('بطاقة الدعوة', sub: 'باسم أمك · بدون أي صورة'),
    Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: B.goldSoft, width: 3),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 70,
            child: Container(
              decoration: BoxDecoration(color: B.plum, borderRadius: BorderRadius.circular(16)),
              child: const CustomPaint(painter: Lights(strands: 9, lit: 9, apexY: 0.05, cross: false), size: Size.infinite),
            ),
          ),
          gap(18),
          Text('بسم الله الرحمن الرحيم', style: tx(14, c: K.muted)),
          gap(10),
          Text('تتشرف أم سلمى', style: tx(20, w: bold)),
          Text('بدعوتك لحضور حفل زفاف ابنتها', style: tx(15, c: K.muted)),
          gap(12),
          Text('الثلاثاء 19 يناير', style: tx(22, w: bold, c: B.rose)),
          Text('بعد العصر · صالة الياسمين', style: tx(15)),
          gap(14),
          Container(height: 1, color: B.goldSoft),
          gap(12),
          Text('الحفلة للنساء فقط', style: tx(13.5, w: bold, c: B.gold)),
        ],
      ),
    ),
    gap(12),
    note('كل ضيفة يوصلها رابط باسمها ترد منه. ما نطلب صور، وما تظهر أسماء الضيفات لأحد غيرك.',
        c: K.lilac, bg: K.lilacSoft, i: LucideIcons.shieldCheck),
  ],
);

// ============================================================ المزودين

Widget bProviders() {
  Widget c(IconData i, String t, String n) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        iconTile(i, K.sky, K.skySoft, s: 40),
        gap(10),
        Text(t, style: tx(15, w: bold)),
        Text(n, style: tx(12, c: K.muted)),
      ],
    ),
  );
  return Phone(
    nav: Sec.providers,
    children: [
      tabHeader('المزودين', 'محجوز 3 من 7', actions: [LucideIcons.search]),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: B.roseSoft, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            const Icon(LucideIcons.badgeCheck, color: B.rose),
            const SizedBox(width: 10),
            Expanded(
              child: Text('اللي عليهن "نسائي" فريقهن كله نساء، ويتعهدن ما ينشرن صورك.',
                  style: tx(13.5, w: bold, c: B.roseDark, h: 1.45)),
            ),
          ],
        ),
      ),
      gap(12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.45,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          c(LucideIcons.building2, 'صالات نسائية', 'محجوزة · الياسمين'),
          c(LucideIcons.sparkles, 'المزينات', 'محجوزة · لمسة'),
          c(LucideIcons.palette, 'النقاشات', '6 قريبات منك'),
          c(LucideIcons.camera, 'المصورات', 'عرضين ينتظرونك'),
          c(LucideIcons.shirt, 'الفساتين', 'بيع وتأجير'),
          c(LucideIcons.gem, 'الذهب', 'محلات في صنعاء'),
          c(LucideIcons.bed, 'المفارش', 'للجهاز'),
          c(LucideIcons.droplets, 'الحمامات', 'محجوز · الميدان'),
        ],
      ),
    ],
  );
}

Widget bPhotographer() => Phone(
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
    child: Row(
      children: [
        Expanded(child: btn('اطلبي حجز', bg: K.sky, v: 16, fs: 16)),
        const SizedBox(width: 8),
        btn('محادثة', bg: K.skySoft, fg: K.sky, v: 16, fs: 16),
      ],
    ),
  ),
  children: [
    subHeader('المصورة رنا', sub: 'تصوير نسائي · صنعاء'),
    Container(
      height: 150,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [B.plum, B.plumMid]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: Lights(strands: 9, lit: 9, apexY: 0.05))),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.eyeOff, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('ما تعرض صور عرايس', style: tx(14, w: bold, c: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    gap(12),
    Row(
      children: [
        tag('نسائي', B.rose, B.roseSoft),
        const SizedBox(width: 6),
        tag('فاضية يوم الحفلة', K.green, K.greenSoft),
        const Spacer(),
        const Icon(Icons.star_rounded, size: 18, color: B.gold),
        Text(' 4.9 · 38 عروسة', style: tx(13.5, w: bold)),
      ],
    ),
    sectionTitle('تعهد الخصوصية'),
    Box(
      pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          kv(LucideIcons.shieldCheck, 'النشر', 'ولا صورة، حتى بدون وجه', c: K.green),
          kv(LucideIcons.hardDrive, 'التسليم', 'لك أنتِ بس، رابط خاص', c: K.green),
          kv(LucideIcons.trash2, 'بعد شهر', 'تمسح نسختها', c: K.green),
        ],
      ),
    ),
    sectionTitle('الباقات'),
    whiteList([
      listRow(icon: LucideIcons.camera, fg: K.sky, soft: K.skySoft, title: 'الحفلة', sub: '4 ساعات · 300 صورة', trailing: Text('180 ألف', style: tx(14, w: bold, c: K.sky))),
      listRow(icon: LucideIcons.camera, fg: K.sky, soft: K.skySoft, title: 'الحفلة والزفة', sub: 'يومين · ألبوم مطبوع', trailing: Text('320 ألف', style: tx(14, w: bold, c: K.sky))),
    ]),
  ],
);

// ============================================================ الخصوصية

Widget bPeople() {
  Widget m(String l, Color c, String name, String role, String sees) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        avatar(l, c, s: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(name, style: tx(15.5, w: bold)),
                  const SizedBox(width: 6),
                  Text(role, style: tx(12.5, c: K.muted)),
                ],
              ),
              Text(sees, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        const Icon(LucideIcons.chevronLeft, size: 18, color: K.faint),
      ],
    ),
  );
  return Phone(
    children: [
      subHeader('المشاركين', sub: 'مين يساعدك، ووش يشوف'),
      whiteList([
        m('أ', B.rose, 'أمي', 'تشوف وتعدّل', 'كل شي، والمال'),
        m('ن', K.lilac, 'نورة', 'أختي', 'المهام والضيفات · وتكتب الهدايا'),
        m('م', K.teal, 'محمد', 'العريس', 'موعد الزفة والبرنامج بس'),
      ]),
      gap(12),
      note('محمد له خطته لجانبه، وأنتِ مشاركة فيها بنفس الطريقة. كل واحد يشوف بس اللي يسمح فيه الثاني.',
          c: K.teal, bg: K.tealSoft, i: LucideIcons.heartHandshake),
      sectionTitle('أضيفي'),
      whiteList([
        listRow(icon: LucideIcons.userPlus, fg: B.rose, soft: B.roseSoft, title: 'من جهات الاتصال', sub: 'وتحددين وش تشوف'),
      ]),
    ],
  );
}

Widget bPrivacy() {
  Widget t(String s, String sub, bool on) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s, style: tx(15.5, w: bold)),
              Text(sub, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 26,
          padding: const EdgeInsets.all(3),
          alignment: on ? Alignment.centerLeft : Alignment.centerRight,
          decoration: BoxDecoration(color: on ? B.rose : K.line, borderRadius: BorderRadius.circular(13)),
          child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
        ),
      ],
    ),
  );
  return Phone(
    children: [
      subHeader('الخصوصية', sub: 'خطتك، وصورك، وأرقامك'),
      whiteList([
        t('قفل بالبصمة', 'كل ما تفتحين التطبيق', true),
        t('أخفي المبالغ', 'في الرئيسية، لو أحد جنبك', true),
        t('الصور ما تطلع برا التطبيق', 'إيصالات وصور الفساتين محفوظة عندك بس', true),
        t('التنبيهات بدون تفاصيل', 'على شاشة القفل: "عندك موعد" بس', true),
      ]),
      sectionTitle('محمد يشوف'),
      whiteList([
        t('موعد الزفة والبرنامج', 'عشان يرتب عرسه على يومك', true),
        t('المال', 'المهر اللي وصل والباقي', false),
        t('الضيفات', '', false),
      ]),
    ],
  );
}

// ============================================================ لحظة

Widget bMomentWeek() => Phone(
  statusLight: true,
  gradient: const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [B.plum, B.plumMid],
  ),
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
    child: btn('وريني أيامي', wide: true, v: 16, fs: 17, bg: Colors.white, fg: B.plumMid),
  ),
  children: [
    const SizedBox(height: 230, child: CustomPaint(painter: Lights(strands: 11, lit: 11), size: Size.infinite)),
    gap(14),
    Center(child: Text('السبت 16 يناير', style: tx(15, w: bold, c: Colors.white70))),
    gap(6),
    Center(child: Text('بدأ أسبوعك يا سلمى', style: tx(32, w: bold, c: Colors.white))),
    gap(8),
    Center(
      child: Text('ستة أيام، كل يوم بفستانه.\nاليوم الحمام، والليلة نورّنا أول حبل.',
          textAlign: TextAlign.center, style: tx(15.5, c: Colors.white70, h: 1.5)),
    ),
    gap(22),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          for (final r in const [
            ('الحمام', 'السبت'),
            ('الذبال', 'الأحد'),
            ('النقش', 'الاثنين'),
            ('الحفلة', 'الثلاثاء'),
            ('النسمة', 'الأربعاء'),
            ('الزفة', 'الخميس'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(r.$1, style: tx(15.5, w: bold, c: Colors.white))),
                  Text(r.$2, style: tx(14, c: Colors.white70)),
                ],
              ),
            ),
        ],
      ),
    ),
  ],
);
