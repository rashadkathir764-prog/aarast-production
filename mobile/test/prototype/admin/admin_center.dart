// Admin prototype: what turns the back office into a control centre. One
// inbox for every queue, the market, one-number support, platform health,
// trust and safety, and the switches that change the app without a release.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import 'akit.dart';

Widget _bar(double v, Color c, {double h = 10}) => ClipRRect(
  borderRadius: BorderRadius.circular(h),
  child: SizedBox(
    height: h,
    child: Row(children: [
      Expanded(flex: (v * 1000).round(), child: Container(color: c)),
      Expanded(flex: ((1 - v) * 1000).round().clamp(1, 1000), child: Container(color: K.line)),
    ]),
  ),
);

Widget _sla(String s, {bool late = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
  Icon(LucideIcons.clock, size: 14, color: late ? K.coral : K.muted),
  const SizedBox(width: 4),
  t(s, fs: 13, b: late, c: late ? K.coral : K.muted),
]);

// ============================================================ اليوم

/// One inbox for every queue, each item with its promise and its owner.
Widget n01Inbox() => desk(
  'inbox',
  crumb: 'اليوم',
  title: 'الصندوق',
  sub: 'كل شغل اللوحة في مكان واحد · 23 مفتوح · 4 تعدّت الوقت',
  actions: [aBtn('لي 9'), aBtn('بدون مسؤول 6', bg: A.soft, fg: A.c), aBtn('الكل', bg: A.soft, fg: A.c)],
  body: [
    Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: table(
              const [('البند', 5), ('النوع', 2), ('الوقت', 2), ('مسؤول', 2)],
              [
                [t2('صورة نساء بوجه واضح في معرض «عدسة الياسمين»', 'فحص آلي · قبل 40 دقيقة'), tag('صور', K.coral, K.coralSoft), _sla('باقي ساعة', late: true), t('سارة')],
                [t2('ضيافة الأصالة مع محمد الحمدي: الدفعة ما وصلت', 'العريس دفع 200,000 · المزود ينكر'), tag('خلاف دفعة', K.coral, K.coralSoft), _sla('تعدّى بيوم', late: true), t('—', c: K.muted)],
                [t2('استوديو ضوء صنعاء', 'أُعيد إرساله بعد التعديل'), tag('انضمام', K.sky, K.skySoft), _sla('باقي يوم'), t('نادية')],
                [t2('منقشة أم سارة', 'البطاقة + مزكّي'), tag('توثيق', K.green, K.greenSoft), _sla('باقي يومين'), t('—', c: K.muted)],
                [t2('احتيال: طلب تحويل لرقم ثاني', 'محمد بلّغ عن «مصور مجهول»'), tag('بلاغ', K.coral, K.coralSoft), _sla('باقي 3 ساعات'), t('سارة')],
                [t2('770 998 321 يطلب نسخة من بياناته', 'طلب بيانات'), tag('بيانات', A.c, A.soft), _sla('باقي 5 أيام'), t('عمر')],
              ],
              hi: 1,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: Column(children: [
              panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('الوعد لكل نوع', style: tx(15, w: bold)),
                gap(6),
                for (final r in const [('صور النساء', 'ساعتين'), ('بلاغ احتيال', '4 ساعات'), ('خلاف دفعة', 'يوم'), ('انضمام', 'يومين'), ('توثيق', '3 أيام'), ('طلب بيانات', '7 أيام')])
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: t(r.$1, fs: 13.5)), t(r.$2, b: true, fs: 13.5)])),
              ])),
              gap(12),
              panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ضغط الفريق', style: tx(15, w: bold)),
                gap(8),
                for (final r in const [('سارة · إشراف', 7, 0.9), ('نادية · تشغيل', 4, 0.5), ('عمر · دعم', 2, 0.25)])
                  Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: t(r.$1, fs: 13.5)), t('${r.$2}', b: true, fs: 13.5)]),
                    gap(4),
                    _bar(r.$3, r.$3 > 0.8 ? K.coral : A.c, h: 7),
                  ])),
              ])),
            ]),
          ),
        ],
      ),
    ),
  ],
);

// ============================================================ السوق

