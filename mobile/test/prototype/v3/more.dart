// Journey prototype v3: the remaining groom screens (forms, details, states,
// account). Same plan, same numbers as the rest of the journey.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import '../c_journey/screens_home.dart' show homeHeader;

Widget _toggle(bool on) => Container(
  width: 44,
  height: 26,
  padding: const EdgeInsets.all(3),
  alignment: on ? Alignment.centerRight : Alignment.centerLeft,
  decoration: BoxDecoration(
    color: on ? K.teal : K.line,
    borderRadius: BorderRadius.circular(13),
  ),
  child: Container(
    width: 20,
    height: 20,
    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
  ),
);

Widget _label(String s) => Padding(
  padding: const EdgeInsets.only(bottom: 8, top: 14),
  child: Text(s, style: tx(14, w: bold, c: K.muted)),
);

Widget _info(String s, {Color c = K.teal, Color bg = K.tealSoft, IconData i = LucideIcons.info}) =>
    Box(
      c: bg,
      pad: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, size: 18, color: c),
          const SizedBox(width: 10),
          Expanded(child: Text(s, style: tx(13.5, w: bold, c: c))),
        ],
      ),
    );

Widget _bubble(String t, {bool me = false, String? time, Color? bg}) => Align(
  alignment: me ? Alignment.centerRight : Alignment.centerLeft,
  child: Container(
    constraints: const BoxConstraints(maxWidth: 290),
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
    decoration: BoxDecoration(
      color: bg ?? (me ? K.teal : Colors.white),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t, style: tx(14.5, c: me && bg == null ? Colors.white : K.ink, h: 1.5)),
        if (time != null) Text(time, style: tx(11, c: me && bg == null ? Colors.white70 : K.faint)),
      ],
    ),
  ),
);

// ============================================================ الدخول

Widget vLogin() => Phone(
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
    child: Column(
      children: [
        btn('أرسل الرمز على واتساب', wide: true, v: 16, fs: 17, icon: LucideIcons.send),
        gap(12),
        Text('أدخل بكلمة المرور بدل كذا', style: tx(14.5, w: bold, c: K.muted)),
      ],
    ),
  ),
  children: [
    subHeader(''),
    gap(20),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: wordmark(s: 26),
    ),
    gap(18),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text('أهلًا من جديد', style: tx(30, w: bold)),
    ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text('رقمك بس، وتلقى خطتك مثل ما تركتها.', style: tx(16, c: K.muted)),
    ),
    gap(26),
    Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: K.teal, width: 2),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Text('+967', style: tx(18, w: bold, c: K.muted)),
            const SizedBox(width: 12),
            Container(width: 1, height: 28, color: K.line),
            const SizedBox(width: 12),
            Text('777 123 456', style: tx(24, w: bold)),
          ],
        ),
      ),
    ),
    gap(8),
    Row(
      children: [
        const Icon(LucideIcons.checkCircle2, size: 15, color: K.green),
        const SizedBox(width: 6),
        Text('رقم يمن موبايل صحيح', style: tx(13, w: bold, c: K.green)),
      ],
    ),
  ],
);

// ============================================================ الرئيسية: إضافات

Widget vAssistant() => Phone(
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
    child: quickInput(text: 'اسأل عن عرسك…'),
  ),
  children: [
    subHeader('اسأل اعّرست', sub: 'يجاوبك من خطتك أنت، وما يخترع أسعار'),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('وش نسيت؟', icon: LucideIcons.listChecks),
        chip('وين أوفر؟', icon: LucideIcons.scissors),
        chip('اكتب رسالة تفاوض', icon: LucideIcons.messageCircle),
      ],
    ),
    gap(14),
    _bubble('كم أخصص للقات؟ عندي 124 ضيف', me: true, time: '9:20'),
    Container(
      padding: const EdgeInsets.all(16),
      decoration: card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sparkles, size: 16, color: K.teal),
              const SizedBox(width: 6),
              Text('من خطتك', style: tx(13, w: bold, c: K.teal)),
            ],
          ),
          gap(8),
          Text('خصصت مليون للقات، ودفعت منه 800 ألف.', style: tx(15, h: 1.6)),
          Text('لـ 124 ضيف هذا حوالي 8 آلاف للضيف، وهو داخل النطاق اللي سجله عرسان صنعاء على اعّرست (6 إلى 10 آلاف).',
              style: tx(15, h: 1.6)),
          gap(12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('لو قللت لـ 100 ضيف', style: tx(13, c: K.muted)),
                      Text('توفر حوالي 180 ألف', style: tx(16, w: bold, c: K.green)),
                    ],
                  ),
                ),
                softAction('جرّب "لو"'),
              ],
            ),
          ),
          gap(10),
          Text('اقتراح، والقرار لك.', style: tx(12.5, c: K.faint)),
        ],
      ),
    ),
    gap(6),
    Row(
      children: [
        Text('باقي لك اليوم 8 أسئلة', style: tx(12.5, c: K.faint)),
        const Spacer(),
        const Icon(LucideIcons.copy, size: 16, color: K.faint),
      ],
    ),
  ],
);

