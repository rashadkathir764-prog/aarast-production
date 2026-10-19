// Journey prototype v3: the gaps the logic audit found, part two. Money,
// tasks, guests and providers edges, the assistant's consent and limits, and
// the states every screen needs.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import 'gaps_a.dart' show gBottom, gEffect, gNote, gOption, gToggle;

// ============================================================ المال

Widget vCategoryOver() => Phone(
  nav: Sec.money,
  children: [
    subHeader('الضيافة', sub: 'ضيافة الأصالة'),
    Box(
      border: K.coral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.alertTriangle, size: 20, color: K.coral),
              const SizedBox(width: 8),
              Text('زادت 300 ألف عن المحطوط', style: tx(16, w: bold, c: K.coral)),
            ],
          ),
          gap(10),
          Text('2.1 مليون من 1.8', style: tx(26, w: bold)),
          gap(10),
          bar(1, K.coral, h: 10),
          gap(8),
          Text('زاد عدد الضيوف من 300 إلى 350', style: tx(13.5, c: K.muted)),
        ],
      ),
    ),
    sectionTitle('وش تسوي؟'),
    gOption('زِد ميزانية الضيافة', sub: 'من الاحتياط: باقي فيه 700 ألف', on: true),
    gOption('خذها من بند ثاني', sub: 'مثلًا الزينة: محطوط لها 600 وصرفت 250'),
    gOption('خلّها كذا', sub: 'المجموع يطلع فوق الميزانية بـ 300 ألف'),
    gap(6),
    btn('تطبيق', wide: true, v: 15),
  ],
);

Widget vAllocate() {
  Widget a(String n, String v, double p, {bool over = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(n, style: tx(15, w: bold))),
            Text(v, style: tx(15, w: bold, c: over ? K.coral : K.ink)),
          ],
        ),
        gap(6),
        bar(p, over ? K.coral : K.teal, h: 8),
      ],
    ),
  );
  return Phone(
    bottom: gBottom(btn('حفظ التوزيع', wide: true, v: 16, fs: 17)),
    children: [
      subHeader('توزيع الميزانية', sub: '10 مليون'),
      Box(
        pad: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text('موزّع', style: tx(12.5, c: K.muted)), Text('9.3 مليون', style: tx(20, w: bold))],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text('احتياط', style: tx(12.5, c: K.muted)), Text('700 ألف', style: tx(20, w: bold, c: K.teal))],
              ),
            ),
          ],
        ),
      ),
      gap(12),
      whiteList([
        a('القاعة', '3 مليون', 0.30),
        a('الضيافة', '1.8 مليون', 0.18),
        a('المهر والشبكة', '2.5 مليون', 0.25),
        a('الغداء في بيت الوالد', '700 ألف', 0.07),
        a('الفنان والفرقة', '500 ألف', 0.05),
        a('المصور', '400 ألف', 0.04),
        a('الزينة والألعاب', '400 ألف', 0.04),
      ], dividers: false),
      gap(10),
      Text('اسحب أي رقم، والاحتياط يتعدل لحاله.', style: tx(13, c: K.muted)),
    ],
  );
}

Widget vPayerFilter() {
  Widget p(String t, String s, String v, String who, Color c) => listRow(
    icon: LucideIcons.receipt, fg: c, soft: c.withValues(alpha: 0.12), title: t, sub: '$s · $who',
    trailing: Text(v, style: tx(15, w: bold)),
  );
  return Phone(
    nav: Sec.money,
    children: [
      tabHeader('الدفعات', 'مين دفع وش', sec: Sec.money),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip('الكل', fs: 13),
            const SizedBox(width: 8),
            chip('أنا', fs: 13),
            const SizedBox(width: 8),
            chip('الوالد', on: true, fs: 13),
            const SizedBox(width: 8),
            chip('صالح', fs: 13),
            const SizedBox(width: 8),
            chip('خالي أحمد', fs: 13),
          ],
        ),
      ),
      gap(12),
      Box(
        pad: const EdgeInsets.all(14),
        child: Row(
          children: [
            avatar('ع', K.teal, s: 40),
            const SizedBox(width: 10),
            Expanded(child: Text('الوالد دفع', style: tx(15.5, w: bold))),
            Text('2.2 مليون', style: tx(19, w: bold, c: K.teal)),
          ],
        ),
      ),
      gap(12),
      whiteList([
        p('قاعة سبأ', 'الدفعة الأولى · 3 نوفمبر', '1 مليون', 'الوالد', K.teal),
        p('الغداء', 'الذبائح · 10 يناير', '700 ألف', 'الوالد', K.teal),
        p('ضيافة الأصالة', 'دفعة مقدمة · 8 ديسمبر', '500 ألف', 'الوالد', K.teal),
      ]),
    ],
  );
}

