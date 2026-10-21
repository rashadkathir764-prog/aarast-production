// Journey prototype: the start, from opening the app to the saved plan.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'kit.dart';

Widget splash() => Phone(
  statusLight: true,
  gradient: const LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [K.teal, K.tealDark],
  ),
  children: [
    SizedBox(
      height: 250,
      child: CustomPaint(
        painter: const QamariyaMark(alpha: 0.13, cx: 0.5, frieze: false),
      ),
    ),
    Center(child: wordmark(s: 64, c: Colors.white)),
    gap(14),
    Center(
      child: Text(
        'عرسك من أول ريال إلى آخر قسط',
        style: tx(17, c: Colors.white.withValues(alpha: 0.8)),
      ),
    ),
    gap(250),
    Center(
      child: SizedBox(
        width: 120,
        child: segments(
          3,
          1,
          on: Colors.white,
          now: K.saffron,
          off: Colors.white.withValues(alpha: 0.25),
          h: 4,
        ),
      ),
    ),
  ],
);

Widget whoAreYou() {
  Widget option(
    IconData i,
    String t,
    String s,
    Color fg,
    Color soft, {
    bool on = false,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: card(border: on ? K.teal : null),
    child: Row(
      children: [
        iconTile(i, fg, soft, s: 54, r: 18),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: tx(19, w: bold)),
              Text(s, style: tx(14, c: K.muted)),
            ],
          ),
        ),
        Icon(LucideIcons.chevronLeft, color: on ? K.teal : K.faint),
      ],
    ),
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.only(bottom: 34),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'عندك حساب؟  ',
              style: tx(15, c: K.muted),
            ),
            TextSpan(
              text: 'ادخل برقمك',
              style: tx(15, w: bold, c: K.teal),
            ),
          ],
        ),
      ),
    ),
    children: [
      gap(26),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: wordmark(s: 30),
      ),
      gap(26),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          'نرتب عرسك معك:\nفلوسه ومهامه وضيوفه وحجوزاته.',
          style: tx(27, w: bold, h: 1.3),
        ),
      ),
      gap(10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text('مين أنت؟', style: tx(17, c: K.muted)),
      ),
      gap(20),
      option(
        LucideIcons.user,
        'العريس',
        'أبدأ خطة عرسي',
        K.teal,
        K.tealSoft,
        on: true,
      ),
      option(
        LucideIcons.flower2,
        'العروسة',
        'أبدأ أو أنضم لخطة عرسنا',
        K.lilac,
        K.lilacSoft,
      ),
      option(
        LucideIcons.mail,
        'من الأهل',
        'وصلتني دعوة أساعد في عرس',
        K.saffronInk,
        K.saffronSoft,
      ),
      option(
        LucideIcons.store,
        'مزود خدمة',
        'قاعة، تصوير، فرقة، أو غيرها',
        K.sky,
        K.skySoft,
      ),
    ],
  );
}

Widget qName() => questionScreen(
  step: 0,
  q: 'أهلًا بك! ايش اسمك؟',
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

Widget qDate() {
  Widget month(String m, String y, {bool on = false}) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
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
        Text(y, style: tx(12.5, c: on ? Colors.white70 : K.muted)),
      ],
    ),
  );
  return questionScreen(
    step: 1,
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
          month('نوفمبر', '2026'),
          month('ديسمبر', '2026'),
          month('يناير', '2027', on: true),
          month('فبراير', '2027'),
          month('مارس', '2027'),
          month('أبريل', '2027'),
        ],
      ),
      gap(16),
      field(
        'اليوم بالضبط (إذا تعرفه)',
        'الخميس 21 يناير',
        icon: LucideIcons.calendarDays,
      ),
      gap(14),
      Center(child: tag('96 يوم من اليوم', K.teal, K.tealSoft)),
    ],
  );
}

