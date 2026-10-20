// Provider journey prototype: requests, from the first message to the review.
// One card per wedding carries the whole story: request, offer, booking.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import 'pkit.dart';

Widget _cust(String name, String sub, {Color c = K.teal}) => Row(
  children: [
    avatar(name.characters.first, c, s: 44),
    const SizedBox(width: 12),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(name, style: tx(17, w: bold)), Text(sub, style: tx(13, c: K.muted))],
      ),
    ),
  ],
);

Widget _facts() => Box(
  child: Column(
    children: [
      kv('المناسبة', 'الزفة · عرس رجال'),
      kv('اليوم', 'الخميس 21 يناير · 13 شعبان'),
      kv('الفترة', 'الليل · من بعد العشاء'),
      kv('المكان', 'قاعة سبأ، صنعاء'),
      kv('الضيوف', '124 تقريبًا'),
      kv('يبغى', 'صور وفيديو'),
    ],
  ),
);

// ============================================================ القائمة

Widget p15Requests() {
  Widget card(String l, Color c, String name, String what, String next, String s, {String? time}) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            avatar(l, c, s: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(name, style: tx(15.5, w: bold)), Text(what, style: tx(12.5, c: K.muted))],
              ),
            ),
            st(s),
          ],
        ),
        gap(10),
        Row(
          children: [
            const Icon(LucideIcons.arrowLeftCircle, size: 16, color: P.c),
            const SizedBox(width: 6),
            Expanded(child: Text(next, style: tx(13.5, w: bold, c: P.c))),
            if (time != null) Text(time, style: tx(12, c: K.muted)),
          ],
        ),
      ],
    ),
  );
  return pPhone(
    tab: PTab.requests,
    badge: 3,
    children: [
      pTop('الطلبات', '3 ينتظرون ردك'),
      Row(children: [pChip('جديد 3', on: true), const SizedBox(width: 8), pChip('ردّيت 5'), const SizedBox(width: 8), pChip('محجوز 9'), const SizedBox(width: 8), pChip('انتهى')]),
      gap(12),
      card('م', K.teal, 'محمد الحمدي', 'الزفة · الخميس 21 يناير · صور وفيديو', 'ردّ: باقي 6 أيام', 'جديد', time: 'أمس'),
      card('س', const Color(0xFFB4536A), 'سلمى الحمدي', 'حفلة نساء · الخميس 21 يناير · فريق نساء', 'ردّ: باقي 6 أيام', 'جديد', time: 'اليوم'),
      card('ع', K.sky, 'عادل الريمي', 'السمرة · الأربعاء 20 يناير', 'ردّ: باقي 7 أيام', 'جديد', time: 'قبل ساعة'),
      card('ف', K.saffronInk, 'فهد العمري', 'الزفة · 4 فبراير', 'أكّد الحجز: يبغى يحجز', 'قبلوا عرضك'),
    ],
  );
}

// ============================================================ طلب جديد

Widget p16Request() => pPhone(
  action: Row(
    children: [
      Expanded(child: pBtn('أرسل عرض', v: 15, fs: 16)),
      const SizedBox(width: 10),
      btn('اعتذر', bg: Colors.white, fg: K.muted, v: 15),
    ],
  ),
  children: [
    subHeader('طلب جديد', sub: 'وصل أمس 8 المساء'),
    _cust('محمد الحمدي', 'عريس · صنعاء'),
    gap(12),
    _facts(),
    gap(10),
    Box(
      pad: const EdgeInsets.all(14),
      child: Text('«نبغى تصوير الزفة من دخول العريس، ودرون عند الباب إذا ممكن»', style: tx(14.5, h: 1.6)),
    ),
    gap(10),
    Box(
      c: K.greenSoft,
      pad: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(LucideIcons.calendarCheck, color: K.green, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('ليلة الخميس عندك: باقي فريق 2 من 3 فرق رجال',
                style: tx(14, w: bold, c: K.green)),
          ),
        ],
      ),
    ),
    gap(10),
    Text('ميزانيته ورقمه ما يوصلونك إلا إذا شاركهم. تكلّم معه من «اسأل».', style: tx(12.5, c: K.muted)),
    gap(8),
    Center(child: Text('اسأله قبل ما ترد', style: tx(14, w: bold, c: P.c))),
  ],
);