Widget vPartialRefund() => Phone(
  nav: Sec.money,
  sheet: sheet(
    title: 'رجع لك مبلغ',
    sub: 'فرقة الأفراح · دفعت 100 ألف دفعة مقدمة',
    children: [
      amountField('كم رجع؟', '60,000', 'ستين ألف ريال'),
      gap(10),
      Row(
        children: [
          chip('كله 100 ألف', fs: 13),
          const SizedBox(width: 8),
          chip('جزء', on: true, fs: 13),
        ],
      ),
      gap(12),
      gOption('الباقي 40 ألف خصموه', sub: 'يصير مصروف على البند', on: true),
      gOption('الباقي بيرجع بعدين', sub: 'نذكّرك تتابع معهم'),
      gap(6),
      btn('سجّل الاسترجاع', wide: true, v: 16, fs: 17),
    ],
  ),
  children: [subHeader('فرقة الأفراح')],
);

Widget vReceipts() {
  Widget r(String t, String s, {bool missing = false}) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: missing ? K.bg : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: missing ? K.line : Colors.transparent),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 92,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: missing ? Colors.transparent : K.tealSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(missing ? LucideIcons.camera : LucideIcons.fileText,
              size: 30, color: missing ? K.faint : K.teal),
        ),
        gap(8),
        Text(t, style: tx(14, w: bold, c: missing ? K.muted : K.ink)),
        Text(s, style: tx(12, c: K.muted)),
      ],
    ),
  );
  return Phone(
    nav: Sec.money,
    children: [
      subHeader('الإيصالات', sub: '9 من 12 دفعة لها إيصال'),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.05,
        children: [
          r('قاعة سبأ', '1 مليون · 3 نوفمبر'),
          r('ضيافة الأصالة', '500 ألف · 8 ديسمبر'),
          r('المصور', '150 ألف · بدون إيصال', missing: true),
          r('الفرقة', '100 ألف · بدون إيصال', missing: true),
        ],
      ),
      gap(12),
      gNote('اضغط مطوّل على إيصال تبدله أو تشيله. الدفعة تبقى حتى لو شلت الإيصال.'),
    ],
  );
}

Widget vItemLocked() => Phone(
  nav: Sec.money,
  sheet: sheet(
    title: 'ما تقدر تحذف المصور',
    sub: 'عليه دفعة 150 ألف. الحذف يمسح أثرها من حسابك.',
    children: [
      gOption('ألغِ البند', sub: 'يبقى في السجل ملغي، والمدفوع يظهر للاسترجاع', on: true),
      gOption('اعكس الدفعة أول', sub: 'لو سجلتها غلط. بعدها تقدر تحذف'),
      gOption('بدّل المصور', sub: 'الدفعة تنتقل للمصور الجديد'),
      gap(6),
      btn('متابعة', wide: true, v: 15),
    ],
  ),
  children: [subHeader('المصور')],
);

// ============================================================ المهام

