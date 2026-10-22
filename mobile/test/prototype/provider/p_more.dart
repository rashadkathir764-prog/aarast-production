// Provider journey prototype: calendar (bookings in and outside the app,
// holds, freshness), messages, the provider's profile, and general states.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import 'pkit.dart';

// ============================================================ التقويم

/// A month for a provider with four teams: each night shows what is left.
Widget p28Month() {
  // (day, left of 4, state) state: 0 free, 1 some, 2 full, 3 closed, 4 waiting
  const days = <(int, String, int)>[
    (1, '', 0), (2, '', 0), (3, '', 0), (4, '', 0), (5, '', 0), (6, '', 0), (7, '3', 1),
    (8, '', 0), (9, '', 0), (10, '', 3), (11, '', 3), (12, '', 0), (13, '', 0), (14, '1', 1),
    (15, '', 0), (16, '', 0), (17, '', 0), (18, '', 0), (19, '', 0), (20, '2', 4), (21, '0', 2),
    (22, '', 0), (23, '', 0), (24, '', 0), (25, '', 0), (26, '', 0), (27, '3', 1), (28, '1', 1),
    (29, '', 0), (30, '', 0), (31, '', 0),
  ];
  Color bg(int s) => [Colors.white, K.greenSoft, K.coralSoft, K.line, K.saffronSoft][s];
  Color fg(int s) => [K.ink, K.green, K.coral, K.faint, K.saffronInk][s];
  Widget cell((int, String, int) d) => Container(
    height: 50,
    margin: const EdgeInsets.all(2.5),
    decoration: BoxDecoration(
      color: bg(d.$3),
      borderRadius: BorderRadius.circular(12),
      border: d.$1 == 21 ? Border.all(color: P.c, width: 2) : null,
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('${d.$1}', style: tx(14, w: bold, c: fg(d.$3), f: fPlex)),
        if (d.$2.isNotEmpty) Text(d.$2 == '0' ? 'مليان' : 'باقي ${d.$2}', style: tx(9.5, w: bold, c: fg(d.$3))),
        if (d.$3 == 3) Text('مقفول', style: tx(9.5, c: K.faint)),
      ],
    ),
  );
  const wd = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];
  return pPhone(
    tab: PTab.calendar,
    action: Row(
      children: [
        Expanded(child: pBtn('حجز من برا', icon: LucideIcons.plus, v: 14, fs: 15)),
        const SizedBox(width: 10),
        Expanded(child: pBtn('أقفل أيام', v: 14, fs: 15, bg: Colors.white, fg: P.c)),
      ],
    ),
    children: [
      pTop('التقويم', 'يناير 2027 · رجب وشعبان 1448', icons: [LucideIcons.chevronRight, LucideIcons.chevronLeft]),
      Row(children: [for (final w in wd) Expanded(child: Center(child: Text(w, style: tx(12.5, c: K.muted))))]),
      gap(4),
      // 1 January 2027 is a Friday: the Saturday-first grid starts 6 cells in.
      for (var r = 0; r < 6; r++)
        Row(children: [
          for (var c = 0; c < 7; c++)
            Expanded(
              child: r * 7 + c - 6 >= 0 && r * 7 + c - 6 < days.length
                  ? cell(days[r * 7 + c - 6])
                  : const SizedBox(height: 55),
            ),
        ]),
      gap(10),
      Wrap(spacing: 12, runSpacing: 6, children: [
        for (final l in const [('فيه فرق فاضية', 1), ('مليان', 2), ('طلب ينتظرك', 4), ('مقفول', 3)])
          Row(mainAxisSize: MainAxisSize.min, children: [dot(fg(l.$2), 10), const SizedBox(width: 5), Text(l.$1, style: tx(12, c: K.muted))]),
      ]),
      gap(10),
      pNote('حدّثته قبل 3 أيام. العرسان يشوفون «فاضي» بس إذا حدّثته خلال 14 يوم.', i: LucideIcons.shieldCheck),
    ],
  );
}