/// Model 1: an order for a sales provider.
Widget p16Order() => pPhone(
  action: Row(
    children: [
      Expanded(child: pBtn('أقبل الطلب', v: 15, fs: 16)),
      const SizedBox(width: 10),
      btn('اعتذر', bg: Colors.white, fg: K.muted, v: 15),
    ],
  ),
  children: [
    subHeader('طلب جديد', sub: 'محلات الأناقة'),
    _cust('محمد الحمدي', 'عريس · صنعاء'),
    gap(12),
    whiteList([
      listRow(icon: LucideIcons.shirt, fg: P.c, soft: P.soft, title: 'ثوب أبيض × 2', sub: 'مقاس 56 · تفصيل',
          trailing: Text('70,000', style: tx(14.5, w: bold))),
      listRow(icon: LucideIcons.shirt, fg: P.c, soft: P.soft, title: 'كوت شتوي × 1', sub: 'مقاس 52',
          trailing: Text('60,000', style: tx(14.5, w: bold))),
      listRow(icon: LucideIcons.shirt, fg: P.c, soft: P.soft, title: 'شال كشميري × 1', sub: 'رمادي',
          trailing: Text('25,000', style: tx(14.5, w: bold))),
    ]),
    gap(10),
    Box(
      child: Column(
        children: [
          kv('المجموع', '155,000 ر.ي صنعاء'),
          kv('الاستلام', 'من المحل · الاثنين 18 يناير'),
          kv('ملاحظة', 'يبغى بروفة قبلها بأسبوع'),
        ],
      ),
    ),
    gap(10),
    pNote('تقدر تعدّل السعر أو الموعد في ردك قبل ما يأكد.', i: LucideIcons.pencil),
  ],
);

// ============================================================ العرض

Widget p17Offer() => pPhone(
  action: pBtn('شوف العرض قبل ما يوصله', icon: LucideIcons.eye),
  children: [
    subHeader('عرضك لمحمد', sub: 'الزفة · الخميس 21 يناير'),
    Row(children: [pChip('صور فقط'), const SizedBox(width: 8), pChip('صور وفيديو', on: true), const SizedBox(width: 8), pChip('مخصص')]),
    gap(12),
    Row(
      children: [
        Expanded(flex: 3, child: pField('السعر', '450,000', focused: true)),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: pField('العملة', 'ر.ي صنعاء')),
      ],
    ),
    gap(12),
    Box(
      pad: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('يشمل', style: tx(13, c: K.muted)),
          eff(LucideIcons.check, '300 صورة معدّلة', c: K.green),
          eff(LucideIcons.check, 'فيلم 10 دقايق', c: K.green),
          eff(LucideIcons.check, 'درون عند الباب', c: K.green),
          gap(4),
          Text('ما يشمل', style: tx(13, c: K.muted)),
          eff(LucideIcons.x, 'الألبوم المطبوع · إضافة 80,000', c: K.coral),
        ],
      ),
    ),
    gap(10),
    Row(
      children: [
        Expanded(child: pField('الدفعة المقدمة', '100,000')),
        const SizedBox(width: 10),
        Expanded(child: pField('الباقي', 'يوم العرس')),
      ],
    ),
    gap(10),
    Row(
      children: [
        Text('صالح لـ', style: tx(14, c: K.muted)),
        const SizedBox(width: 8),
        pChip('7 أيام'),
        const SizedBox(width: 8),
        pChip('10 أيام', on: true),
        const SizedBox(width: 8),
        pChip('14 يوم'),
      ],
    ),
  ],
);

Widget p18Decline() => pPhone(
  sheet: sheet(
    title: 'تعتذر من محمد؟',
    children: [
      pOption('مشغول ذاك اليوم', sub: 'نقفل ليلة الخميس في تقويمك؟', on: true),
      pOption('خارج منطقتي'),
      pOption('ما أقدم هذي الخدمة'),
      pOption('سبب ثاني'),
      gap(4),
      Box(
        pad: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('اللي يوصل محمد', style: tx(12.5, c: K.muted)),
            Text('«نعتذر، الفرق محجوزة ليلة 21 يناير. الله يتمم لك على خير.»', style: tx(14.5, h: 1.5)),
          ],
        ),
      ),
      gap(12),
      pBtn('أرسل الاعتذار'),
    ],
  ),
  children: [subHeader('طلب جديد')],
);