Widget vEvents() {
  Widget ev(String name, String date, String time, String place, IconData i, Color c, Color bg,
          {String? note}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: card(),
        child: Row(
          children: [
            iconTile(i, c, bg, s: 48, r: 16),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: tx(17, w: bold)),
                  Text('$date · $time', style: tx(13.5, c: K.muted)),
                  Text(place, style: tx(13.5, c: K.muted)),
                  if (note != null) ...[
                    gap(6),
                    tag(note, K.saffronInk, K.saffronSoft),
                  ],
                ],
              ),
            ),
            const Icon(LucideIcons.pencil, size: 17, color: K.faint),
          ],
        ),
      );
  return Phone(
    children: [
      subHeader('مناسبات عرسك', sub: 'منها يتبنى أسبوع العرس ويوم العرس'),
      ev('السمرة', 'الثلاثاء 19 يناير', 'بعد العشاء', 'الديوان', LucideIcons.moon, K.lilac,
          K.lilacSoft),
      ev('المقيل', 'الأربعاء 20 يناير', 'بعد الظهر', 'بيت الوالد', LucideIcons.leaf, K.green,
          K.greenSoft, note: 'القات عند صالح'),
      ev('الزفاف', 'الخميس 21 يناير', 'بعد العصر', 'قاعة سبأ · حدة', LucideIcons.partyPopper,
          K.teal, K.tealSoft, note: 'المناسبة الرئيسية'),
      gap(4),
      Text('اقتراحات', style: tx(14, w: bold, c: K.muted)),
      gap(8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('عقد القران', icon: LucideIcons.plus),
          chip('الغداء', icon: LucideIcons.plus),
          chip('مناسبة ثانية', icon: LucideIcons.plus),
        ],
      ),
    ],
  );
}

Widget vEventEdit() => Phone(
  sheet: sheet(
    title: 'المقيل',
    sub: 'يظهر في برنامج الأسبوع ويوم العرس',
    children: [
      Row(
        children: [
          Expanded(child: field('اليوم', 'الأربعاء 20', icon: LucideIcons.calendarDays)),
          const SizedBox(width: 8),
          Expanded(child: field('الهجري', '12 شعبان', icon: LucideIcons.moon)),
        ],
      ),
      _label('الوقت'),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('الضحى'),
          chip('بعد الظهر', on: true),
          chip('بعد العصر'),
          chip('بعد المغرب'),
          chip('بعد العشاء'),
          chip('ساعة محددة', icon: LucideIcons.clock),
        ],
      ),
      gap(14),
      field('المكان', 'بيت الوالد · الحصبة', icon: LucideIcons.mapPin),
      gap(10),
      field('مين مسؤول؟', 'صالح أخوي', icon: LucideIcons.user),
      gap(16),
      btn('حفظ', wide: true, v: 16, fs: 17),
    ],
  ),
  children: [subHeader('مناسبات عرسك')],
);

Widget vLoading() {
  Widget sk(double h, {double r = 22}) => Container(
    height: h,
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(color: const Color(0xFFE6EAE9), borderRadius: BorderRadius.circular(r)),
  );
  return Phone(
    nav: Sec.home,
    children: [
      homeHeader(),
      gap(18),
      sk(130, r: 28),
      sk(56, r: 20),
      Container(
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: card(),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: const Color(0xFFE6EAE9), borderRadius: BorderRadius.circular(16)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final w in const [0.4, 0.8, 0.6])
                    FractionallySizedBox(
                      widthFactor: w,
                      child: Container(
                        height: 12,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                            color: const Color(0xFFE6EAE9),
                            borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      Row(
        children: [
          Expanded(child: sk(110)),
          const SizedBox(width: 10),
          Expanded(child: sk(110)),
          const SizedBox(width: 10),
          Expanded(child: sk(110)),
        ],
      ),
      Center(child: Text('نجهز خطتك…', style: tx(14, w: bold, c: K.faint))),
    ],
  );
}

Widget vError() => Phone(
  nav: Sec.providers,
  children: [
    tabHeader('المزودين', 'محجوز 3 من 6'),
    gap(60),
    Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: const BoxDecoration(color: K.skySoft, shape: BoxShape.circle),
        child: const Icon(LucideIcons.cloudOff, size: 42, color: K.sky),
      ),
    ),
    gap(20),
    Center(child: Text('ما قدرنا نجيب المزودين', style: tx(22, w: bold))),
    gap(6),
    Center(
      child: Text('النت ضعيف أو الخادم مشغول. طلباتك ومحادثاتك المحفوظة تقدر تشوفها.',
          textAlign: TextAlign.center, style: tx(15, c: K.muted)),
    ),
    gap(22),
    Center(child: btn('حاول مرة ثانية', bg: K.sky, icon: LucideIcons.refreshCw)),
    gap(12),
    Center(child: Text('افتح طلباتي المحفوظة', style: tx(15, w: bold, c: K.sky))),
  ],
);

// ============================================================ المال: نماذج وتفاصيل

Widget vAddItem() => Phone(
  nav: Sec.money,
  sheet: sheet(
    title: 'بند جديد',
    sub: 'لعرسك، ويدخل في الميزانية',
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('الذهب', icon: LucideIcons.gem, on: true),
          chip('زينة البيت', icon: LucideIcons.lightbulb),
          chip('الألعاب النارية', icon: LucideIcons.sparkles),
          chip('السيارات', icon: LucideIcons.car),
          chip('الكروت', icon: LucideIcons.mail),
          chip('العطور والبخور', icon: LucideIcons.sparkles),
          chip('اسم ثاني', icon: LucideIcons.pencil),
        ],
      ),
      gap(14),
      amountField('كم تخصص له تقريبًا؟', '800,000', 'ثمانمية ألف ريال'),
      gap(10),
      Wrap(spacing: 8, children: [chip('ر.ي', on: true), chip('\$'), chip('ر.س'), chip('بالجرام', icon: LucideIcons.gem)]),
      gap(12),
      _info('الذهب ما يظهر في خطتك إلا لأنك أضفته. تقدر تسجله بالجرام والعيار.',
          c: K.saffronInk, bg: K.saffronSoft, i: LucideIcons.gem),
      gap(14),
      btn('أضف البند', wide: true, v: 16, fs: 17),
    ],
  ),
  children: [tabHeader('المال', 'ماشية، بس ناقصك 2.5 مليون')],
);