/// Supply and demand per city and section, from real requests.
Widget n02Market() {
  Widget row(String city, String cat, int req, int prov, double unanswered, String reply, String note) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(children: [
      Expanded(flex: 3, child: t2(city, cat)),
      Expanded(flex: 2, child: t('$req', b: true)),
      Expanded(flex: 2, child: t('$prov')),
      Expanded(flex: 4, child: Row(children: [Expanded(child: _bar(unanswered, unanswered > 0.25 ? K.coral : K.green, h: 8)), const SizedBox(width: 8), t('${(unanswered * 100).round()}٪', fs: 13, b: true, c: unanswered > 0.25 ? K.coral : K.ink)])),
      Expanded(flex: 2, child: t(reply)),
      Expanded(flex: 4, child: t(note, fs: 13, c: note.startsWith('نقص') ? K.coral : K.muted, b: note.startsWith('نقص'))),
    ]),
  );
  return desk(
    'market',
    crumb: 'السوق',
    title: 'نظرة السوق',
    sub: 'آخر 30 يوم · من الطلبات الحقيقية',
    actions: [aBtn('كل المدن', bg: A.soft, fg: A.c), aBtn('آخر 30 يوم', bg: A.soft, fg: A.c)],
    body: [
      Row(children: [stat('3,910', 'طلب عرض'), const SizedBox(width: 12), stat('19٪', 'ما انرد عليها', c: K.coral), const SizedBox(width: 12), stat('5 ساعات', 'متوسط الرد'), const SizedBox(width: 12), stat('28٪', 'صار حجز')]),
      gap(12),
      panel(
        pad: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(children: [
              for (final h in const [('المدينة والقسم', 3), ('طلبات', 2), ('مزودين', 2), ('ما انرد عليها', 4), ('الرد', 2), ('ايش يعني', 4)])
                Expanded(flex: h.$2, child: t(h.$1, fs: 12.5, b: true, c: K.muted)),
            ]),
          ),
          const Divider(height: 1, color: K.line),
          row('عدن', 'التصوير', 410, 11, 0.38, '11 ساعة', 'نقص مزودين: 37 طلب لكل مزود'),
          row('صنعاء', 'التصوير', 980, 24, 0.12, '3 ساعات', 'متوازن'),
          row('صنعاء', 'الصالات', 640, 19, 0.08, '2 ساعات', 'متوازن'),
          row('تعز', 'الكوش والزينة', 120, 2, 0.46, 'يوم', 'نقص مزودين: أضف ملفات من الدليل'),
          row('صنعاء', 'الفنانين', 300, 14, 0.15, '6 ساعات', 'متوازن'),
        ]),
      ),
    ],
  );
}

/// Where couples drop between opening the app and booking.
Widget n03Funnel() {
  Widget step(String l, String n, double v, String? drop) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      SizedBox(width: 210, child: t(l, b: true)),
      Expanded(child: _bar(v, A.c, h: 26)),
      const SizedBox(width: 12),
      SizedBox(width: 80, child: t(n, b: true)),
      SizedBox(width: 200, child: drop == null ? const SizedBox() : t(drop, fs: 13, c: K.coral, b: true)),
    ]),
  );
  return desk(
    'funnel',
    crumb: 'السوق',
    title: 'مسار العريس',
    sub: 'سبتمبر · العريس والعروسة',
    actions: [aBtn('العريس والعروسة', bg: A.soft, fg: A.c), aBtn('كل المدن', bg: A.soft, fg: A.c)],
    body: [
      panel(child: Column(children: [
        step('فتح التطبيق أول مرة', '5,200', 1, null),
        step('سوّى خطة على الجوال', '3,640', 0.70, null),
        step('حفظها بحساب', '1,980', 0.38, 'يطيح 46٪ هنا: رمز واتساب'),
        step('سجّل أول تكلفة أو دفعة', '1,410', 0.27, null),
        step('أضاف مشارك', '820', 0.16, null),
        step('طلب عرض من مزود', '1,130', 0.22, null),
        step('حجز مزود', '318', 0.06, null),
      ])),
      gap(12),
      panel(c: K.coralSoft, child: Row(children: [
        const Icon(LucideIcons.alertTriangle, color: K.coral),
        const SizedBox(width: 10),
        Expanded(child: t('أكبر طيحة عند حفظ الخطة: 22٪ من رموز واتساب ما وصلت في عدن هذا الشهر. شوف «صحة المنصة».', b: true, c: K.coral)),
      ])),
    ],
  );
}

