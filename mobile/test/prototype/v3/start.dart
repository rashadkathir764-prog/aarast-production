// Journey prototype v3: the start, now five questions with the women's side.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';

Widget vName() => questionScreen(
  step: 0,
  total: 5,
  q: 'أهلًا بك! وش اسمك؟',
  help: 'نناديك فيه، ونسمي خطتك باسمكم.',
  body: [
    field('اسمك', 'محمد', big: true, focused: true),
    gap(12),
    field('اسم العروسة (اختياري)', 'سلمى', big: true),
    gap(16),
    Box(
      c: K.tealSoft,
      child: Row(
        children: [
          const Icon(LucideIcons.sparkles, color: K.teal, size: 20),
          const SizedBox(width: 10),
          Text('خطتك بتكون: ', style: tx(15, c: K.muted)),
          Text(
            'عرس محمد وسلمى',
            style: tx(15, w: bold, c: K.teal),
          ),
        ],
      ),
    ),
  ],
);

Widget vDate() {
  Widget month(String m, String h, {bool on = false}) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: on ? K.teal : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: on ? null : Border.all(color: K.line),
    ),
    child: Column(
      children: [
        Text(
          m,
          style: tx(17, w: bold, c: on ? Colors.white : K.ink),
        ),
        Text(h, style: tx(12, c: on ? Colors.white70 : K.muted)),
      ],
    ),
  );
  return questionScreen(
    step: 1,
    total: 5,
    q: 'متى العرس؟',
    help: 'نرتب لك المهام والدفعات على موعده.',
    skip: 'ما حددنا الموعد بعد',
    body: [
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.45,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          month('ديسمبر', 'جمادى الآخرة'),
          month('يناير', 'رجب · شعبان', on: true),
          month('فبراير', 'شعبان · رمضان'),
          month('مارس', 'رمضان · شوال'),
          month('أبريل', 'شوال · القعدة'),
          month('مايو', 'القعدة · الحجة'),
        ],
      ),
      gap(14),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: K.line),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.calendarDays, size: 20, color: K.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اليوم بالضبط (إذا تعرفه)', style: tx(12.5, c: K.muted)),
                  Text('الخميس 21 يناير', style: tx(17, w: bold)),
                  Text(
                    '13 شعبان 1448',
                    style: tx(13.5, w: bold, c: K.teal),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      gap(12),
      Box(
        c: K.saffronSoft,
        pad: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(LucideIcons.moon, size: 18, color: K.saffronInk),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'قبل رمضان بـ 18 يوم. الأسعار عادة ترتفع قبل رمضان، فبدري أحسن.',
                style: tx(13.5, w: bold, c: K.saffronInk),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget vCity() => questionScreen(
  step: 2,
  total: 5,
  q: 'في أي مدينة العرس؟',
  help: 'نعرض لك مزودين وأسعار من مدينتك.',
  body: [
    Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        chip('صنعاء', on: true, icon: LucideIcons.mapPin, fs: 16),
        for (final c in [
          'عدن',
          'تعز',
          'إب',
          'الحديدة',
          'ذمار',
          'المكلا',
          'مأرب',
        ])
          chip(c, fs: 16),
        chip('مدينة ثانية', icon: LucideIcons.plus, fs: 16),
      ],
    ),
    gap(22),
    Box(
      child: Row(
        children: [
          iconTile(LucideIcons.mapPin, K.sky, K.skySoft),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'مكان العرس تحدده بعدين لما تحجز القاعة.',
              style: tx(14.5, c: K.muted),
            ),
          ),
        ],
      ),
    ),
  ],
);