Widget vAddCost() {
  Widget pay(String n, String amount, String when, {bool first = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: first ? K.teal : K.tealSoft,
            shape: BoxShape.circle,
          ),
          child: Text(n, style: tx(13, w: bold, c: first ? Colors.white : K.teal)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(when, style: tx(14.5, w: bold))),
        Text(amount, style: tx(14.5, w: bold)),
      ],
    ),
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: btn('حفظ الاتفاق', wide: true, v: 16, fs: 17),
    ),
    children: [
      subHeader('اتفاق جديد', sub: 'مع مين اتفقت، وبكم، وكيف بتدفع'),
      Text('البند', style: tx(14, w: bold, c: K.muted)),
      gap(8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        chip('الفنان والفرقة', on: true, icon: LucideIcons.music),
        chip('التصوير', icon: LucideIcons.camera),
        chip('القات', icon: LucideIcons.leaf),
      ]),
      _label('مع مين؟'),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: card(border: K.teal),
        child: Row(
          children: [
            iconTile(LucideIcons.music, K.sky, K.skySoft, s: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('فرقة الأفراح', style: tx(16, w: bold)),
                  Text('من اعّرست · موثّق', style: tx(12.5, c: K.muted)),
                ],
              ),
            ),
            Text('تغيير', style: tx(14, w: bold, c: K.teal)),
          ],
        ),
      ),
      gap(12),
      amountField('بكم اتفقت؟', '400,000', 'أربعمية ألف ريال', focused: false),
      gap(4),
      Text('أقل من بندك بـ 100 ألف', style: tx(13, w: bold, c: K.green)),
      _label('كيف بتدفع؟'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        chip('مرة وحدة'),
        chip('عربون والباقي يوم العرس', on: true),
        chip('أقساط'),
      ]),
      gap(10),
      Box(
        child: Column(
          children: [
            pay('1', '100 ألف', 'العربون · اليوم', first: true),
            pay('2', '300 ألف', 'الباقي · يوم العرس'),
          ],
        ),
      ),
    ],
  );
}

Widget vPaymentDetail() {
  Widget r(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        SizedBox(width: 90, child: Text(k, style: tx(14, c: K.muted))),
        Expanded(child: Text(v, style: tx(15, w: bold))),
      ],
    ),
  );
  return Phone(
    children: [
      subHeader('دفعة القاعة', sub: 'الدفعة الأولى · العربون'),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: K.greenSoft,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            iconTile(LucideIcons.checkCircle2, K.green, Colors.white, s: 50, r: 16),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('500,000 ر.ي', style: tx(26, w: bold)),
                  Text('خمسمية ألف ريال · دُفعت', style: tx(13.5, w: bold, c: K.green)),
                ],
              ),
            ),
          ],
        ),
      ),
      gap(12),
      Box(
        pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            r('لمين', 'قاعة سبأ'),
            r('متى', '10 سبتمبر · 17 ربيع الأول'),
            r('من وين', 'مدخراتي'),
            r('كيف', 'نقدًا'),
            r('سجّلها', 'أنت'),
          ],
        ),
      ),
      sectionTitle('الإيصال'),
      Container(
        height: 220,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F3EA),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: K.line),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('قاعة سبأ للأفراح', style: tx(16, w: bold, c: K.muted)),
            gap(6),
            for (final w in const [0.9, 0.7, 0.8, 0.5])
              FractionallySizedBox(
                widthFactor: w,
                child: Container(
                  height: 8,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE3DCCB), borderRadius: BorderRadius.circular(4)),
                ),
              ),
            const Spacer(),
            Row(
              children: [
                Text('500,000', style: tx(20, w: bold, c: K.muted)),
                const Spacer(),
                const Icon(LucideIcons.zoomIn, color: K.faint),
              ],
            ),
          ],
        ),
      ),
      gap(14),
      Center(child: Text('سجلتها بالغلط؟ اعكس الدفعة', style: tx(14, w: bold, c: K.coral))),
    ],
  );
}

Widget vAddSource() => Phone(
  nav: Sec.money,
  sheet: sheet(
    title: 'مصدر فلوس',
    sub: 'من وين بتجيب فلوس عرسك',
    children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        chip('مدخراتي', icon: LucideIcons.piggyBank),
        chip('دعم من الأهل', icon: LucideIcons.heartHandshake),
        chip('سلفة', icon: LucideIcons.calendarClock, on: true),
        chip('هدية', icon: LucideIcons.gift),
      ]),
      gap(14),
      field('من مين؟', 'خالي أحمد', icon: LucideIcons.user),
      gap(10),
      amountField('كم؟', '600,000', 'ستمية ألف ريال', focused: false),
      _label('وصلت ولا موعود؟'),
      Row(children: [
        Expanded(child: chip('وصلت', on: true)),
        const SizedBox(width: 8),
        Expanded(child: chip('موعود')),
      ]),
      _label('كيف بترجعها؟'),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: card(),
        child: Row(
          children: [
            Text('4 أقساط', style: tx(16, w: bold)),
            const SizedBox(width: 6),
            Text('· 150 ألف كل شهر', style: tx(14, c: K.muted)),
            const Spacer(),
            Text('تبدأ فبراير', style: tx(14, w: bold, c: K.teal)),
          ],
        ),
      ),
      gap(16),
      btn('حفظ', wide: true, v: 16, fs: 17),
    ],
  ),
  children: [tabHeader('المال', 'ماشية، بس ناقصك 2.5 مليون')],
);