/// Weddings coming up per week and city: the season before it arrives.
Widget n04Calendar() {
  const cities = ['صنعاء', 'عدن', 'تعز', 'إب', 'الحديدة'];
  // Ramadan 1448 starts about 8 February 2027: the peak is the week before.
  const weeks = ['28 ديسمبر', '4 يناير', '11 يناير', '18 يناير', '25 يناير', '1 فبراير'];
  const v = [
    [22, 30, 39, 42, 58, 61],
    [9, 14, 20, 18, 22, 31],
    [5, 6, 10, 9, 12, 14],
    [3, 4, 6, 7, 8, 11],
    [2, 3, 4, 5, 6, 9],
  ];
  Color c(int n) => n >= 50 ? K.coral : n >= 30 ? K.saffron : n >= 12 ? K.saffronSoft : A.soft;
  return desk(
    'calendar',
    crumb: 'السوق',
    title: 'تقويم الأعراس',
    sub: 'أعراس الخطط حسب الأسبوع · لين قبل رمضان',
    body: [
      panel(child: Column(children: [
        Row(children: [const SizedBox(width: 110), for (final w in weeks) Expanded(child: Center(child: t(w, fs: 12.5, c: K.muted)))]),
        gap(8),
        for (var i = 0; i < cities.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(width: 110, child: t(cities[i], b: true)),
              for (final n in v[i])
                Expanded(
                  child: Container(
                    height: 46,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c(n), borderRadius: BorderRadius.circular(10)),
                    child: t('$n', b: true, c: n >= 30 ? Colors.white : K.ink),
                  ),
                ),
            ]),
          ),
      ])),
      gap(12),
      panel(child: Row(children: [
        const Icon(LucideIcons.lightbulb, color: K.saffronInk),
        const SizedBox(width: 10),
        Expanded(child: t('أسبوع 1 فبراير في صنعاء: 61 عرس و24 مصور. ذكّر المزودين يحدّثون تقاويمهم قبلها بأسبوعين.', b: true)),
        aBtn('ذكّرهم', icon: LucideIcons.send),
      ])),
    ],
  );
}

// ============================================================ الناس

/// One number, every context: the support desk.
Widget n05Lookup() => desk(
  'lookup',
  crumb: 'الناس',
  title: 'ابحث برقم',
  sub: '777 123 456',
  role: Role.support,
  who: 'عمر',
  body: [
    Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(children: [
              panel(child: Row(children: [
                avatar('م', K.teal, s: 46),
                const SizedBox(width: 12),
                Expanded(child: t2('محمد الحمدي', 'حساب من 2 أكتوبر · جهازين · آخر دخول الآن')),
                tag('نشط', K.green, K.greenSoft),
              ])),
              gap(10),
              table(
                const [('وين موجود', 4), ('دوره', 2), ('الحالة', 3)],
                [
                  [t2('عرس محمد', 'الخميس 21 يناير · صنعاء'), t('صاحب الخطة'), tag('نشطة', K.green, K.greenSoft)],
                  [t2('عرس صالح', 'مارس'), t('مساعد'), tag('نشطة', K.green, K.greenSoft)],
                  [t2('ملف مزود', '—'), t('—'), t('ما عنده', c: K.muted)],
                ],
              ),
              gap(10),
              panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('آخر رسائل واتساب له', style: tx(15, w: bold)),
                gap(6),
                for (final r in const [('رمز الدخول', '9:40', true), ('رمز الدخول', '9:38', false), ('دعوة من صالح', 'أمس', true)])
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
                    Icon(r.$3 ? LucideIcons.checkCheck : LucideIcons.xCircle, size: 17, color: r.$3 ? K.green : K.coral),
                    const SizedBox(width: 8),
                    Expanded(child: t(r.$1, fs: 13.5)),
                    t(r.$3 ? 'وصلت ${r.$2}' : 'ما وصلت ${r.$2}', fs: 13, c: r.$3 ? K.muted : K.coral),
                  ])),
              ])),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('اللي تقدر تسويه', style: tx(15, w: bold)),
              gap(8),
              for (final r in const [
                (LucideIcons.unlock, 'فك قفل الرموز', 'مقفل لين 9:55 بعد 5 محاولات'),
                (LucideIcons.send, 'أعد إرسال آخر رمز', 'بعد ما يفك القفل'),
                (LucideIcons.logOut, 'أطلعه من الأجهزة', 'لو جواله انسرق'),
                (LucideIcons.rotateCcw, 'رجّع حساب قيد الحذف', 'ما فيه طلب حذف'),
              ])
                Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [Icon(r.$1, color: A.c, size: 19), const SizedBox(width: 10), Expanded(child: t2(r.$2, r.$3))])),
              gap(8),
              panel(c: A.soft, child: t('دورك «دعم»: الإجراءات تطلب موافقة من التشغيل. وما تشوف مال الخطة ولا ضيوفها.', fs: 13)),
            ])),
          ),
        ],
      ),
    ),
  ],
);