/// One night split into periods, each team on its line.
Widget p29Day() {
  Widget slot(String period, List<(String, String, String)> rows) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(period, style: tx(14, w: bold, c: K.muted)),
        gap(6),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(width: 82, child: Text(r.$1, style: tx(14, w: bold))),
                Expanded(child: Text(r.$2, style: tx(13.5, c: K.muted))),
                st(r.$3),
              ],
            ),
          ),
      ],
    ),
  );
  return pPhone(
    tab: PTab.calendar,
    children: [
      subHeader('الخميس 21 يناير', sub: '13 شعبان · الليلة مليانة'),
      slot('العصر', [
        ('فريق 3', 'مقيل عرس ناصر', 'محجوز'),
        ('فريق 1', 'فاضي، تقدر تاخذ مقيل', 'فاضي'),
      ]),
      slot('الليل', [
        ('فريق 1', 'زفة عادل الريمي', 'محجوز'),
        ('فريق 2', 'زفة محمد الحمدي', 'محجوز'),
        ('فريق 3', 'حجز من برا: بيت السنيدار', 'من برا'),
        ('فريق النساء', 'حفلة سلمى · ينتظر تأكيدك', 'ينتظر تأكيدك'),
      ]),
      gap(4),
      Row(
        children: [
          Expanded(child: pBtn('أقفل الليلة', v: 13, fs: 15, bg: Colors.white, fg: P.c)),
          const SizedBox(width: 10),
          Expanded(child: pBtn('حجز من برا', v: 13, fs: 15, bg: P.soft, fg: P.c)),
        ],
      ),
    ],
  );
}

Widget p30Outside() => pPhone(
  sheet: sheet(
    title: 'حجز من برا',
    sub: 'واحد جا المحل أو اتصل. ينحسب مثل أي حجز.',
    children: [
      pField('اليوم والفترة', 'الخميس 21 يناير · الليل', icon: LucideIcons.calendarDays),
      gap(10),
      Wrap(spacing: 8, runSpacing: 8, children: [pChip('فريق 3', on: true), pChip('فريق النساء')]),
      gap(10),
      pField('اسم أو ملاحظة (اختياري)', 'بيت السنيدار · دفع 50 ألف'),
      gap(12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: K.saffronSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: K.saffron)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(LucideIcons.alertTriangle, color: K.saffronInk, size: 19),
              const SizedBox(width: 8),
              Expanded(child: Text('آخر فريق رجال ليلة الخميس', style: tx(15, w: bold, c: K.saffronInk))),
            ]),
            gap(6),
            Text('عندك طلب من خالد على نفس الليلة ما رديت عليه. لو حفظت، نعتذر له بأدب.', style: tx(13.5, h: 1.5)),
          ],
        ),
      ),
      gap(12),
      pBtn('احفظ واعتذر لخالد'),
      gap(8),
      Center(child: Text('خلّ الفريق لخالد', style: tx(14, w: bold, c: K.muted))),
    ],
  ),
  children: [subHeader('التقويم')],
);

Widget p31Hold() => pPhone(
  sheet: sheet(
    title: 'امسك الليلة لمحمد',
    sub: 'مثل «نمسكها لك يومين لين تأكد»',
    children: [
      Box(child: Column(children: [kv('الليلة', 'الخميس 21 يناير · الليل'), kv('الفريق', 'فريق 2')])),
      gap(12),
      Text('لين متى؟', style: tx(14, w: bold, c: K.muted)),
      gap(8),
      Row(children: [pChip('يوم'), const SizedBox(width: 8), pChip('3 أيام', on: true), const SizedBox(width: 8), pChip('أسبوع')]),
      gap(12),
      Box(
        child: Column(
          children: [
            eff(LucideIcons.lock, 'الفريق ما ينعرض فاضي لغيره'),
            eff(LucideIcons.timer, 'لو ما أكّد لين السبت، تنفك لحالها ونبلّغكم'),
            eff(LucideIcons.bell, 'محمد يوصله «ماسكين لك الليلة لين السبت»'),
          ],
        ),
      ),
      gap(12),
      pBtn('امسكها', icon: LucideIcons.lock),
    ],
  ),
  children: [subHeader('محمد الحمدي')],
);