Widget vLoan() {
  Widget inst(String n, String when, int state) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state == 2 ? K.green : (state == 1 ? K.saffronSoft : K.bg),
            border: state == 1 ? Border.all(color: K.saffron, width: 2) : null,
          ),
          child: state == 2
              ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
              : Text(n, style: tx(13, w: bold, c: K.muted)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(when,
              style: tx(15, w: bold, c: state == 2 ? K.muted : K.ink)),
        ),
        Text('150 ألف', style: tx(15, w: bold, c: state == 2 ? K.muted : K.ink)),
      ],
    ),
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: btn('سجّل القسط الثالث', wide: true, v: 16, fs: 17),
    ),
    children: [
      subHeader('سلفة خالي أحمد', sub: 'وصلت قبل العرس · خاصة بك'),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(colors: [K.teal, K.tealDark]),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('باقي عليك', style: tx(14, c: Colors.white70)),
            Text('300,000 ر.ي', style: tx(30, w: bold, c: Colors.white)),
            gap(12),
            segments(4, 2, on: Colors.white, now: K.saffron, off: Colors.white24),
            gap(10),
            Text('تخلص منها في مارس إن شاء الله', style: tx(14, w: bold, c: Colors.white)),
          ],
        ),
      ),
      sectionTitle('الأقساط'),
      Box(
        pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            inst('1', 'فبراير · دفعته', 2),
            inst('2', 'أول مارس · دفعته', 2),
            inst('3', 'منتصف مارس · بعد 9 أيام', 1),
            inst('4', 'آخر مارس', 0),
          ],
        ),
      ),
      gap(12),
      Box(
        child: Row(
          children: [
            const Icon(LucideIcons.bellRing, color: K.teal, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('ذكّرني قبل كل قسط بثلاثة أيام', style: tx(15, w: bold))),
            _toggle(true),
          ],
        ),
      ),
    ],
  );
}

Widget vShareSummary() => Phone(
  bg: const Color(0xFFE9E1D6),
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
    child: btn('افتح واتساب واختر المحادثة', wide: true, v: 16, fs: 17, bg: K.green,
        icon: LucideIcons.send),
  ),
  children: [
    subHeader('شارك ملخص المال', sub: 'تشوف الرسالة كاملة قبل ما ترسلها'),
    Box(
      child: Row(
        children: [
          const Icon(LucideIcons.eyeOff, color: K.teal, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('أخفِ المبالغ (نسب بس)', style: tx(15, w: bold))),
          _toggle(false),
        ],
      ),
    ),
    gap(16),
    _bubble(
      'ملخص عرس محمد وسلمى\n'
      'العرس بيكلف 10 مليون، ودفعنا 4.6.\n'
      'باقي 5.4، ومعنا 2.9.\n\n'
      'أكبر البنود:\n'
      '• المهر 3 مليون (سلّمنا 2)\n'
      '• القاعة 2 مليون\n'
      '• الضيافة 1.6 مليون\n\n'
      'أقرب دفعة: القاعة 500 ألف بعد 5 أيام.',
      me: true,
      time: 'من اعّرست',
      bg: const Color(0xFFD9FDD3),
    ),
    gap(8),
    _info('ما نرسل مصادر فلوسك ولا السلف أبدًا.', i: LucideIcons.lock),
  ],
);

// ============================================================ المهام

Widget vStarterTasks() {
  Widget t(String s, bool on, {String? when}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    child: Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: on ? K.saffronInk : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: on ? K.saffronInk : K.line, width: 2),
          ),
          child: on ? const Icon(LucideIcons.check, size: 14, color: Colors.white) : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(s, style: tx(15, w: bold, c: on ? K.ink : K.muted))),
        if (when != null) Text(when, style: tx(12.5, c: K.muted)),
      ],
    ),
  );
  Widget g(String title, String sub, List<Widget> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 8),
        child: Row(
          children: [
            Text(title, style: tx(16, w: bold)),
            const SizedBox(width: 8),
            Text(sub, style: tx(13, c: K.muted)),
          ],
        ),
      ),
      whiteList(rows, dividers: false),
    ],
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: btn('أضف 24 مهمة لخطتي', wide: true, v: 16, fs: 17, bg: K.saffronInk),
    ),
    children: [
      subHeader('مهام جاهزة لعرسك', sub: 'مرتبة على موعدك · شيل اللي ما يخصك'),
      g('الحين', 'قبل العرس بثلاثة أشهر', [
        t('احجز القاعة', true, when: 'هذا الأسبوع'),
        t('حدد موعد عقد القران', true, when: 'قبل 30 أكتوبر'),
        t('جهّز أوراق العقد', true, when: 'قبل العقد'),
        t('اختر المصور', true, when: 'نوفمبر'),
      ]),
      g('قبل بشهرين', 'ديسمبر', [
        t('احجز الفنان أو الفرقة', true),
        t('رتب القات مع المقوّت', true),
        t('حجز سيارات الزفة', false),
      ]),
      g('قبل بشهر', 'يناير', [
        t('أرسل الدعوات', true),
        t('رتّب الغداء', true),
        t('بدلة العريس', true),
        t('ركّب زينة البيت', true, when: 'قبل السمرة'),
      ]),
    ],
  );
}

Widget vTaskDetail() {
  Widget step(String s, bool done) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(done ? LucideIcons.checkCircle2 : LucideIcons.circle,
            size: 20, color: done ? K.green : K.faint),
        const SizedBox(width: 10),
        Text(s, style: tx(15, c: done ? K.muted : K.ink)),
      ],
    ),
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: Row(
        children: [
          Expanded(child: btn('خلصت', bg: K.green, v: 16, fs: 17, icon: LucideIcons.check)),
          const SizedBox(width: 10),
          btn('أجّلها', bg: K.saffronSoft, fg: K.saffronInk, v: 16, fs: 16),
        ],
      ),
    ),
    children: [
      subHeader('حدد موعد عقد القران',
          trailing: const Icon(LucideIcons.moreHorizontal, color: K.muted)),
      Row(
        children: [
          tag('متأخرة 7 أيام', K.coral, K.coralSoft),
          const SizedBox(width: 8),
          tag('لك', K.saffronInk, K.saffronSoft),
        ],
      ),
      gap(14),
      Box(
        child: Column(
          children: [
            for (final r in const [
              (LucideIcons.calendarDays, 'الموعد', 'كان 12 أكتوبر'),
              (LucideIcons.user, 'مين', 'أنت'),
              (LucideIcons.heartHandshake, 'مرتبطة بـ', 'المهر · الباقي 15 نوفمبر'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Icon(r.$1, size: 18, color: K.saffronInk),
                    const SizedBox(width: 10),
                    SizedBox(width: 70, child: Text(r.$2, style: tx(14, c: K.muted))),
                    Expanded(child: Text(r.$3, style: tx(15, w: bold))),
                  ],
                ),
              ),
          ],
        ),
      ),
      sectionTitle('خطوات صغيرة', action: 'أضف', ac: K.saffronInk),
      Box(
        pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            step('اتفق مع الوالد على اليوم', true),
            step('كلّم الأمين الشرعي', false),
            step('بلّغ أهل العروسة', false),
          ],
        ),
      ),
      sectionTitle('الأمين الشرعي'),
      _officiant(),
      gap(10),
      Box(
        pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            iconTile(LucideIcons.fileText, K.saffronInk, K.saffronSoft, s: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('جهّز أوراق العقد', style: tx(15, w: bold)),
                  Text('مهمة مرتبطة · 1 من 4 جاهزة', style: tx(13, c: K.muted)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronLeft, size: 18, color: K.faint),
          ],
        ),
      ),
    ],
  );
}