Widget vTimeline() {
  Widget m(String when, List<(String, bool)> items, {bool now = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: now ? K.saffronInk : Colors.white,
                border: Border.all(color: K.saffronInk, width: 2),
              ),
            ),
            Container(width: 2, height: 30.0 * items.length + 30, color: K.line),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(when, style: tx(14.5, w: bold, c: now ? K.saffronInk : K.muted)),
              gap(4),
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(i.$2 ? LucideIcons.checkCircle2 : LucideIcons.circle,
                          size: 17, color: i.$2 ? K.green : K.faint),
                      const SizedBox(width: 8),
                      Text(i.$1, style: tx(14.5, c: i.$2 ? K.faint : K.ink)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    nav: Sec.tasks,
    children: [
      tabHeader('المهام', 'على الوقت', sec: Sec.tasks),
      Row(children: [chip('القائمة', fs: 13), const SizedBox(width: 8), chip('الوقت', on: true, onBg: K.saffronInk, fs: 13)]),
      gap(16),
      m('أكتوبر', [('احجز القاعة', true), ('اتفق على المهر', true)]),
      m('نوفمبر · الحين', [('احجز الضيافة', false), ('اطلب عرض من مصورين', false)], now: true),
      m('ديسمبر', [('أوراق العقد عند الأمين الشرعي', false), ('بدلة العريس', false)]),
      m('يناير', [('ارسل الدعوات', false), ('رتّب القات مع المقوّت', false), ('الغداء في بيت الوالد', false)]),
    ],
  );
}

Widget vPrivateTask() => Phone(
  nav: Sec.tasks,
  sheet: sheet(
    title: 'مهمة جديدة',
    children: [
      field('المهمة', 'هدية العروسة', focused: true),
      gap(10),
      field('متى', 'قبل 14 يناير', icon: LucideIcons.calendarDays),
      gap(12),
      Box(
        pad: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(LucideIcons.eyeOff, size: 20, color: K.saffronInk),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('خاصة', style: tx(15.5, w: bold)),
                  Text('ما يشوفها غيرك، حتى المشاركين', style: tx(12.5, c: K.muted)),
                ],
              ),
            ),
            gToggle(true),
          ],
        ),
      ),
      gap(14),
      btn('أضف', wide: true, v: 16, fs: 17, bg: K.saffronInk),
    ],
  ),
  children: [tabHeader('المهام', '', sec: Sec.tasks)],
);

Widget vOverdue() => Phone(
  nav: Sec.tasks,
  children: [
    tabHeader('المهام', '3 متأخرة', sec: Sec.tasks),
    Box(
      border: K.coral,
      pad: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('متأخرة', style: tx(14, w: bold, c: K.coral)),
          gap(6),
          for (final t in const [
            ('احجز الضيافة', 'كان قبل 5 نوفمبر · متأخرة 4 أيام', 'عليك'),
            ('اطلب عرض من مصورين', 'كان قبل 1 نوفمبر · متأخرة 8 أيام', 'صالح'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertCircle, size: 19, color: K.coral),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text(t.$1, style: tx(15.5, w: bold)), Text('${t.$2} · ${t.$3}', style: tx(12.5, c: K.muted))],
                    ),
                  ),
                  softAction('أجّل', fg: K.saffronInk, bg: K.saffronSoft),
                ],
              ),
            ),
        ],
      ),
    ),
    gap(12),
    gNote('التأخير ما يأثر على الموعد. نبلّغك بس إذا مهمة متأخرة توقف شيء ثاني، مثل الدعوات قبل الضيافة.',
        c: K.saffronInk, bg: K.saffronSoft),
  ],
);

// ============================================================ الضيوف

Widget vGuestGroups() {
  Widget g(String n, String c, Color col) => listRow(
    icon: LucideIcons.users, fg: col, soft: col.withValues(alpha: 0.12), title: n, sub: c,
    trailing: const Icon(LucideIcons.gripVertical, size: 18, color: K.faint),
  );
  return Phone(
    nav: Sec.guests,
    children: [
      subHeader('المجموعات', sub: 'رتّب ضيوفك'),
      Row(children: [chip('أهلنا', on: true, onBg: K.lilac, fs: 13), const SizedBox(width: 8), chip('أهل العروسة', fs: 13)]),
      gap(12),
      whiteList([
        g('الأهل', '42 ضيف', K.lilac),
        g('الحارة', '35 ضيف', K.lilac),
        g('زملاء الشغل', '28 ضيف', K.lilac),
        g('أصحاب الجامعة', '19 ضيف', K.lilac),
        g('بدون مجموعة', '16 ضيف', K.faint),
      ]),
      gap(12),
      btn('مجموعة جديدة', wide: true, v: 14, bg: K.lilacSoft, fg: K.lilac, icon: LucideIcons.plus),
      gap(10),
      Text('حذف مجموعة ما يحذف ضيوفها، ينقلهم "بدون مجموعة".', style: tx(13, c: K.muted)),
    ],
  );
}