Widget p19OfferSent() => pPhone(
  tab: PTab.requests,
  children: [
    subHeader('محمد الحمدي', sub: 'الزفة · الخميس 21 يناير'),
    Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text('صور وفيديو', style: tx(17, w: bold))), st('ردّيت')]),
          Text('450,000 ر.ي صنعاء · نسخة 1', style: tx(14, c: K.muted)),
          gap(12),
          Row(
            children: [
              const Icon(LucideIcons.checkCheck, size: 18, color: K.sky),
              const SizedBox(width: 8),
              Text('شافه محمد اليوم 9 الصبح', style: tx(14, w: bold, c: K.sky)),
            ],
          ),
          gap(6),
          Row(
            children: [
              const Icon(LucideIcons.clock, size: 18, color: K.muted),
              const SizedBox(width: 8),
              Text('صالح لين 31 ديسمبر · باقي 8 أيام', style: tx(14)),
            ],
          ),
        ],
      ),
    ),
    gap(12),
    Row(
      children: [
        Expanded(child: pBtn('عدّل العرض', v: 13, fs: 15, bg: P.soft, fg: P.c, icon: LucideIcons.pencil)),
        const SizedBox(width: 10),
        Expanded(child: pBtn('اسحب العرض', v: 13, fs: 15, bg: Colors.white, fg: K.coral)),
      ],
    ),
    gap(12),
    pNote('التعديل يوصله نسخة 2 فيها «وش تغيّر». والسحب يقفل العرض ويوصله سطر هادي.'),
  ],
);

Widget p20Ended() {
  Widget c(IconData i, Color col, Color soft, String t, String s, String? act) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: card(),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        iconTile(i, col, soft, s: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: tx(16, w: bold)),
              Text(s, style: tx(13.5, c: K.muted, h: 1.45)),
              if (act != null) ...[gap(10), pSoft(act)],
            ],
          ),
        ),
      ],
    ),
  );
  return pPhone(
    tab: PTab.requests,
    children: [
      pTop('انتهى', 'اللي ما كمّل، وليش'),
      c(LucideIcons.clock, K.muted, K.line, 'عرضك لعادل انتهى', 'ما رد خلال 10 أيام. تجدده بنفس السعر أو بسعر جديد.', 'جدّد العرض'),
      c(LucideIcons.xCircle, K.coral, K.coralSoft, 'فهد اختار غيرك', 'السبب: «السعر فوق اللي حاسب له». الرقم اللي حاسبه ما يوصلك.', null),
      c(LucideIcons.ban, K.muted, K.line, 'خالد لغى الطلب', 'قبل ما ترد. ما عليك شيء.', null),
      c(LucideIcons.timerOff, K.coral, K.coralSoft, 'طلب يحيى انتهى بدون رد', '7 أيام ما رديت. هذا ينحسب في سرعة ردك.', null),
    ],
  );
}

// ============================================================ الحجز

Widget p21Confirm() {
  Widget team(String n, String s, {bool on = false, bool busy = false}) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: busy ? K.bg : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: on ? P.c : K.line, width: on ? 2 : 1),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(n, style: tx(15, w: bold, c: busy ? K.faint : K.ink)), Text(s, style: tx(12.5, c: K.muted))],
          ),
        ),
        if (busy) st('محجوز') else if (on) const Icon(LucideIcons.checkCircle2, color: P.c),
      ],
    ),
  );
  return pPhone(
    sheet: sheet(
      title: 'محمد قبل عرضك',
      sub: 'يبغى يحجز الزفة · الخميس 21 يناير · الليل',
      children: [
        Text('أي فريق؟', style: tx(14, w: bold, c: K.muted)),
        gap(8),
        team('فريق 1', 'محجوز لعرس عادل', busy: true),
        team('فريق 2', 'فاضي · صور وفيديو ودرون', on: true),
        team('فريق 3', 'فاضي · صور بس'),
        gap(6),
        pNote('نتأكد إن الفريق فاضي لحظة ما تضغط. لو انحجز في نفس الثانية، نقولك.', i: LucideIcons.shieldCheck),
        gap(12),
        pBtn('أكّد الحجز', icon: LucideIcons.check),
        gap(8),
        Center(child: Text('ما أقدر، اعتذر', style: tx(14, w: bold, c: K.muted))),
      ],
    ),
    children: [subHeader('محمد الحمدي')],
  );
}