// Who writes and registers the contract. Optional: name and number only.
Widget _officiant() => Box(
  pad: const EdgeInsets.all(14),
  child: Column(
    children: [
      Row(
        children: [
          avatar('ع', K.saffronInk, s: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الشيخ عبدالله المطري', style: tx(16, w: bold)),
                Text('${ltr('771 220 914')} · من الوالد', style: tx(13.5, c: K.muted)),
              ],
            ),
          ),
          const Icon(LucideIcons.pencil, size: 17, color: K.faint),
        ],
      ),
      gap(12),
      Row(
        children: [
          Expanded(child: btn('اتصل', bg: K.bg, fg: K.ink, icon: LucideIcons.phone, v: 11, fs: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: btn('واتساب', bg: K.greenSoft, fg: K.green, icon: LucideIcons.messageCircle, v: 11, fs: 14),
          ),
        ],
      ),
    ],
  ),
);

Widget vContractPapers() {
  Widget paper(String s, String sub, {bool done = false, Widget? end}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: done ? K.saffronInk : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: done ? K.saffronInk : K.line, width: 2),
          ),
          child: done ? const Icon(LucideIcons.check, size: 14, color: Colors.white) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s, style: tx(15, w: bold, c: done ? K.muted : K.ink)),
              Text(sub, style: tx(13, c: K.muted)),
            ],
          ),
        ),
        ?end,
      ],
    ),
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: btn('كل الأوراق جاهزة', wide: true, v: 16, fs: 17, bg: K.saffronInk, icon: LucideIcons.check),
    ),
    children: [
      subHeader('جهّز أوراق العقد', sub: 'قبل عقد القران · مرتبطة بموعده'),
      Box(
        c: K.saffronSoft,
        pad: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1 من 4 جاهزة', style: tx(22, w: bold, c: K.saffronInk)),
                  Text('خلّها في ظرف واحد مع صالح', style: tx(13.5, c: K.saffronInk)),
                ],
              ),
            ),
            iconTile(LucideIcons.fileText, Colors.white, K.saffronInk, s: 48),
          ],
        ),
      ),
      sectionTitle('عليك'),
      Box(
        pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            paper('بطاقتك الشخصية', 'الأصل وصورة', done: true),
            paper('شاهدين ومعهم بطاقاتهم', 'صالح أخوي · ناقص واحد',
                end: chip('اختر', bg: K.saffronSoft, fg: K.saffronInk)),
            paper('المهر كما اتفقتوا', '3,000,000 · ينكتب في العقد'),
            paper('اللي بتسلّمه يوم العقد', '2,000,000 · من خطتك المالية'),
          ],
        ),
      ),
      sectionTitle('عند أهل العروسة'),
      Box(
        pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(LucideIcons.users, size: 20, color: K.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text('بطاقة الولي وأوراق العروسة',
                  style: tx(14.5, c: K.muted)),
            ),
            tag('عندهم', K.muted, K.bg),
          ],
        ),
      ),
      gap(12),
      _info('الأوراق تختلف من منطقة لمنطقة. اسأل الأمين الشرعي وأضف اللي يطلبه.',
          c: K.saffronInk, bg: K.saffronSoft, i: LucideIcons.helpCircle),
      gap(8),
      Center(child: softAction('اسأل الشيخ عبدالله على واتساب', fg: K.green, bg: K.greenSoft)),
    ],
  );
}

// ============================================================ الضيوف

Widget vAddGuest() => Phone(
  nav: Sec.guests,
  sheet: sheet(
    title: 'ضيف جديد',
    children: [
      field('الاسم', 'خالد الحمدي', focused: true),
      gap(10),
      field('رقم الجوال (اختياري)', ltr('771 554 220'), icon: LucideIcons.phone),
      _label('العائلة'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        chip('آل الحمدي', on: true, onBg: K.lilac),
        chip('آل السقاف'),
        chip('الأصحاب'),
        chip('العمل'),
        chip('جديدة', icon: LucideIcons.plus),
      ]),
      _label('كم معه؟'),
      Wrap(spacing: 8, children: [
        chip('لحاله'),
        chip('\u202A+1\u202C', on: true, onBg: K.lilac),
        chip('\u202A+2\u202C'),
        chip('\u202A+3\u202C'),
      ]),
      gap(16),
      Row(
        children: [
          Expanded(child: btn('حفظ', bg: K.lilac, v: 16, fs: 17)),
          const SizedBox(width: 10),
          btn('حفظ وأضف التالي', bg: K.lilacSoft, fg: K.lilac, v: 16, fs: 15),
        ],
      ),
    ],
  ),
  children: [tabHeader('الضيوف', '124 مدعو · 86 أكدوا · 20 ما ردّوا')],
);