Widget vBulkGuests() => Phone(
  nav: Sec.guests,
  bottom: gBottom(btn('أضف 12 ضيف', wide: true, v: 16, fs: 17, bg: K.lilac)),
  children: [
    subHeader('أضف مجموعة ضيوف'),
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: K.lilac, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in const [('عبدالله الحمدي', '771234567'), ('يحيى السنيدار', ''), ('أحمد ناجي', '733445566')])
            Text('${l.$1} ${l.$2}', style: tx(15, h: 1.6)),
          Text('…', style: tx(15, h: 1.6)),
        ],
      ),
    ),
    gap(6),
    Text('الصق قائمة: اسم في كل سطر، والرقم اختياري.', style: tx(13, c: K.muted)),
    sectionTitle('فهمناها كذا'),
    whiteList([
      listRow(icon: LucideIcons.user, fg: K.lilac, soft: K.lilacSoft, title: 'عبدالله الحمدي', sub: ltr('771 234 567')),
      listRow(icon: LucideIcons.user, fg: K.lilac, soft: K.lilacSoft, title: 'يحيى السنيدار', sub: 'بدون رقم'),
      listRow(icon: LucideIcons.copy, fg: K.saffronInk, soft: K.saffronSoft, title: 'أحمد ناجي', sub: 'موجود من قبل · ما نضيفه مرتين'),
    ]),
    gap(12),
    Row(
      children: [
        Text('المجموعة:', style: tx(14, c: K.muted)),
        const SizedBox(width: 8),
        chip('الحارة', on: true, onBg: K.lilac, fs: 13),
        const SizedBox(width: 8),
        chip('أهلنا', on: true, onBg: K.lilac, fs: 13),
      ],
    ),
  ],
);

Widget vGuestsOffline() => Phone(
  nav: Sec.guests,
  children: [
    tabHeader('الضيوف', '140 ضيف', sec: Sec.guests),
    offlineBar(),
    gap(10),
    Box(
      c: K.line,
      pad: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(LucideIcons.eye, size: 18, color: K.muted),
          const SizedBox(width: 8),
          Expanded(child: Text('تشوف القائمة. الإضافة والدعوات لما يرجع النت.', style: tx(13.5, w: bold, c: K.muted))),
        ],
      ),
    ),
    gap(12),
    whiteList([
      listRow(icon: LucideIcons.user, fg: K.lilac, soft: K.lilacSoft, title: 'عبدالله الحمدي', sub: 'الأهل · أكد',
          trailing: tag('أكد', K.green, K.greenSoft)),
      listRow(icon: LucideIcons.user, fg: K.lilac, soft: K.lilacSoft, title: 'يحيى السنيدار', sub: 'الحارة · ما رد',
          trailing: tag('ما رد', K.muted, K.line)),
      listRow(icon: LucideIcons.user, fg: K.lilac, soft: K.lilacSoft, title: 'أحمد ناجي', sub: 'الشغل · اعتذر',
          trailing: tag('اعتذر', K.coral, K.coralSoft)),
    ]),
    gap(10),
    Text('آخر تحديث قبل 20 دقيقة', style: tx(13, c: K.muted)),
  ],
);

// ============================================================ المزودين