Widget p32Fresh() => pPhone(
  tab: PTab.calendar,
  children: [
    pTop('التقويم', 'كل جمعة نسألك'),
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: P.c, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تقويمك صحيح؟', style: tx(22, w: bold, c: Colors.white)),
          Text('فيه حجز من برا ما سجّلته هذا الأسبوع؟', style: tx(14, c: Colors.white70)),
          gap(14),
          Row(children: [
            btn('إيه صحيح', bg: Colors.white, fg: P.c),
            const SizedBox(width: 10),
            btn('أعدّل', bg: P.dark, fg: Colors.white),
          ]),
        ],
      ),
    ),
    gap(10),
    Text('لو ما رديت 14 يوم، العرسان يشوفون «اسأل عن التوفر» بدل «فاضي».', style: tx(13, c: K.muted)),
    sectionTitle('إجازة'),
    Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('في إجازة', style: tx(16, w: bold))),
            pToggle(true),
          ]),
          gap(6),
          kv('من', 'الاثنين 8 فبراير'),
          kv('لين', 'آخر رمضان · 9 مارس'),
          gap(6),
          eff(LucideIcons.inbox, 'ما توصلك طلبات جديدة، ويظهر للعرسان «في إجازة لين 9 مارس»'),
          eff(LucideIcons.checkCircle2, 'حجوزاتك المؤكدة ما تتأثر', c: K.green),
        ],
      ),
    ),
  ],
);

// ============================================================ الرسائل

Widget p33Chats() {
  Widget c(String l, Color col, String n, String sub, String last, String t, {int un = 0, String? s}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        avatar(l, col, s: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Text(n, style: tx(15.5, w: bold)), const SizedBox(width: 6), if (s != null) st(s)]),
              Text(sub, style: tx(12, c: K.muted)),
              Text(last, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(13.5, c: un > 0 ? K.ink : K.muted)),
            ],
          ),
        ),
        Column(
          children: [
            Text(t, style: tx(11.5, c: K.muted)),
            if (un > 0) ...[gap(4), Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: P.c, borderRadius: BorderRadius.circular(9)),
              child: Text('$un', style: tx(11, w: bold, c: Colors.white)),
            )],
          ],
        ),
      ],
    ),
  );
  return pPhone(
    tab: PTab.chats,
    children: [
      pTop('الرسائل', 'مع العرسان'),
      whiteList([
        c('م', K.teal, 'محمد الحمدي', 'الزفة · 21 يناير', 'الدرون عند الباب ممكن؟', '9:40', un: 2, s: 'ردّيت'),
        c('س', const Color(0xFFB4536A), 'سلمى السقاف', 'حفلة نساء · 21 يناير', 'رسالة صوتية · 0:34', '8:15', un: 1, s: 'جديد'),
        c('ع', K.sky, 'عادل الريمي', 'الزفة · 21 يناير', 'تمام، نشوفكم الخميس', 'أمس', s: 'محجوز'),
      ]),
    ],
  );
}

Widget p34Chat() {
  Widget b(String t, {bool me = false, String? time}) => Align(
    alignment: me ? Alignment.centerLeft : Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(maxWidth: 270),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: me ? P.c : Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t, style: tx(14.5, c: me ? Colors.white : K.ink, h: 1.5)),
          if (time != null) Text(time, style: tx(11, c: me ? Colors.white60 : K.muted)),
        ],
      ),
    ),
  );
  return pPhone(
    action: Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: K.line)),
      child: Row(
        children: [
          Expanded(child: Text('اكتب رسالة…', style: tx(15, c: K.faint))),
          const Icon(LucideIcons.mic, color: P.c),
          const SizedBox(width: 10),
          Container(width: 38, height: 38, decoration: const BoxDecoration(color: P.c, shape: BoxShape.circle),
              child: const Icon(LucideIcons.send, color: Colors.white, size: 18)),
        ],
      ),
    ),
    children: [
      subHeader('محمد الحمدي', sub: 'الزفة · الخميس 21 يناير'),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: P.soft, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Icon(LucideIcons.fileText, size: 18, color: P.c),
          const SizedBox(width: 8),
          Expanded(child: Text('عرضك: صور وفيديو · 550,000 · باقي 8 أيام', style: tx(13.5, w: bold, c: P.c))),
          st('ردّيت'),
        ]),
      ),
      gap(14),
      b('السلام عليكم، الدرون عند الباب ممكن؟ القاعة تسمح', time: '9:38'),
      b('وعليكم السلام. ممكن، والقاعة تسمح', me: true, time: '9:40'),
      b('طيب والدرون كم يزيد؟', time: '9:41'),
      gap(8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        pChip('الدرون 80,000 إضافة'),
        pChip('أعدّل العرض'),
        pChip('أرسل موقع المحل'),
      ]),
    ],
  );
}