Widget p22Booking() => pPhone(
  tab: PTab.requests,
  children: [
    subHeader('حجز محمد الحمدي', trailing: st('محجوز')),
    _facts(),
    gap(10),
    Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الاتفاق · نسخة 2', style: tx(13, c: K.muted)),
          Text('صور وفيديو · 450,000 ر.ي صنعاء', style: tx(16, w: bold)),
          gap(6),
          kv('الفريق', 'فريق 2'),
          kv('الدفعة المقدمة', '100,000 · وصلتك 12 ديسمبر', c: K.green),
          kv('الباقي', '350,000 · يوم العرس'),
          kv('التسليم', 'خلال 30 يوم من العرس'),
        ],
      ),
    ),
    gap(10),
    Box(
      pad: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(LucideIcons.bell, color: K.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('نذكّرك أنت ومحمد قبل بأسبوع وبيوم', style: tx(14))),
        ],
      ),
    ),
    gap(12),
    Row(
      children: [
        Expanded(child: pBtn('المحادثة', v: 13, fs: 15, bg: P.soft, fg: P.c, icon: LucideIcons.messageCircle)),
        const SizedBox(width: 10),
        Expanded(child: pBtn('إلغاء الحجز', v: 13, fs: 15, bg: Colors.white, fg: K.coral)),
      ],
    ),
  ],
);

Widget p23Deposit() => pPhone(
  sheet: sheet(
    title: 'وصلتك الدفعة المقدمة؟',
    sub: 'محمد سجّل إنه دفع لك',
    children: [
      Box(
        child: Column(
          children: [
            kv('المبلغ', '100,000 ر.ي صنعاء'),
            kv('الطريقة', 'حوالة الكريمي'),
            kv('التاريخ', 'الخميس 12 ديسمبر'),
          ],
        ),
      ),
      gap(10),
      Container(
        height: 110,
        decoration: BoxDecoration(color: P.soft, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Icon(LucideIcons.receipt, color: P.mid, size: 36)),
      ),
      gap(14),
      Row(
        children: [
          Expanded(child: pBtn('إيه، وصلت', v: 15, fs: 16)),
          const SizedBox(width: 10),
          Expanded(child: btn('ما وصلت', bg: Colors.white, fg: K.coral, v: 15)),
        ],
      ),
      gap(10),
      Text('التطبيق ما يستلم ولا يحوّل فلوس. هذا تسجيل يحفظ حق الطرفين.', style: tx(12.5, c: K.muted)),
    ],
  ),
  children: [subHeader('حجز محمد الحمدي')],
);

Widget p24Changed() => pPhone(
  sheet: sheet(
    title: 'محمد أجّل العرس',
    sub: 'من الخميس 21 يناير إلى الخميس 4 فبراير',
    children: [
      Box(
        c: K.greenSoft,
        pad: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(LucideIcons.calendarCheck, color: K.green),
            const SizedBox(width: 10),
            Expanded(child: Text('ليلة 4 فبراير عندك: فريق 2 فاضي', style: tx(14.5, w: bold, c: K.green))),
          ],
        ),
      ),
      gap(12),
      pOption('ثبّت الحجز على 4 فبراير', sub: 'نفس الاتفاق والدفعة المقدمة', on: true),
      pOption('ثبّته وعدّل العرض', sub: 'نسخة جديدة يوافق عليها محمد'),
      pOption('ما أقدر في اليوم الجديد', sub: 'نبلّغه، والدفعة المقدمة تتسجل كم رجع'),
      gap(6),
      pBtn('تمام'),
    ],
  ),
  children: [subHeader('حجز محمد الحمدي')],
);