Widget vDirectoryFilters() => Phone(
  nav: Sec.providers,
  sheet: sheet(
    title: 'فلتر',
    children: [
      Text('القسم', style: tx(14, w: bold, c: K.muted)),
      gap(8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        chip('مصورين', on: true, onBg: K.sky, fs: 13),
        chip('قاعات', fs: 13),
        chip('ضيافة', fs: 13),
        chip('فرق', fs: 13),
        chip('زينة', fs: 13),
      ]),
      gap(14),
      Text('المكان', style: tx(14, w: bold, c: K.muted)),
      gap(8),
      Wrap(spacing: 8, runSpacing: 8, children: [chip('صنعاء', on: true, onBg: K.sky, fs: 13), chip('يجون من محافظة ثانية', fs: 13)]),
      gap(14),
      Text('السعر', style: tx(14, w: bold, c: K.muted)),
      gap(8),
      Wrap(spacing: 8, runSpacing: 8, children: [chip('أقل من 200 ألف', fs: 13), chip('200–500 ألف', on: true, onBg: K.sky, fs: 13), chip('أكثر', fs: 13)]),
      gap(14),
      Row(
        children: [
          Expanded(child: Text('فاضي يوم 21 يناير بس', style: tx(15, w: bold))),
          gToggle(true),
        ],
      ),
      gap(16),
      btn('اعرض 8 مصورين', wide: true, v: 16, fs: 17, bg: K.sky),
    ],
  ),
  children: [tabHeader('المزودين', '', sec: Sec.providers)],
);

Widget vOfferExpired() => Phone(
  nav: Sec.providers,
  children: [
    subHeader('عرض استوديو الضوء'),
    Box(
      c: K.line,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.clock, size: 20, color: K.muted),
              const SizedBox(width: 8),
              Text('العرض انتهى 5 نوفمبر', style: tx(16, w: bold, c: K.muted)),
            ],
          ),
          gap(8),
          Text('350 ألف · تصوير الزفاف وألبوم', style: tx(20, w: bold, c: K.muted)),
          Text('كان صالح 10 أيام', style: tx(13, c: K.muted)),
        ],
      ),
    ),
    gap(14),
    btn('اطلب عرض جديد', wide: true, v: 15, bg: K.sky, icon: LucideIcons.refreshCw),
    gap(10),
    btn('ما أبغاه، سكّر الطلب', wide: true, v: 15, bg: K.surface, fg: K.muted),
    gap(14),
    gNote('السعر ممكن يتغير في العرض الجديد. الطلبات المسكرة تنحفظ في "السابقة".',
        c: K.sky, bg: K.skySoft),
  ],
);

Widget vChatMenu() => Phone(
  nav: Sec.providers,
  sheet: sheet(
    title: 'فرقة الأفراح',
    children: [
      whiteList([
        listRow(icon: LucideIcons.bellOff, fg: K.ink, soft: K.bg, title: 'كتم المحادثة', sub: 'الرسائل توصل بدون تنبيه', trailing: gToggle(false)),
        listRow(icon: LucideIcons.flag, fg: K.saffronInk, soft: K.saffronSoft, title: 'بلّغ عن مشكلة', sub: 'تأخير، كلام غير لائق، احتيال'),
        listRow(icon: LucideIcons.ban, fg: K.coral, soft: K.coralSoft, title: 'احظر المزود', sub: 'ما يقدر يراسلك، وطلباتك معه تتسكر'),
      ]),
      gap(12),
      gNote('الحظر ما يلغي الحجز المؤكد. ألغه من "الحجوزات" لو تبغى.', c: K.coral, bg: K.coralSoft, i: LucideIcons.info),
    ],
  ),
  children: [subHeader('فرقة الأفراح')],
);