Widget n06DataRequests() => desk(
  'datareq',
  crumb: 'الناس',
  title: 'طلبات البيانات',
  sub: 'نزّلوا بياناتي واحذفوا حسابي · نوعد خلال 7 أيام',
  body: [
    table(
      const [('الرقم', 2), ('الطلب', 2), ('من', 2), ('الحالة', 3), ('', 2)],
      [
        [t('770 998 321'), t('نسخة من بياناته'), t('قبل يومين'), tag('الملف جاهز', K.green, K.greenSoft), softAction('أرسل الرابط', fg: A.c, bg: A.soft)],
        [t('771 554 220'), t('حذف الحساب'), t('19 أكتوبر'), tag('مهلة: باقي 27 يوم', K.saffronInk, K.saffronSoft), softAction('رجّعه بطلبه', fg: A.c, bg: A.soft)],
        [t('733 445 566'), t('حذف حساب مزود'), t('أمس'), tag('موقوف: 3 حجوزات جاية', K.coral, K.coralSoft), softAction('كلّمه', fg: A.c, bg: A.soft)],
      ],
    ),
    gap(10),
    t('حذف حساب المزود ما يكمل وعنده حجوزات جاية، لين يسلّمها أو يلغيها والعرسان يتبلّغون.', c: K.muted, fs: 13),
  ],
);

// ============================================================ الرقابة

Widget n07Photos() {
  Widget ph(Color c, String who, String flag) => Expanded(
    child: panel(
      pad: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(height: 150, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12)), child: const Center(child: Icon(LucideIcons.eyeOff, color: Colors.white70, size: 32))),
        gap(8),
        t(who, b: true, fs: 13.5),
        t(flag, fs: 12.5, c: K.coral),
        gap(8),
        Row(children: [softAction('شِل', fg: K.coral, bg: K.coralSoft), const SizedBox(width: 6), softAction('سليمة', fg: K.green, bg: K.greenSoft)]),
      ]),
    ),
  );
  return desk(
    'photos',
    crumb: 'الرقابة',
    title: 'صور تحتاج مراجعة',
    sub: 'صور معارض المزودين اللي تخدم النساء · الوعد ساعتين',
    role: Role.moderator,
    who: 'سارة',
    body: [
      Row(children: [
        ph(const Color(0xFF8A7C8F), 'عدسة الياسمين', 'آلي: وجه واضح'),
        const SizedBox(width: 12),
        ph(const Color(0xFF7D8A80), 'كوافيرة أم ريان', 'آلي: وجه جزئي'),
        const SizedBox(width: 12),
        ph(const Color(0xFF9C8B74), 'استوديو ضوء صنعاء · فريق النساء', 'بلاغ من عروسة'),
        const SizedBox(width: 12),
        ph(const Color(0xFF6E7F8C), 'منقشة أم سارة', 'آلي: غير متأكد'),
      ]),
      gap(12),
      t('الصورة ما تظهر للعرسان لين تتراجع. والمزود يوصله ليش انشالت.', c: K.muted, fs: 13),
    ],
  );
}

Widget n08Fraud() => desk(
  'fraud',
  crumb: 'الرقابة',
  title: 'إشارات الاحتيال',
  sub: 'تطلع لحالها من البيانات · كل وحدة تحتاج نظرة إنسان',
  body: [
    table(
      const [('الإشارة', 5), ('على', 3), ('القوة', 2), ('', 2)],
      [
        [t2('طلب تحويل الدفعة لرقم غير اللي في الاتفاق', 'كلمات في المحادثة + رقم جديد'), t('مصور مجهول'), tag('عالية', K.coral, K.coralSoft), softAction('افتح', fg: A.c, bg: A.soft)],
        [t2('6 تقييمات 5 نجوم من أرقام عمرها أقل من أسبوع', 'نفس اليوم'), t('صالة الورد'), tag('عالية', K.coral, K.coralSoft), softAction('افتح', fg: A.c, bg: A.soft)],
        [t2('رقم واحد عليه 4 حسابات مزود', 'أسماء مختلفة'), t('773 900 001'), tag('متوسطة', K.saffronInk, K.saffronSoft), softAction('افتح', fg: A.c, bg: A.soft)],
        [t2('مزود يلغي 40٪ من حجوزاته المؤكدة', 'آخر 60 يوم'), t('فرقة النور'), tag('متوسطة', K.saffronInk, K.saffronSoft), softAction('افتح', fg: A.c, bg: A.soft)],
      ],
    ),
  ],
);

// ============================================================ النظام