Widget p25Cancelled() => pPhone(
  tab: PTab.requests,
  children: [
    subHeader('حجز فهد العمري', trailing: st('ملغي')),
    Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('فهد لغى الحجز', style: tx(18, w: bold)),
          Text('الزفة · الخميس 4 فبراير · أمس 6 المساء', style: tx(13.5, c: K.muted)),
          gap(8),
          Text('السبب: «العرس تأجل للصيف»', style: tx(14.5)),
        ],
      ),
    ),
    gap(10),
    Box(
      c: K.greenSoft,
      pad: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(LucideIcons.calendarPlus, color: K.green, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('رجع فريق 2 فاضي ليلة 4 فبراير', style: tx(14.5, w: bold, c: K.green))),
        ],
      ),
    ),
    sectionTitle('الدفعة المقدمة 100,000'),
    pOption('رجّعتها كاملة'),
    pOption('رجّعت جزء', sub: 'وكم خصمت'),
    pOption('ما ترجع', sub: 'حسب الاتفاق: «الدفعة المقدمة ما ترجع بعد 15 يوم»', on: true),
    gap(6),
    pBtn('سجّل'),
  ],
);

Widget p26After() => pPhone(
  tab: PTab.requests,
  children: [
    subHeader('عرس محمد الحمدي', sub: 'الخميس 21 يناير'),
    Center(child: iconTile(LucideIcons.partyPopper, K.green, K.greenSoft, s: 72, r: 22)),
    gap(12),
    Center(child: Text('تم العرس؟', style: tx(23, w: bold))),
    gap(4),
    Center(child: Text('نحسب الحجز تم لو ما بلّغت خلال يومين.', style: tx(14.5, c: K.muted))),
    gap(16),
    pOption('إيه، تم', sub: 'ونذكّر محمد يقيّمك', on: true),
    pOption('ما صار', sub: 'لغوا في آخر لحظة، أو ما حضرنا'),
    pOption('ما صار بقرار رسمي أو ظرف قاهر', sub: 'ما يأثر على تقييمك'),
    gap(10),
    sectionTitle('التسليم'),
    Box(
      pad: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(LucideIcons.packageCheck, color: K.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('الصور والفيلم: وعدت خلال 30 يوم', style: tx(14.5))),
          pSoft('سلّمت'),
        ],
      ),
    ),
  ],
);

Widget p26Order() {
  Widget step(String t, String s, bool done, {bool now = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(done ? LucideIcons.checkCircle2 : (now ? LucideIcons.circleDot : LucideIcons.circle),
            color: done ? K.green : (now ? P.c : K.faint)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(t, style: tx(15.5, w: bold, c: done || now ? K.ink : K.faint)), Text(s, style: tx(12.5, c: K.muted))],
          ),
        ),
      ],
    ),
  );
  return pPhone(
    tab: PTab.requests,
    action: pBtn('جاهز للاستلام', icon: LucideIcons.packageCheck),
    children: [
      subHeader('طلب محمد الحمدي', sub: 'محلات الأناقة · 155,000'),
      Box(
        child: Column(
          children: [
            step('قبلت الطلب', '2 يناير', true),
            step('البروفة', 'الاثنين 11 يناير · تمت', true),
            step('جاهز', 'نبلّغ محمد يجي ياخذه', false, now: true),
            step('تسلّم', 'الاثنين 18 يناير', false),
          ],
        ),
      ),
      gap(12),
      pNote('لو ما جا يستلم في موعده، نذكّره ونذكّرك.'),
    ],
  );
}

Widget p27Review() => pPhone(
  tab: PTab.me,
  children: [
    subHeader('تقييم جديد'),
    Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('محمد', style: tx(16, w: bold)),
              const SizedBox(width: 8),
              for (var i = 0; i < 5; i++) Icon(LucideIcons.star, size: 17, color: i < 4 ? K.saffron : K.line),
            ],
          ),
          Text('الزفة · 21 يناير', style: tx(12.5, c: K.muted)),
          gap(10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            tag('التزم بالموعد', K.green, K.greenSoft),
            tag('شغل نظيف', K.green, K.greenSoft),
          ]),
          gap(10),
          Text('«الصور رهيبة، بس الفيلم تأخر أسبوعين عن الموعد.»', style: tx(15, h: 1.6)),
        ],
      ),
    ),
    gap(12),
    pField('ردك (مرة وحدة، يشوفه الكل)', 'شكرًا يا محمد، ونعتذر عن التأخير. ضغط الموسم، وعدّلنا طريقة التسليم.', focused: true),
    gap(12),
    pBtn('انشر الرد'),
    gap(10),
    Center(child: Text('فيه كلام مسيء أو كذب؟ بلّغ عنه', style: tx(13.5, w: bold, c: K.muted))),
  ],
);