Widget vMahr() {
  Widget row(
    String label,
    String amount,
    String words,
    String state,
    bool done,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: card(r: 18, border: done ? null : K.teal),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: tx(13, c: K.muted)),
              Text(amount, style: tx(26, w: bold)),
              Text(
                words,
                style: tx(13, w: bold, c: K.teal),
              ),
            ],
          ),
        ),
        done
            ? tag(state, K.green, K.greenSoft)
            : tag(state, K.saffronInk, K.saffronSoft),
      ],
    ),
  );
  return questionScreen(
    step: 3,
    total: 5,
    q: 'اتفقتوا على المهر؟',
    help: 'اللي بتسلّمه لأهل العروسة. نحسبه لحاله ونذكرك بموعد تسليمه.',
    skip: 'ما اتفقنا بعد',
    body: [
      row('المهر', '3,000,000', 'ثلاثة مليون ريال', 'باقي مليون', false),
      field('سلّمت منه', '2,000,000', icon: LucideIcons.checkCircle2),
      gap(10),
      field('موعد تسليم الباقي', '15 نوفمبر', icon: LucideIcons.calendarDays),
      gap(10),
      gap(4),
      Box(
        c: K.tealSoft,
        pad: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.heartHandshake, size: 18, color: K.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'تجهيز العروسة وعرس النساء عند أهلها. خطتك لعرسك أنت: عرس الرجال.',
                style: tx(13.5, w: bold, c: K.tealDark),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget vBudget() {
  Widget opt(String a, String b, {bool on = false}) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    decoration: card(r: 18, border: on ? K.teal : null),
    child: Row(
      children: [
        Expanded(
          child: Text(a, style: tx(18, w: bold)),
        ),
        Text(b, style: tx(14, c: K.muted)),
        const SizedBox(width: 12),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? K.teal : Colors.transparent,
            border: Border.all(color: on ? K.teal : K.line, width: 2),
          ),
          child: on
              ? const Icon(LucideIcons.check, size: 14, color: Colors.white)
              : null,
        ),
      ],
    ),
  );
  return questionScreen(
    step: 4,
    total: 5,
    q: 'كم ميزانيتك تقريبًا؟',
    help: 'لعرسك: القاعة والضيافة والقات والفنان. رقم تقريبي يكفي.',
    primary: 'جهّز خطتي',
    skip: 'ما أدري، ساعدني أحسبها',
    body: [
      opt('أقل من 5 مليون', 'عرس بسيط'),
      opt('5 إلى 10 مليون', 'الأكثر في صنعاء', on: true),
      opt('10 إلى 20 مليون', 'عرس كبير'),
      opt('أكثر من 20 مليون', ''),
      gap(4),
      Text(
        'بالريال اليمني (صنعاء). المهر محسوب لحاله.',
        style: tx(13.5, c: K.faint),
      ),
    ],
  );
}

Widget vReady() => Phone(
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
    child: Column(
      children: [
        btn(
          'احفظ خطتي برقم جوالي',
          wide: true,
          v: 16,
          fs: 17,
          icon: LucideIcons.phoneCall,
        ),
        gap(12),
        Text(
          'بعدين، خلني أشوف أول',
          style: tx(15, w: bold, c: K.muted),
        ),
      ],
    ),
  ),
  children: [
    gap(30),
    Center(
      child: Container(
        width: 110,
        height: 110,
        decoration: const BoxDecoration(
          color: K.tealSoft,
          shape: BoxShape.circle,
        ),
        child: const Icon(LucideIcons.partyPopper, size: 50, color: K.teal),
      ),
    ),
    gap(22),
    Center(
      child: Text('خطتك جاهزة يا محمد', style: tx(28, w: bold)),
    ),
    gap(4),
    Center(
      child: Text(
        'عرس محمد وسلمى · صنعاء · 13 شعبان',
        style: tx(15, c: K.muted),
      ),
    ),
    gap(20),
    Box(
      pad: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          listRow(
            icon: LucideIcons.calendarDays,
            fg: K.teal,
            soft: K.tealSoft,
            title: '3 مناسبات على أسبوع العرس',
            sub: 'السمرة، المقيل، الزفاف',
          ),
          listRow(
            icon: LucideIcons.wallet,
            fg: K.teal,
            soft: K.tealSoft,
            title: '9 بنود لعرسك في صنعاء',
            sub: 'القاعة والضيافة والقات والغداء والباقي',
          ),
          listRow(
            icon: LucideIcons.listChecks,
            fg: K.saffronInk,
            soft: K.saffronSoft,
            title: '32 مهمة على موعدك',
            sub: 'أولها هذا الأسبوع: احجز القاعة',
          ),
          listRow(
            icon: LucideIcons.heartHandshake,
            fg: K.teal,
            soft: K.tealSoft,
            title: 'المهر: 3 مليون',
            sub: 'سلّمت 2 · نذكرك بالباقي قبل موعده',
          ),
        ],
      ),
    ),
  ],
);