// ============================================================ ملفي

Widget p35Me() => pPhone(
  tab: PTab.me,
  children: [
    gap(6),
    pBiz(),
    gap(10),
    Wrap(spacing: 6, runSpacing: 6, children: [
      tag('موثّق', K.green, K.greenSoft),
      tag('★ 4.7 · 38 تقييم', K.saffronInk, K.saffronSoft),
      tag('يرد خلال 3 ساعات', K.sky, K.skySoft),
    ]),
    gap(12),
    pBtn('كيف يشوفك العرسان', icon: LucideIcons.eye, bg: P.soft, fg: P.c, v: 13, fs: 15),
    gap(12),
    whiteList([
      listRow(icon: LucideIcons.package, fg: P.c, soft: P.soft, title: 'خدماتك وفرقك', sub: '4 فرق · باقتين · من 350,000'),
      listRow(icon: LucideIcons.image, fg: P.c, soft: P.soft, title: 'معرض الشغل', sub: '18 صورة · تيك توك مربوط'),
      listRow(icon: LucideIcons.mapPin, fg: P.c, soft: P.soft, title: 'التغطية', sub: 'كل صنعاء · يسافر'),
      listRow(icon: LucideIcons.badgeCheck, fg: P.c, soft: P.soft, title: 'التوثيق', sub: 'موثّق من أسبوعين'),
      listRow(icon: LucideIcons.star, fg: P.c, soft: P.soft, title: 'التقييمات', sub: 'تقييم جديد ما رديت عليه', trailing: dot(K.coral, 9)),
      listRow(icon: LucideIcons.barChart3, fg: P.c, soft: P.soft, title: 'أداؤك', sub: 'آخر 30 يوم'),
      listRow(icon: LucideIcons.settings, fg: P.c, soft: P.soft, title: 'الإعدادات', sub: 'الرقم، والتنبيهات، والحساب'),
    ]),
  ],
);

Widget p36Services() {
  Widget pkg(String n, String inc, String price, String season) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Expanded(child: Text(n, style: tx(16, w: bold))), Text(price, style: tx(15.5, w: bold))]),
        Text(inc, style: tx(13, c: K.muted, h: 1.5)),
        gap(6),
        Text(season, style: tx(12.5, w: bold, c: K.saffronInk)),
      ],
    ),
  );
  return pPhone(
    tab: PTab.me,
    children: [
      subHeader('خدماتك', sub: 'تصوير · 4 فرق'),
      pkg('صور فقط', 'يشمل: 300 صورة معدّلة · إضافة: ألبوم 80,000', '350,000', 'في الموسم (شوال والصيف): 400,000'),
      pkg('صور وفيديو', 'يشمل: مصوّرين، 300 صورة، فيلم 10 دقايق، ألبوم مطبوع · إضافة: درون 80,000', '550,000', 'في الموسم: 620,000'),
      sectionTitle('الفرق', action: 'عدّل', ac: P.c),
      whiteList([
        listRow(icon: LucideIcons.camera, fg: P.c, soft: P.soft, title: 'فريق 1 · فريق 2 · فريق 3', sub: 'رجال'),
        listRow(icon: LucideIcons.camera, fg: K.coral, soft: K.coralSoft, title: 'فريق النساء', sub: 'نساء · طاقمه مصوّرات'),
        listRow(icon: LucideIcons.wrench, fg: K.muted, soft: K.line, title: 'فريق 3 موقوف مؤقتًا', sub: 'الكاميرا في الصيانة لين 30 يناير', trailing: pToggle(false)),
      ]),
      gap(10),
      Text('الأسعار بريال صنعاء · آخر تحديث قبل أسبوعين', style: tx(13, c: K.muted)),
    ],
  );
}

