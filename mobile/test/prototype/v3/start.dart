// Journey prototype v3: the start. Two question screens after «خطة مين؟»:
// name + date, then place + budget. The bride's name is never asked in the
// groom's journey (owner decision 2026-10-21).
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';

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
    total: 4,
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
      child: Text('عرس محمد · صنعاء · 13 شعبان', style: tx(15, c: K.muted)),
    ),
    gap(20),
    Box(
      pad: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          listRow(
            icon: LucideIcons.wallet,
            fg: K.teal,
            soft: K.tealSoft,
            title: '11 بند لعرسك',
            sub: 'القاعة والوليمة والقات والتصوير والزفة وغيرها',
          ),
          listRow(
            icon: LucideIcons.listChecks,
            fg: K.saffronInk,
            soft: K.saffronSoft,
            title: '20 مهمة مرتبة على موعدك',
            sub: 'أولها: تحديد الميزانية وتوزيعها',
          ),
          listRow(
            icon: LucideIcons.store,
            fg: K.sky,
            soft: K.skySoft,
            title: 'مزودين صنعاء بأسعارهم',
            sub: 'قاعات ومصورين ومنشدين',
          ),
        ],
      ),
    ),
    gap(14),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        'تشيل وتضيف براحتك، والمهام تمشي مع الموعد لو تغيّر.',
        style: tx(13.5, c: K.faint),
      ),
    ),
  ],
);

Widget _label(String t) => Padding(
  padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
  child: Text(
    t,
    style: tx(14, w: bold, c: K.muted),
  ),
);

Widget _later(String t) => Padding(
  padding: const EdgeInsets.only(top: 10),
  child: Row(
    children: [
      Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: K.line, width: 2),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        t,
        style: tx(14.5, w: bold, c: K.muted),
      ),
    ],
  ),
);

/// Step 1 of 2: the groom's name and the wedding month (exact day optional).
Widget vNameDate() {
  Widget month(String m, String h, {bool on = false}) => Container(
    padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: BoxDecoration(
      color: on ? K.teal : Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: on ? null : Border.all(color: K.line),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          m,
          style: tx(16, w: bold, c: on ? Colors.white : K.ink),
        ),
        Text(h, style: tx(11.5, c: on ? Colors.white70 : K.muted)),
      ],
    ),
  );
  return questionScreen(
    step: 0,
    total: 4,
    q: 'أهلًا بك! ايش اسمك، ومتى العرس؟',
    help: 'نناديك باسمك، ونرتب المهام والدفعات على الموعد.',
    body: [
      field('اسمك', 'محمد', big: true),
      gap(8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            const Icon(LucideIcons.sparkles, color: K.teal, size: 16),
            const SizedBox(width: 6),
            Text('خطتك بتكون: ', style: tx(13.5, c: K.muted)),
            Text(
              'عرس محمد',
              style: tx(13.5, w: bold, c: K.teal),
            ),
          ],
        ),
      ),
      gap(20),
      _label('شهر العرس'),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.9,
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
      gap(10),
      Container(
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: K.line),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.calendarDays, size: 18, color: K.muted),
            const SizedBox(width: 10),
            Text('اليوم بالضبط (اختياري)', style: tx(13, c: K.muted)),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('الخميس 21 يناير', style: tx(15, w: bold)),
                Text(
                  '13 شعبان 1448',
                  style: tx(12.5, w: bold, c: K.teal),
                ),
              ],
            ),
          ],
        ),
      ),
      gap(10),
      Box(
        c: K.saffronSoft,
        pad: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(LucideIcons.moon, size: 17, color: K.saffronInk),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'قبل رمضان بـ 18 يوم، والحجوزات تكثر قبل رمضان. احجز القاعة بدري.',
                style: tx(13, w: bold, c: K.saffronInk),
              ),
            ),
          ],
        ),
      ),
      _later('ما حددنا الموعد بعد'),
    ],
  );
}

/// Step 2 of 2: the city and a rough budget, then the plan is prepared.
Widget vPlaceBudget() {
  Widget opt(String a, String b, {bool on = false}) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
    decoration: card(r: 16, border: on ? K.teal : null),
    child: Row(
      children: [
        Expanded(
          child: Text(a, style: tx(16.5, w: bold)),
        ),
        Text(b, style: tx(13, c: K.muted)),
        const SizedBox(width: 12),
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? K.teal : Colors.transparent,
            border: Border.all(color: on ? K.teal : K.line, width: 2),
          ),
          child: on
              ? const Icon(LucideIcons.check, size: 13, color: Colors.white)
              : null,
        ),
      ],
    ),
  );
  return questionScreen(
    step: 1,
    total: 4,
    q: 'وين العرس، وكم ميزانيتك تقريبًا؟',
    help: 'نعرض لك مزودين وأسعار من مدينتك. رقم تقريبي يكفي.',
    primary: 'جهّز خطتي',
    body: [
      _label('المدينة'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('صنعاء', on: true, icon: LucideIcons.mapPin, fs: 15),
          for (final c in ['عدن', 'تعز', 'إب', 'الحديدة', 'ذمار', 'المكلا'])
            chip(c, fs: 15),
          chip('مدينة ثانية', icon: LucideIcons.plus, fs: 15),
        ],
      ),
      gap(22),
      _label('الميزانية تقريبًا (بالريال اليمني)'),
      opt('أقل من 5 مليون', 'عرس بسيط'),
      opt('5 إلى 10 مليون', 'عرس متوسط', on: true),
      opt('10 إلى 20 مليون', 'عرس كبير'),
      opt('أكثر من 20 مليون', ''),
      _later('أكمل بدون ميزانية'),
      gap(10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text('تقدر تغيّرها بعدين من الفلوس.', style: tx(13, c: K.faint)),
      ),
    ],
  );
}