Widget vGuestDetail() {
  Widget step(String s, String when, bool done) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(done ? LucideIcons.checkCircle2 : LucideIcons.circle,
            size: 19, color: done ? K.lilac : K.faint),
        const SizedBox(width: 10),
        Expanded(child: Text(s, style: tx(15, w: bold, c: done ? K.ink : K.faint))),
        Text(when, style: tx(12.5, c: K.muted)),
      ],
    ),
  );
  return Phone(
    children: [
      subHeader('', trailing: const Icon(LucideIcons.moreHorizontal, color: K.muted)),
      Center(child: avatar('ع', K.lilac, s: 76)),
      gap(10),
      Center(child: Text('عبدالله الحمدي', style: tx(24, w: bold))),
      Center(child: Text('آل الحمدي · \u202A+1\u202C', style: tx(15, c: K.muted))),
      gap(10),
      Center(child: tag('أكّد حضوره', K.lilac, K.lilacSoft)),
      gap(16),
      Row(
        children: [
          Expanded(child: btn('اتصل', bg: Colors.white, fg: K.ink, icon: LucideIcons.phone)),
          const SizedBox(width: 8),
          Expanded(
            child: btn('واتساب', bg: K.greenSoft, fg: K.green, icon: LucideIcons.messageCircle),
          ),
        ],
      ),
      sectionTitle('الدعوة'),
      Box(
        pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            step('انرسلت الدعوة', '2 نوفمبر', true),
            step('فتح الرابط', '2 نوفمبر', true),
            step('أكّد الحضور مع واحد', '3 نوفمبر', true),
          ],
        ),
      ),
      sectionTitle('الرفد'),
      Box(
        c: K.saffronSoft,
        child: Row(
          children: [
            const Icon(LucideIcons.gem, color: K.saffronInk),
            const SizedBox(width: 10),
            Expanded(child: Text('رفدك 20,000 يوم العرس', style: tx(15, w: bold))),
            Text('ترده في عرسه', style: tx(13, c: K.saffronInk)),
          ],
        ),
      ),
    ],
  );
}

Widget vReminderPreview() => Phone(
  bg: const Color(0xFFE9E1D6),
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
    child: btn('أرسل لـ 20 ضيف', wide: true, v: 16, fs: 17, bg: K.green, icon: LucideIcons.send),
  ),
  children: [
    subHeader('تذكير اللي ما ردّوا', sub: 'كل واحد يوصله باسمه ورابطه'),
    SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final n in const ['ياسر', 'مراد', 'فهد', 'سامي', 'نبيل', '\u202A+15\u202C'])
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: chip(n, bg: Colors.white),
            ),
        ],
      ),
    ),
    gap(16),
    _bubble(
      'أهلًا ياسر\n'
      'نذكرك بزفاف محمد الحمدي يوم الخميس 21 يناير، بعد العصر في قاعة سبأ.\n'
      'رد علينا من هنا بضغطة:\n'
      'aarast.app/rsvp/…',
      me: true,
      time: 'باسم والد العريس',
      bg: const Color(0xFFD9FDD3),
    ),
    gap(8),
    Box(
      child: Row(
        children: [
          const Icon(LucideIcons.pencil, color: K.lilac, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text('عدّل الرسالة', style: tx(15, w: bold, c: K.lilac))),
          Text('الوالد يرسلها', style: tx(13, c: K.muted)),
        ],
      ),
    ),
  ],
);

Widget vRafdBook() {
  Widget e(String n, String a, {String? note}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    child: Row(
      children: [
        avatar(n.characters.first, K.saffronInk, s: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n, style: tx(15, w: bold)),
              if (note != null) Text(note, style: tx(12.5, w: bold, c: K.lilac)),
            ],
          ),
        ),
        Text(a, style: tx(15, w: bold)),
      ],
    ),
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: btn('اشكرهم كلهم على واتساب', wide: true, v: 16, fs: 17, bg: K.saffronInk,
          icon: LucideIcons.heartHandshake),
    ),
    children: [
      subHeader('دفتر الرفد', sub: 'كتبه صالح يوم العرس'),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: K.saffron, borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('وصلك', style: tx(14, c: K.ink.withValues(alpha: 0.7))),
                  Text('1,800,000 ر.ي', style: tx(28, w: bold)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('112 شخص', style: tx(16, w: bold)),
                Text('شكرت 40', style: tx(13, c: K.ink.withValues(alpha: 0.7))),
              ],
            ),
          ],
        ),
      ),
      gap(12),
      field('ابحث', 'اسم أو مبلغ', icon: LucideIcons.search),
      gap(12),
      whiteList([
        e('عبدالله الحمدي', '20,000', note: 'عرسه بعد شهرين · ترده'),
        e('سالم الأهدل', '50,000', note: 'عرس سالم الشهر الجاي'),
        e('عمي محمد', '100,000'),
        e('زملاء العمل', '150,000'),
        e('ياسر الأهدل', '10,000'),
      ], dividers: false),
    ],
  );
}

Widget vThanks() => Phone(
  sheet: sheet(
    title: 'رسالة الشكر',
    sub: 'تنرسل لكل واحد باسمه',
    children: [
      _bubble(
        'الله يجزاك خير يا عبدالله على حضورك ورفدك\n'
        'فرحتنا كملت بوجودك، وعقبال أفراحكم.\n'
        'محمد الحمدي',
        me: true,
        bg: const Color(0xFFD9FDD3),
      ),
      gap(8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        chip('اذكر المبلغ', icon: LucideIcons.eyeOff),
        chip('بدون المبلغ', on: true, onBg: K.saffronInk),
      ]),
      gap(12),
      Row(
        children: [
          const Icon(LucideIcons.users, size: 18, color: K.muted),
          const SizedBox(width: 8),
          Text('72 باقين ما شكرتهم', style: tx(15, w: bold)),
        ],
      ),
      gap(16),
      btn('أرسل لـ 72', wide: true, v: 16, fs: 17, bg: K.saffronInk, icon: LucideIcons.send),
    ],
  ),
  children: [subHeader('دفتر الرفد')],
);