Widget vProviderStatus() {
  Widget p(String n, String s, Widget badge, String price) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: card(),
    child: Row(
      children: [
        iconTile(LucideIcons.camera, K.sky, K.skySoft, s: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Flexible(child: Text(n, style: tx(16, w: bold))), const SizedBox(width: 6), badge]),
              Text(s, style: tx(12.5, c: K.muted)),
              gap(4),
              Text(price, style: tx(13.5, w: bold, c: K.sky)),
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    nav: Sec.providers,
    children: [
      tabHeader('المصورين', 'صنعاء', sec: Sec.providers),
      p('استوديو الضوء', 'موثّق: تأكدنا من السجل والرقم',
          const Icon(LucideIcons.badgeCheck, size: 18, color: K.sky), 'من 300 ألف · محدّث هذا الشهر'),
      p('عدسة صنعاء', 'ما وثّق بعد', tag('جديد', K.muted, K.line), 'من 250 ألف · محدّث قبل 8 شهور'),
      p('مصور الحارة', 'الملف أضفناه من دليل عام، صاحبه ما استلمه',
          tag('غير مفعّل', K.saffronInk, K.saffronSoft), 'ما فيه سعر · تقدر تطلب عرض'),
      gap(4),
      gNote('السعر القديم ممكن تغير. اطلب عرض تتأكد. والمزود غير المفعّل نرسل له طلبك على واتساب يفعّل ملفه.',
          c: K.sky, bg: K.skySoft),
    ],
  );
}

Widget vBookingStates() {
  Widget b(String n, String s, Widget t, {String? act}) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Expanded(child: Text(n, style: tx(16, w: bold))), t]),
        Text(s, style: tx(13, c: K.muted)),
        if (act != null) ...[gap(10), softAction(act, fg: K.sky, bg: K.skySoft)],
      ],
    ),
  );
  return Phone(
    nav: Sec.providers,
    children: [
      tabHeader('الحجوزات', '21 يناير', sec: Sec.providers),
      b('قاعة سبأ', 'أكدوا 2 نوفمبر · نذكّركم قبل بأسبوع وبيوم', tag('محجوز', K.green, K.greenSoft)),
      b('ضيافة الأصالة', 'طلبت 7 نوفمبر · يردون عادة خلال يوم', tag('ينتظر تأكيدهم', K.saffronInk, K.saffronSoft),
          act: 'ذكّرهم'),
      b('فرقة الأفراح', 'اعتذروا: محجوزين ذاك اليوم', tag('اعتذر المزود', K.coral, K.coralSoft),
          act: 'شوف فرق فاضية يوم 21'),
      b('استوديو الضوء', 'لغيته أنت 1 نوفمبر', tag('ملغي', K.muted, K.line), act: 'اطلب حجز مرة ثانية'),
    ],
  );
}

Widget vRateLocked() => Phone(
  nav: Sec.providers,
  children: [
    subHeader('قاعة سبأ'),
    gap(16),
    Center(child: iconTile(LucideIcons.star, K.saffronInk, K.saffronSoft, s: 76, r: 24)),
    gap(14),
    Center(child: Text('التقييم بعد العرس', style: tx(23, w: bold))),
    gap(6),
    Center(
      child: Text('تقيّم المزود بعد يوم الحجز بس، عشان كل تقييم يكون من تجربة حقيقية.',
          textAlign: TextAlign.center, style: tx(15, c: K.muted, h: 1.5)),
    ),
    gap(18),
    gNote('نذكّرك يوم 22 يناير. التقييم يطلع باسمك الأول بس.', i: LucideIcons.bell),
  ],
);

// ============================================================ المساعد

Widget vAiConsent() => Phone(
  sheet: sheet(
    title: 'المساعد الذكي',
    sub: 'يفهم كلامك ويقرأ الفواتير ويقترح',
    children: [
      Box(
        pad: const EdgeInsets.all(14),
        child: Column(
          children: [
            gEffect(LucideIcons.send, 'اللي تكتبه أو تصوره يروح لخدمة ذكاء اصطناعي تفهمه', c: K.teal),
            gEffect(LucideIcons.eyeOff, 'ما نرسل أسماء ضيوفك ولا أرقامهم', c: K.teal),
            gEffect(LucideIcons.checkCircle2, 'ما يحفظ شيء في خطتك إلا بعد ما توافق أنت', c: K.teal),
            gEffect(LucideIcons.gauge, '30 طلب في اليوم', c: K.teal),
          ],
        ),
      ),
      gap(14),
      btn('شغّل المساعد', wide: true, v: 16, fs: 17, icon: LucideIcons.sparkles),
      gap(10),
      Center(child: Text('مو الحين', style: tx(14.5, w: bold, c: K.muted))),
      gap(8),
      Center(child: Text('تقدر توقفه من الحساب › الخصوصية', style: tx(12.5, c: K.muted))),
    ],
  ),
  children: [gap(20)],
);