Widget p37Gallery() {
  Widget ph(Color c, {bool pending = false}) => Container(
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(14)),
    child: pending
        ? Align(alignment: Alignment.bottomCenter, child: Padding(padding: const EdgeInsets.all(6), child: tag('نراجعها', K.saffronInk, K.saffronSoft)))
        : null,
  );
  return pPhone(
    tab: PTab.me,
    children: [
      subHeader('معرض الشغل', sub: '18 صورة'),
      Row(children: [pChip('الزفة', on: true), const SizedBox(width: 8), pChip('حفلات النساء'), const SizedBox(width: 8), pChip('الدرون')]),
      gap(12),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          ph(const Color(0xFF7D8A80)), ph(const Color(0xFF9C8B74)), ph(const Color(0xFF6E7F8C)),
          ph(const Color(0xFF8A7C8F)), ph(const Color(0xFF7F9283)), ph(const Color(0xFF6A7682), pending: true),
        ],
      ),
      gap(12),
      pNote('ألبوم «حفلات النساء» يظهر للعرائس بس، وبدون وجوه. كل صورة جديدة نراجعها قبل ما تظهر.', c: K.coral, bg: K.coralSoft, i: LucideIcons.eyeOff),
      sectionTitle('التغطية'),
      Box(
        pad: const EdgeInsets.all(14),
        child: Column(children: [
          kv('المدينة', 'صنعاء · كل المديريات'),
          kv('يسافر', 'ذمار، إب، الحديدة · المواصلات في العرض'),
        ]),
      ),
    ],
  );
}

Widget p38Verify() => pPhone(
  action: pBtn('أرسل للتوثيق'),
  children: [
    subHeader('التوثيق'),
    Center(child: iconTile(LucideIcons.badgeCheck, K.green, K.greenSoft, s: 70, r: 22)),
    gap(10),
    Center(child: Text('شارة «موثّق» تطمّن العرسان', style: tx(20, w: bold))),
    gap(14),
    Text('واحد من هذول يكفي', style: tx(14, w: bold, c: K.muted)),
    gap(8),
    pOption('السجل التجاري', sub: 'صورة واضحة', icon: LucideIcons.fileBadge),
    pOption('البطاقة الشخصية + صورة المحل', sub: 'للي يشتغل بدون سجل', on: true, icon: LucideIcons.contact),
    pOption('البطاقة + مزكّي', sub: 'للمزودات من البيت: رقم شخص يعرفك، نتصل فيه', icon: LucideIcons.userCheck),
    gap(6),
    pNote('المستندات ما يشوفها غير فريق المراجعة، وتنحذف بعد التوثيق.', i: LucideIcons.lock),
  ],
);

Widget p39Performance() {
  Widget m(String v, String l, {String? sub}) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: card(r: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(v, style: tx(24, w: bold)),
          Text(l, style: tx(13, c: K.muted)),
          if (sub != null) Text(sub, style: tx(11.5, w: bold, c: K.green)),
        ],
      ),
    ),
  );
  return pPhone(
    tab: PTab.me,
    children: [
      subHeader('أداؤك', sub: 'آخر 30 يوم'),
      Row(children: [m('412', 'شافوا ملفك', sub: '+18%'), const SizedBox(width: 10), m('27', 'طلب')]),
      gap(10),
      Row(children: [m('3 ساعات', 'متوسط ردك'), const SizedBox(width: 10), m('9', 'حجز', sub: '33% من الطلبات')]),
      gap(12),
      Box(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ليش ما اختاروك', style: tx(15, w: bold)),
            gap(8),
            Row(children: [Expanded(child: Text('السعر', style: tx(14))), Text('7', style: tx(14, w: bold))]),
            gap(4), bar(0.7, P.c, h: 8), gap(8),
            Row(children: [Expanded(child: Text('اختاروا غيرك', style: tx(14))), Text('3', style: tx(14, w: bold))]),
            gap(4), bar(0.3, P.c, h: 8),
          ],
        ),
      ),
      gap(10),
      Text('الأرقام من طلباتك أنت بس. ما نقارنك بغيرك.', style: tx(13, c: K.muted)),
    ],
  );
}