// ============================================================ المزودين

Widget vQuoteRequest() {
  Widget auto(IconData i, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(i, size: 18, color: K.sky),
        const SizedBox(width: 10),
        SizedBox(width: 74, child: Text(k, style: tx(14, c: K.muted))),
        Expanded(child: Text(v, style: tx(15, w: bold))),
        const Icon(LucideIcons.pencil, size: 15, color: K.faint),
      ],
    ),
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: btn('أرسل الطلب', wide: true, v: 16, fs: 17, bg: K.sky, icon: LucideIcons.send),
    ),
    children: [
      subHeader('اطلب عرض سعر', sub: 'إلى فرقة الأفراح'),
      Text('وش تحتاج؟', style: tx(14, w: bold, c: K.muted)),
      gap(8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        chip('فرقة كاملة', on: true, onBg: K.sky),
        chip('فنان بس'),
        chip('زفة'),
      ]),
      _label('من خطتك'),
      Box(
        pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            auto(LucideIcons.calendarDays, 'اليوم', 'الخميس 21 يناير'),
            auto(LucideIcons.clock, 'الوقت', 'بعد العصر لين العشاء'),
            auto(LucideIcons.mapPin, 'المكان', 'قاعة سبأ · حدة'),
            auto(LucideIcons.users, 'الضيوف', '124 تقريبًا'),
            auto(LucideIcons.wallet, 'بندك', '500 ألف'),
          ],
        ),
      ),
      gap(12),
      field('كلمة لهم (اختياري)', 'نبغى زفة من باب القاعة لين المنصة'),
      gap(10),
      _info('بندك ما يوصلهم إلا إذا فعّلته.', c: K.sky, bg: K.skySoft, i: LucideIcons.lock),
    ],
  );
}

Widget vConversations() {
  Widget c(String n, String last, String when, int unread, IconData i) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        iconTile(i, K.sky, K.skySoft, s: 46, r: 15),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n, style: tx(15.5, w: bold)),
              Text(last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tx(13, w: unread > 0 ? bold : FontWeight.w400,
                      c: unread > 0 ? K.ink : K.muted)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(when, style: tx(12, c: K.muted)),
            gap(4),
            if (unread > 0)
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: K.sky, shape: BoxShape.circle),
                child: Text('$unread', style: tx(12, w: bold, c: Colors.white)),
              ),
          ],
        ),
      ],
    ),
  );
  return Phone(
    nav: Sec.providers,
    children: [
      tabHeader('المزودين', 'محجوز 3 من 6', actions: [LucideIcons.search]),
      topTabs(const ['طلباتي', 'استكشف', 'المحادثات', 'المفضلة'], 2, c: K.sky),
      gap(14),
      whiteList([
        c('استوديو ضوء صنعاء', 'وصلك عرض: صور وفيديو 550 ألف', '10:40', 2, LucideIcons.camera),
        c('عدسة سبأ', 'عرضنا 480 ألف ويشمل فيلم قصير', 'أمس', 1, LucideIcons.camera),
        c('قاعة سبأ', 'نأكد عدد المقاعد قبل شهر', 'الأحد', 0, LucideIcons.building2),
        c('ضيافة الأصالة', 'تمام، العشاء 124 شخص', '12 أكتوبر', 0, LucideIcons.utensils),
      ]),
    ],
  );
}

Widget vFavorites() {
  Widget f(String n, String cat, String price, List<Color> cs, IconData i, bool on) => Container(
    decoration: card(border: on ? K.sky : null),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 92,
          decoration: BoxDecoration(gradient: LinearGradient(colors: cs)),
          child: Stack(
            children: [
              Center(child: Icon(i, color: Colors.white54, size: 32)),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: on ? K.sky : Colors.white,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: on ? const Icon(LucideIcons.check, size: 15, color: Colors.white) : null,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(14.5, w: bold)),
              Text(cat, style: tx(12, c: K.muted)),
              Text(price, style: tx(13, w: bold, c: K.sky)),
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    nav: Sec.providers,
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: btn('قارن الاثنين', wide: true, v: 14, bg: K.sky, icon: LucideIcons.columns),
    ),
    children: [
      tabHeader('المزودين', 'محجوز 3 من 6', actions: [LucideIcons.search]),
      topTabs(const ['طلباتي', 'استكشف', 'المحادثات', 'المفضلة'], 3, c: K.sky),
      gap(14),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.98,
        children: [
          f('فرقة الأفراح', 'فرق', '350 - 450 ألف', const [K.sky, K.lilac], LucideIcons.music, true),
          f('الفنان أيمن الآنسي', 'فنانين', '500 - 700 ألف', const [K.teal, K.sky],
              LucideIcons.mic, true),
          f('ضوء صنعاء', 'تصوير', '350 - 700 ألف', const [K.sky, K.ink], LucideIcons.camera,
              false),
          f('قات الروضة', 'قات', 'حسب الطلب', const [K.green, K.teal], LucideIcons.leaf, false),
        ],
      ),
    ],
  );
}

// ============================================================ المشاركين والحساب

Widget vAddParticipant() => Phone(
  sheet: sheet(
    title: 'أضف مشارك',
    children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: card(border: K.teal),
        child: Row(
          children: [
            avatar('س', const Color(0xFF8E5A9E), s: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('سلمى', style: tx(16, w: bold)),
                  Text(ltr('770 998 321'), style: tx(13, c: K.muted)),
                ],
              ),
            ),
            Text('من جهاتك', style: tx(13, w: bold, c: K.teal)),
          ],
        ),
      ),
      _label('وش تقدر تسوي؟'),
      for (final r in const [
        ('تشوف الموعد والبرنامج', true),
        ('تشوف المهام وتضيف', true),
        ('تشوف الضيوف', false),
        ('تشوف المال', false),
      ])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(r.$1, style: tx(15, w: bold))),
              _toggle(r.$2),
            ],
          ),
        ),
      gap(10),
      _info('تقدر تغيّرها أو تشيلها أي وقت.', i: LucideIcons.lock),
      gap(14),
      btn('أرسل الدعوة على واتساب', wide: true, v: 16, fs: 17, icon: LucideIcons.send),
    ],
  ),
  children: [subHeader('المشاركين')],
);