Widget vAiLimit() {
  Widget st(IconData i, Color c, Color soft, String t, String s, String act) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: card(),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        iconTile(i, c, soft, s: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: tx(16.5, w: bold)),
              Text(s, style: tx(13.5, c: K.muted, h: 1.45)),
              gap(10),
              softAction(act, fg: c, bg: soft),
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    children: [
      subHeader('المساعد', sub: 'لما ما يقدر'),
      st(LucideIcons.gauge, K.saffronInk, K.saffronSoft, 'خلصت طلبات اليوم',
          'استخدمت الـ30. ترجع بكرة الساعة 12 الليل.', 'سجّل يدوي'),
      st(LucideIcons.scanLine, K.coral, K.coralSoft, 'ما قدرت أقرأ الفاتورة',
          'الصورة مظلمة أو مقصوصة. جرّب في ضوء أحسن.', 'صوّر مرة ثانية'),
      st(LucideIcons.helpCircle, K.sky, K.skySoft, 'ما فهمت قصدك',
          '"دفعت للحمدي" — الحمدي المصور ولا القاعة؟', 'اختر البند'),
      st(LucideIcons.wifiOff, K.muted, K.line, 'المساعد يحتاج نت',
          'كل شيء ثاني شغّال بدون نت.', 'سجّل يدوي'),
    ],
  );
}

/// Numbers that need others' data say so when there isn't enough of it.
Widget vNotEnoughData() => Phone(
  nav: Sec.guests,
  children: [
    subHeader('كم بيحضر؟'),
    Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('من ردود ضيوفك', style: tx(13, c: K.muted)),
          Text('62 أكدوا من 140', style: tx(26, w: bold)),
          gap(8),
          bar(0.44, K.lilac, h: 10),
          gap(8),
          Text('78 لسا ما ردوا', style: tx(13.5, c: K.muted)),
        ],
      ),
    ),
    gap(12),
    Box(
      c: K.line,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.barChart3, size: 20, color: K.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text('التوقع يطلع لما يرد نص ضيوفك على الأقل. ما نخمّن من عندنا.',
                style: tx(14, w: bold, c: K.muted, h: 1.45)),
          ),
        ],
      ),
    ),
    gap(14),
    btn('ذكّر اللي ما ردوا', wide: true, v: 15, bg: K.lilac, icon: LucideIcons.send),
  ],
);

// ============================================================ عام

Widget vPushOff() => Phone(
  nav: Sec.home,
  children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Row(children: [Expanded(child: Text('أهلًا محمد', style: tx(24, w: bold))), avatar('م', K.saffron, s: 44)]),
    ),
    Box(
      border: K.saffron,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconTile(LucideIcons.bellOff, K.saffronInk, K.saffronSoft, s: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('التنبيهات مقفلة', style: tx(16.5, w: bold)),
                Text('ما راح يوصلك موعد قسط ولا رد مزود. افتحها من إعدادات الجوال.',
                    style: tx(13.5, c: K.muted, h: 1.45)),
                gap(10),
                Row(
                  children: [
                    btn('افتح الإعدادات', v: 10, fs: 14, bg: K.saffronInk),
                    const SizedBox(width: 8),
                    btn('لاحقًا', v: 10, fs: 14, bg: K.bg, fg: K.muted),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ],
);

Widget vPrivacy() {
  Widget r(String t, String s, bool on) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(t, style: tx(15, w: bold)), Text(s, style: tx(12.5, c: K.muted))],
          ),
        ),
        gToggle(on),
      ],
    ),
  );
  return Phone(
    children: [
      subHeader('الخصوصية'),
      whiteList([
        r('أرسل تقارير الأعطال', 'بدون أسماء ولا مبالغ. تساعدنا نصلّح', true),
        r('المساعد الذكي', '30 طلب في اليوم', true),
        r('اسمي في التقييمات', 'الاسم الأول بس', true),
      ], dividers: false),
      gap(12),
      whiteList([
        listRow(icon: LucideIcons.download, fg: K.teal, soft: K.tealSoft, title: 'نزّل بياناتي', sub: 'ملف فيه خطتك كاملة'),
        listRow(icon: LucideIcons.smartphone, fg: K.teal, soft: K.tealSoft, title: 'الأجهزة', sub: '3 أجهزة'),
        listRow(icon: LucideIcons.userX, fg: K.coral, soft: K.coralSoft, title: 'حذف الحساب', sub: 'بعد 30 يوم'),
      ]),
    ],
  );
}