Widget p40Settings() {
  Widget r(String t, String s, bool on) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: tx(15, w: bold)), Text(s, style: tx(12.5, c: K.muted))])),
      pToggle(on),
    ]),
  );
  return pPhone(
    tab: PTab.me,
    children: [
      subHeader('الإعدادات'),
      whiteList([
        r('رقمك يظهر للعرسان', 'لو مقفل، يكلمونك من الرسائل بس', true),
        r('تعهّد عدم نشر صور النساء', 'يظهر للعرائس عند حجز فريق النساء', true),
        r('تنبيه لكل طلب جديد', 'أول ما يوصل', true),
        r('ملخص يومي', 'كل يوم 9 الصبح', false),
      ], dividers: false),
      gap(12),
      whiteList([
        listRow(icon: LucideIcons.repeat, fg: P.c, soft: P.soft, title: 'افتح خطة عرسي', sub: 'نفس الرقم، مسار ثاني'),
        listRow(icon: LucideIcons.users, fg: P.c, soft: P.soft, title: 'مين يدير الحساب', sub: 'أنت · وأضف موظف'),
        listRow(icon: LucideIcons.logOut, fg: K.muted, soft: K.line, title: 'تسجيل الخروج', sub: ''),
        listRow(icon: LucideIcons.trash2, fg: K.coral, soft: K.coralSoft, title: 'حذف الحساب', sub: 'عندك 5 حجوزات جاية لازم تسلّمها أو تلغيها أول'),
      ]),
    ],
  );
}

// ============================================================ عام

Widget p41ClaimLink() => pPhone(
  action: pBtn('استلم ملفك وردّ', icon: LucideIcons.arrowLeft),
  children: [
    gap(20),
    Center(child: wordmark(s: 30, c: P.c)),
    gap(20),
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFDCF8C6), borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('واتساب · اعّرست', style: tx(12.5, w: bold, c: K.green)),
          gap(4),
          Text('السلام عليكم. عندك طلب تصوير من عرس محمد الحمدي يوم 21 يناير في صنعاء. ملفك عندنا من الدليل، استلمه مجانًا وردّ عليه من هنا.',
              style: tx(14.5, h: 1.6)),
        ],
      ),
    ),
    gap(18),
    Box(
      child: Column(
        children: [
          eff(LucideIcons.checkCircle2, 'مجاني، وبدون عمولة', c: K.green),
          eff(LucideIcons.phone, 'ندخلك برقمك هذا ورمز واتساب'),
          eff(LucideIcons.timer, 'الطلب يبقى 7 أيام من وقت ما تستلم الملف'),
        ],
      ),
    ),
  ],
);

Widget p42Notifications() {
  Widget n(IconData i, Color c, Color s, String t, String sub, {bool un = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(children: [
      iconTile(i, c, s, s: 40),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: tx(15, w: bold)), Text(sub, style: tx(12.5, c: K.muted))])),
      if (un) dot(K.coral, 9),
    ]),
  );
  return pPhone(
    children: [
      subHeader('التنبيهات', sub: 'كل واحد يفتح طلبه'),
      whiteList([
        n(LucideIcons.inbox, K.coral, K.coralSoft, 'طلب جديد من سلمى', 'حفلة نساء · 21 يناير', un: true),
        n(LucideIcons.calendarCheck, K.saffronInk, K.saffronSoft, 'محمد قبل عرضك', 'أكّد الحجز', un: true),
        n(LucideIcons.wallet, K.green, K.greenSoft, 'محمد سجّل دفعة 100,000', 'وصلتك؟'),
        n(LucideIcons.calendarClock, K.sky, K.skySoft, 'فهد أجّل العرس', 'من 4 فبراير للصيف · الحجز انلغى'),
        n(LucideIcons.lock, K.lilac, K.lilacSoft, 'الحجز المبدئي ينفك بكرة', 'محمد ما أكّد لسا'),
        n(LucideIcons.star, K.saffronInk, K.saffronSoft, 'تقييم جديد', '4 نجوم من محمد'),
      ]),
    ],
  );
}

Widget p43Offline() => pPhone(
  tab: PTab.requests,
  children: [
    pTop('الطلبات', '3 ينتظرون ردك'),
    offlineBar(),
    gap(4),
    Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.clock, size: 18, color: K.saffronInk),
            const SizedBox(width: 8),
            Text('عرضك لعادل ينتظر النت', style: tx(15, w: bold)),
          ]),
          Text('محفوظ على جوالك، وينرسل أول ما يرجع النت', style: tx(13, c: K.muted)),
        ],
      ),
    ),
    gap(10),
    Box(
      c: K.saffronSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تأكيد الحجز يحتاج نت', style: tx(15, w: bold, c: K.saffronInk)),
          Text('لازم نتأكد إن الفريق ما انحجز من غيرك في نفس اللحظة.', style: tx(13.5, h: 1.5)),
        ],
      ),
    ),
    gap(10),
    Text('آخر تحديث قبل 12 دقيقة', style: tx(13, c: K.muted)),
  ],
);