Widget qCity() => questionScreen(
  step: 2,
  q: 'في أي مدينة العرس؟',
  help: 'نعرض لك مزودين وأسعار من مدينتك.',
  body: [
    Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        chip('صنعاء', on: true, icon: LucideIcons.mapPin, fs: 16),
        chip('عدن', fs: 16),
        chip('تعز', fs: 16),
        chip('إب', fs: 16),
        chip('الحديدة', fs: 16),
        chip('ذمار', fs: 16),
        chip('المكلا', fs: 16),
        chip('مأرب', fs: 16),
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
              'الحي والعنوان بالتفصيل تضيفه بعدين لما تحجز القاعة.',
              style: tx(14.5, c: K.muted),
            ),
          ),
        ],
      ),
    ),
  ],
);

Widget qBudget() {
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
    step: 3,
    q: 'كم ميزانيتك تقريبًا؟',
    help: 'رقم تقريبي يكفي. تقدر تغيره أي وقت.',
    primary: 'جهّز خطتي',
    skip: 'ما أدري، ساعدني أحسبها',
    body: [
      opt('أقل من 5 مليون', 'عرس بسيط'),
      opt('5 إلى 10 مليون', 'الأكثر في صنعاء', on: true),
      opt('10 إلى 20 مليون', 'عرس كبير'),
      opt('أكثر من 20 مليون', ''),
      gap(4),
      Text('بالريال اليمني (صنعاء)', style: tx(13.5, c: K.faint)),
    ],
  );
}

Widget planReady() => Phone(
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
    gap(40),
    Center(
      child: Container(
        width: 120,
        height: 120,
        decoration: const BoxDecoration(
          color: K.tealSoft,
          shape: BoxShape.circle,
        ),
        child: const Icon(LucideIcons.partyPopper, size: 54, color: K.teal),
      ),
    ),
    gap(26),
    Center(
      child: Text('خطتك جاهزة يا محمد', style: tx(28, w: bold)),
    ),
    gap(6),
    Center(
      child: Text(
        'جهزنا لك بداية عرس محمد وسلمى في صنعاء',
        style: tx(16, c: K.muted),
      ),
    ),
    gap(26),
    Box(
      pad: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          listRow(
            icon: LucideIcons.calendarDays,
            fg: K.teal,
            soft: K.tealSoft,
            title: '96 يوم على عرسك',
            sub: 'الخميس 21 يناير 2027',
          ),
          listRow(
            icon: LucideIcons.wallet,
            fg: K.teal,
            soft: K.tealSoft,
            title: '14 بند جاهز لعرس صنعاء',
            sub: 'القاعة، الذهب، المهر، التصوير، والباقي',
          ),
          listRow(
            icon: LucideIcons.listChecks,
            fg: K.saffronInk,
            soft: K.saffronSoft,
            title: '32 مهمة مرتبة على موعدك',
            sub: 'أولها هذا الأسبوع: احجز القاعة',
          ),
        ],
      ),
    ),
    gap(14),
    Center(
      child: Text(
        'احفظها عشان ما تضيع، وتقدر تشاركها مع سلمى وأهلك.',
        textAlign: TextAlign.center,
        style: tx(14, c: K.muted),
      ),
    ),
  ],
);

Widget otp() {
  Widget cell(String d, {bool on = false}) => Container(
    width: 64,
    height: 72,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: on ? K.teal : K.line, width: on ? 2 : 1),
    ),
    child: Text(d, style: tx(30, w: bold)),
  );
  return Phone(
    children: [
      subHeader(''),
      gap(10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text('أرسلنا لك رمز على واتساب', style: tx(28, w: bold)),
      ),
      gap(6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'إلى الرقم ',
                style: tx(16, c: K.muted),
              ),
              TextSpan(
                text: ltr('777 123 456'),
                style: tx(16, w: bold),
              ),
              TextSpan(
                text: '   تغيير',
                style: tx(16, w: bold, c: K.teal),
              ),
            ],
          ),
        ),
      ),
      gap(34),
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [cell('4'), cell('8'), cell('2', on: true), cell('')],
        ),
      ),
      gap(28),
      Center(
        child: Text(
          'ما وصلك؟ نعيد الإرسال بعد 0:42',
          style: tx(15, c: K.muted),
        ),
      ),
      gap(40),
      Box(
        c: K.tealSoft,
        child: Row(
          children: [
            const Icon(LucideIcons.checkCircle2, color: K.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'أول ما يكتمل الرمز تنحفظ خطتك وتدخل عليها.',
                style: tx(14.5, c: K.tealDark),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