/// Is it working? WhatsApp codes, push, the event queue, scheduled jobs.
Widget n09Health() {
  Widget card(String l, String v, String sub, {bool bad = false}) => Expanded(
    child: panel(
      border: bad ? K.coral : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [dot(bad ? K.coral : K.green, 10), const SizedBox(width: 8), t(l, b: true)]),
        gap(6),
        Text(v, style: tx(26, w: bold, c: bad ? K.coral : K.ink)),
        t(sub, fs: 12.5, c: K.muted),
      ]),
    ),
  );
  return desk(
    'health',
    crumb: 'النظام',
    title: 'صحة المنصة',
    sub: 'آخر ساعة · يتحدث كل دقيقة',
    body: [
      Row(children: [
        card('رموز واتساب', '78٪ وصلت', 'عدن 61٪ · صنعاء 94٪', bad: true),
        const SizedBox(width: 12),
        card('التنبيهات للجوالات', '97٪', '312 من 321'),
        const SizedBox(width: 12),
        card('طابور الأحداث', '14 عالق', 'أقدمها من 6 دقايق'),
        const SizedBox(width: 12),
        card('الأخطاء', '0.4٪', 'من 18,200 طلب'),
      ]),
      gap(12),
      Expanded(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 3,
            child: table(
              const [('المهمة المجدولة', 4), ('كل', 2), ('آخر تشغيل', 2), ('النتيجة', 2)],
              [
                [t('تذكيرات الخطط'), t('ساعة'), t('9:15'), tag('تمام', K.green, K.greenSoft)],
                [t('تذكيرات الحجوزات'), t('ساعة'), t('9:25'), tag('تمام', K.green, K.greenSoft)],
                [t('انتهاء الطلبات والحجز المبدئي'), t('ساعة'), t('9:30'), tag('تمام', K.green, K.greenSoft)],
                [t('تنظيف الرفع والجلسات'), t('يوم'), t('3:00'), tag('فشل مرة', K.coral, K.coralSoft)],
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: panel(c: K.coralSoft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('رموز واتساب في عدن نازلة', style: tx(16, w: bold, c: K.coral)),
              gap(6),
              t('من 9 الصبح. 39٪ ما وصلت. العرسان ما يقدرون يحفظون خطتهم.', fs: 14),
              gap(10),
              t('اقتراح: فعّل «الدخول بكلمة المرور أول» لعدن مؤقتًا.', b: true, fs: 14),
              gap(10),
              aBtn('افتح الميزات', icon: LucideIcons.toggleRight),
            ])),
          ),
        ]),
      ),
    ],
  );
}

/// Switches that change the app without a release, and messages to users.
Widget n10Flags() => desk(
  'flags',
  crumb: 'النظام',
  title: 'الميزات والإعلانات',
  sub: 'تتغير في التطبيق بدون إصدار جديد · كل تغيير ينسجل',
  role: Role.superAdmin,
  who: 'رشاد',
  body: [
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الميزات', style: tx(16, w: bold)),
          for (final r in const [
            ('المساعد الذكي', 'كل المدن', true),
            ('الدخول بكلمة المرور أول', 'عدن بس · مؤقت لين واتساب يرجع', true),
            ('مسح الإيصال', '10٪ من المستخدمين', false),
            ('الحجز المبدئي للمزودين', 'كل المدن', true),
            ('مدينة المكلا', 'مخفية لين يكتمل 10 مزودين', false),
          ])
            Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [
              Expanded(child: t2(r.$1, r.$2)),
              Container(
                width: 46, height: 28, padding: const EdgeInsets.all(3),
                alignment: r.$3 ? Alignment.centerLeft : Alignment.centerRight,
                decoration: BoxDecoration(color: r.$3 ? A.c : K.line, borderRadius: BorderRadius.circular(999)),
                child: Container(width: 22, height: 22, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              ),
            ])),
        ])),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('إعلان في التطبيق', style: tx(16, w: bold)),
          gap(10),
          panel(c: A.soft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            t('رمضان كريم', b: true),
            t('أغلب المزودين في إجازة لين العيد. خطتك محفوظة، والتذكيرات تكمل.', fs: 13.5),
          ])),
          gap(10),
          for (final r in const [('لمين', 'العرسان والمزودين'), ('وين', 'كل المدن'), ('من', '1 رمضان'), ('لين', '1 شوال')])
            Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [SizedBox(width: 60, child: t(r.$1, c: K.muted, fs: 13)), t(r.$2, b: true, fs: 13.5)])),
          gap(10),
          aBtn('جدوِله'),
          gap(8),
          t('إعلان واحد في وقت واحد، ويقدر المستخدم يقفله. ما فيه رسائل تسويق.', c: K.muted, fs: 12.5),
        ])),
      ),
    ]),
  ],
);