Widget vPendingQueue() => Phone(
  nav: Sec.money,
  sheet: sheet(
    title: '3 تغييرات تنتظر النت',
    sub: 'محفوظة على جوالك، وتنرسل أول ما يرجع',
    children: [
      whiteList([
        listRow(icon: LucideIcons.receipt, fg: K.teal, soft: K.tealSoft, title: 'دفعة للمصور 150 ألف', sub: 'قبل 10 دقايق',
            trailing: const Icon(LucideIcons.clock, size: 18, color: K.faint)),
        listRow(icon: LucideIcons.checkCircle2, fg: K.saffronInk, soft: K.saffronSoft, title: 'خلّصت "احجز القاعة"', sub: 'قبل 7 دقايق',
            trailing: const Icon(LucideIcons.clock, size: 18, color: K.faint)),
        listRow(icon: LucideIcons.alertCircle, fg: K.coral, soft: K.coralSoft, title: 'ضيف: يحيى السنيدار', sub: 'صالح عدّله قبلك · اختر أي نسخة',
            trailing: softAction('حل', fg: K.coral, bg: K.coralSoft)),
      ]),
      gap(12),
      btn('حاول الحين', wide: true, v: 15, icon: LucideIcons.refreshCw),
    ],
  ),
  children: [tabHeader('المال', '', sec: Sec.money), offlineBar()],
);

/// The four states every list screen has, shown on the guests list.
Widget vSectionStates() {
  Widget frame(String t, Widget body) => Expanded(
    child: Container(
      height: 230,
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(12),
      decoration: card(r: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Text(t, style: tx(12.5, w: bold, c: K.muted)), gap(10), Expanded(child: body)],
      ),
    ),
  );
  Widget sk() => Container(height: 34, margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: K.line, borderRadius: BorderRadius.circular(10)));
  Widget mid(IconData i, Color c, Color s, String a, String b) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      iconTile(i, c, s, s: 48),
      gap(8),
      Text(a, textAlign: TextAlign.center, style: tx(14, w: bold)),
      gap(6),
      softAction(b, fg: c, bg: s),
    ],
  );
  return Phone(
    children: [
      subHeader('حالات كل قائمة', sub: 'مثال: الضيوف'),
      Row(children: [
        frame('يحمّل', Column(children: [sk(), sk(), sk(), sk()])),
        frame('فاضية', mid(LucideIcons.userPlus, K.lilac, K.lilacSoft, 'ما أضفت ضيوف', 'أضف أول ضيف')),
      ]),
      Row(children: [
        frame('خطأ', mid(LucideIcons.alertTriangle, K.coral, K.coralSoft, 'ما قدرنا نجيبها', 'حاول مرة ثانية')),
        frame('بدون نت', mid(LucideIcons.wifiOff, K.muted, K.line, 'آخر نسخة محفوظة', 'تشوف بس')),
      ]),
      gap(10),
      gNote('كل قائمة في التطبيق لها هذي الأربع. الخطأ ما يمسح اللي قدامك، يطلع فوقه.'),
    ],
  );
}