Widget vNotifSettings() {
  Widget r(String t, String s, bool on) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: tx(15, w: bold)),
              Text(s, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        _toggle(on),
      ],
    ),
  );
  return Phone(
    children: [
      subHeader('التنبيهات'),
      whiteList([
        r('الخطوة الجاية', 'كل صباح، إذا فيه شيء مهم', true),
        r('الدفعات والأقساط', 'قبل موعدها بثلاثة أيام', true),
        r('ردود الضيوف', 'مرة باليوم مجمعة', true),
        r('العروض والمحادثات', 'أول ما توصل', true),
        r('ملخص الجمعة', 'وش صار هذا الأسبوع', true),
        r('المشاركين', 'لما أحد يسوي شيء', false),
      ], dividers: false),
      sectionTitle('الهدوء'),
      Box(
        child: Row(
          children: [
            const Icon(LucideIcons.moon, color: K.teal, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('لا تزعجني من 11 الليل لـ 7 الصبح', style: tx(15, w: bold))),
            _toggle(true),
          ],
        ),
      ),
      gap(10),
      _info('على شاشة القفل ما تطلع أسماء ولا مبالغ.', i: LucideIcons.lock),
    ],
  );
}

Widget vLock() {
  Widget key(String k) => Container(
    width: 74,
    height: 74,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), shape: BoxShape.circle),
    child: Text(k, style: tx(28, w: bold, c: Colors.white)),
  );
  return Phone(
    statusLight: true,
    gradient: const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [K.teal, K.tealDark],
    ),
    children: [
      gap(50),
      Center(child: wordmark(s: 30, c: Colors.white)),
      gap(24),
      Center(child: Text('أدخل رمزك', style: tx(20, w: bold, c: Colors.white))),
      gap(18),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: i < 2 ? Colors.white : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
        ],
      ),
      gap(40),
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            for (final row in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ]) ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (final k in row) key(k)]),
              gap(16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const SizedBox(width: 74, child: Icon(LucideIcons.fingerprint, color: Colors.white, size: 30)),
                key('0'),
                const SizedBox(width: 74, child: Icon(LucideIcons.delete, color: Colors.white, size: 26)),
              ],
            ),
          ],
        ),
      ),
      gap(20),
      Center(child: Text('نسيت الرمز؟', style: tx(15, w: bold, c: Colors.white70))),
    ],
  );
}

Widget vChangePhone() => Phone(
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
    child: btn('أرسل الرمز للرقم الجديد', wide: true, v: 16, fs: 17),
  ),
  children: [
    subHeader('تغيير رقم الجوال'),
    field('رقمك الحالي', ltr('777 123 456'), icon: LucideIcons.smartphone),
    gap(10),
    Center(child: Icon(LucideIcons.arrowDown, color: K.faint)),
    gap(10),
    Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: K.teal, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الرقم الجديد', style: tx(12.5, c: K.muted)),
          Text(ltr('733 880 145'), style: tx(24, w: bold)),
        ],
      ),
    ),
    gap(16),
    _info('خطتك ومشاركينك يبقون مثل ما هم. بنخرجك من الأجهزة الثانية للأمان.',
        i: LucideIcons.shieldCheck),
  ],
);

Widget vSupport() => Phone(
  children: [
    subHeader('المساعدة'),
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: K.greenSoft, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          iconTile(LucideIcons.messageCircle, Colors.white, K.green, s: 50, r: 16),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('كلّمنا على واتساب', style: tx(17, w: bold)),
                Text(ltr('777 000 111'), style: tx(15, w: bold, c: K.green)),
                Text('نرد عادة خلال ساعة', style: tx(12.5, c: K.muted)),
              ],
            ),
          ),
        ],
      ),
    ),
    sectionTitle('أسئلة كثير يسألونها'),
    whiteList([
      for (final q in const [
        'كيف أضيف سلمى أو أخوي مشارك؟',
        'وش يصير لو أجّلت العرس؟',
        'هل اعّرست يحوّل فلوس؟',
        'مين يشوف أرقامي؟',
        'كيف أطلب عرض سعر من مزود؟',
      ])
        listRow(
          icon: LucideIcons.helpCircle,
          fg: K.teal,
          soft: K.tealSoft,
          title: q,
          sub: '',
          trailing: const Icon(LucideIcons.chevronLeft, color: K.faint, size: 18),
          iconSize: 36,
        ),
    ], dividers: false),
    gap(12),
    Row(
      children: [
        Expanded(child: chip('الخصوصية', icon: LucideIcons.lock)),
        const SizedBox(width: 8),
        Expanded(child: chip('الشروط', icon: LucideIcons.fileText)),
      ],
    ),
  ],
);

Widget vLogout() => Phone(
  sheet: sheet(
    title: 'الخروج',
    children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: card(),
        child: Row(
          children: [
            const Icon(LucideIcons.logOut, color: K.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اخرج من هذا الجوال', style: tx(16, w: bold)),
                  Text('خطتك تبقى، وترجع لها برقمك', style: tx(13, c: K.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
      gap(10),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: K.coralSoft,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.trash2, color: K.coral),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('احذف حسابي نهائيًا', style: tx(16, w: bold, c: K.coral)),
                  Text('تنحذف خطتك وكل بياناتك، وما ترجع', style: tx(13, c: K.coral)),
                ],
              ),
            ),
          ],
        ),
      ),
      gap(14),
      btn('رجوع', wide: true, v: 15, bg: Colors.white, fg: K.ink),
    ],
  ),
  children: [subHeader('حسابي')],
);
