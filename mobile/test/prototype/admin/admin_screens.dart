// Admin prototype: the back office. Every queue the provider and plan
// journeys create has a place here: joins, verification, reports, deposit
// disputes, directory listings, categories and their default model, support,
// the numbers that control the rules, and the log of every action.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import 'akit.dart';

Widget _q(String n, String l, String sub, Color c, IconData i) => Expanded(
  child: panel(
    child: Row(
      children: [
        iconTile(i, c, c.withValues(alpha: 0.12), s: 46),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(n, style: tx(28, w: bold)), Text(l, style: tx(14.5, w: bold)), Text(sub, style: tx(12.5, c: K.muted))],
          ),
        ),
      ],
    ),
  ),
);

Widget a01Today() => desk(
  ASec.today,
  title: 'اليوم',
  sub: 'الثلاثاء 20 أكتوبر · اللي ينتظرك أول',
  body: [
    Row(children: [
      _q('12', 'طلبات انضمام', 'أقدمها من يومين · الوعد يومين', K.saffronInk, LucideIcons.userPlus),
      const SizedBox(width: 14),
      _q('4', 'تعديلات أُرسلت', 'رجعت بعد «يحتاج تعديل»', K.sky, LucideIcons.refreshCw),
      const SizedBox(width: 14),
      _q('3', 'بلاغات', 'واحد عن صور نساء · عاجل', K.coral, LucideIcons.flag),
      const SizedBox(width: 14),
      _q('2', 'خلافات دفعات', 'العريس دفع والمزود ما استلم', K.coral, LucideIcons.scale),
    ]),
    gap(16),
    Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('تنبيهات السوق', style: tx(17, w: bold)),
                  gap(10),
                  for (final r in const [
                    (LucideIcons.calendarX, 'تقويم 31 مزود ما تحدّث من 14 يوم', 'العرسان يشوفون عندهم «اسأل عن التوفر»', 'ذكّرهم'),
                    (LucideIcons.timerOff, '18 طلب انتهى بدون رد هذا الأسبوع', 'أغلبها مصورين في عدن', 'شوفها'),
                    (LucideIcons.store, '9 ملفات دليل وصلها طلب وما استلمها أحد', 'رابط واتساب انرسل لهم', 'تابع'),
                    (LucideIcons.packageX, '4 مزودين تأخروا في التسليم أكثر من وعدهم', 'تصوير', 'شوفها'),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(children: [
                        Icon(r.$1, color: K.muted, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: t2(r.$2, r.$3)),
                        softAction(r.$4, fg: A.c, bg: A.soft),
                      ]),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('آخر 30 يوم', style: tx(17, w: bold)),
                  gap(12),
                  for (final r in const [('خطط جديدة', '1,240'), ('مزودين مقبولين', '86'), ('طلبات عروض', '3,910'), ('حجوزات مؤكدة', '1,102'), ('متوسط رد المزودين', '5 ساعات'), ('حجز مزدوج', '0')])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(children: [Expanded(child: t(r.$1, c: K.muted)), t(r.$2, b: true)]),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ],
);

Widget a02Joins() => desk(
  ASec.joins,
  title: 'طلبات الانضمام',
  sub: 'الأقدم أول · الوعد للمزود: رد خلال يومين',
  actions: [softAction('الكل 12', fg: A.c, bg: A.soft), softAction('أُرسل تعديل 4', fg: K.sky, bg: K.skySoft)],
  body: [
    table(
      const [('المزود', 4), ('القسم والنموذج', 3), ('المدينة', 2), ('ينتظر', 2), ('تنبيهات', 3), ('', 2)],
      [
        [t2('استوديو لحظة', 'علي الشامي · 773 210 455'), t('تصوير · أكثر من فريق'), t('صنعاء'), t('يومين', b: true, c: K.coral), tag('صورتين فيهن وجوه نساء', K.coral, K.coralSoft), aBtn('راجع')],
        [t2('فرقة الأمجاد للبرع', 'صالح العزي'), t('برع · عرس واحد'), t('ذمار'), t('يوم'), t('—', c: K.faint), aBtn('راجع')],
        [t2('محلات الأناقة', 'منصور الحداد'), t('ملابس · أبيع'), t('صنعاء'), t('يوم'), tag('رقمه يطابق ملف دليل', K.sky, K.skySoft), aBtn('راجع')],
        [t2('كوافيرة أم ريان', 'من البيت · بدون سجل'), t('كوافير · عرس واحد'), t('عدن'), t('5 ساعات'), tag('للنساء · رقم مخفي', K.lilac, K.lilacSoft), aBtn('راجع')],
        [t2('حراسات الأمان', 'شركة'), t('حراسات · أكثر من فريق'), t('تعز'), t('3 ساعات'), t('—', c: K.faint), aBtn('راجع')],
      ],
      hi: 0,
    ),
  ],
);

Widget a03Review() {
  Widget f(String l, String v, {String? note, bool flag = false}) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: note != null ? K.coral : K.line, width: note != null ? 2 : 1)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: t2(l, v)),
          if (flag) tag('آلي: وجوه نساء', K.coral, K.coralSoft),
          const SizedBox(width: 8),
          softAction(note == null ? 'ملاحظة' : 'عدّل الملاحظة', fg: A.c, bg: A.soft),
        ]),
        if (note != null) ...[gap(8), Text('ملاحظتك للمزود: $note', style: tx(13.5, w: bold, c: K.coral))],
      ],
    ),
  );
  return desk(
    ASec.joins,
    title: 'استوديو لحظة',
    sub: 'تصوير · صنعاء · أكثر من فريق · أُرسل قبل يومين',
    actions: [aBtn('اطلب تعديل (2)', bg: K.saffronInk), aBtn('وافق', bg: K.green), aBtn('ارفض', bg: Colors.white, fg: K.coral)],
    body: [
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(children: [
                f('الاسم ويخدم', 'استوديو لحظة · الرجال والنساء'),
                f('المناطق', 'كل صنعاء · يسافر'),
                f('الصور', '6 صور', note: 'صورتين فيهن وجوه نساء واضحة. شيلهن أو بدّلهن.', flag: true),
                f('الفرق', '3 فرق رجال · فريق مصوّرات'),
                f('باقة صور وفيديو', '450,000 ر.ي صنعاء', note: 'اكتب وش تشمل: كم صورة، ومدة الفيلم، والألبوم.'),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('فحص سريع', style: tx(17, w: bold)),
                    gap(10),
                    for (final r in const [
                      (true, 'الرقم تأكد برمز واتساب'),
                      (true, 'ما فيه ملف ثاني بنفس الاسم'),
                      (false, 'الصور: 2 فيهن وجوه'),
                      (true, 'الأسعار بعملة واضحة'),
                      (false, 'باقة بدون «يشمل»'),
                    ])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Icon(r.$1 ? LucideIcons.checkCircle2 : LucideIcons.alertCircle, size: 18, color: r.$1 ? K.green : K.coral),
                          const SizedBox(width: 10),
                          t(r.$2),
                        ]),
                      ),
                    gap(14),
                    Text('أسباب الرفض الجاهزة', style: tx(14, w: bold, c: K.muted)),
                    gap(8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      tag('صور مو من شغله', K.muted, K.line),
                      tag('نشاط مكرر', K.muted, K.line),
                      tag('خارج الأقسام', K.muted, K.line),
                    ]),
                    gap(14),
                    Text('المزود يشوف ملاحظتك جنب الحقل نفسه، ويضغط «أرسلت التعديل».', style: tx(13, c: K.muted)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget a04Verify() => desk(
  ASec.verify,
  title: 'التوثيق',
  sub: '6 ينتظرون · المستندات تنحذف بعد القرار',
  body: [
    Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: table(
              const [('المزود', 3), ('الطريقة', 3)],
              [
                [t2('قاعة سبأ', 'صنعاء'), t('السجل التجاري')],
                [t2('استوديو لحظة', 'صنعاء'), t('البطاقة + صورة المحل')],
                [t2('منقشة أم سارة', 'من البيت'), t('البطاقة + مزكّي')],
              ],
              hi: 2,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('منقشة أم سارة · البطاقة + مزكّي', style: tx(18, w: bold)),
                  gap(12),
                  Row(children: [
                    Expanded(child: Container(height: 150, decoration: BoxDecoration(color: A.soft, borderRadius: BorderRadius.circular(14)), child: const Center(child: Icon(LucideIcons.contact, size: 40, color: K.muted)))),
                    const SizedBox(width: 12),
                    Expanded(child: panel(c: K.bg, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      t('المزكّي', c: K.muted, fs: 13), t('أم فيصل · 771 900 112', b: true),
                      gap(8), t('العلاقة', c: K.muted, fs: 13), t('زبونة سابقة', b: true),
                    ]))),
                  ]),
                  gap(14),
                  for (final r in const [(true, 'الاسم في البطاقة يطابق الحساب'), (true, 'رقم الحساب تأكد بواتساب'), (false, 'اتصلنا بالمزكّي')])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [Icon(r.$1 ? LucideIcons.checkSquare : LucideIcons.square, color: r.$1 ? K.green : K.faint, size: 20), const SizedBox(width: 10), t(r.$2)]),
                    ),
                  gap(14),
                  Row(children: [aBtn('اتصل بالمزكّي', bg: A.soft, fg: A.c, icon: LucideIcons.phone), const SizedBox(width: 10), aBtn('وثّق', bg: K.green), const SizedBox(width: 10), aBtn('مو كافي', bg: Colors.white, fg: K.coral)]),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ],
);

Widget a05Reports() => desk(
  ASec.reports,
  title: 'البلاغات',
  sub: 'المحادثة ما تنفتح إلا داخل بلاغ',
  body: [
    Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: table(
              const [('البلاغ', 4), ('', 1)],
              [
                [t2('صورة نساء في معرض مزود', 'آلي · قبل ساعة'), tag('عاجل', K.coral, K.coralSoft)],
                [t2('كلام غير لائق في محادثة', 'من عريس · أمس'), t('')],
                [t2('تقييم فيه رقم جوال', 'من مزود · أمس'), t('')],
              ],
              hi: 1,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('كلام غير لائق في محادثة', style: tx(18, w: bold)),
                  t('عادل الريمي ← فرقة الأفراح · طلب الزفة 21 يناير', c: K.muted, fs: 13.5),
                  gap(12),
                  panel(c: K.bg, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    t('فرقة الأفراح · 9:12', c: K.muted, fs: 12.5),
                    t('«…» (الرسالة المبلّغ عنها)', b: true),
                    gap(8),
                    t('عادل · 9:14', c: K.muted, fs: 12.5),
                    t('«ليش تكلمني كذا؟»'),
                  ])),
                  gap(10),
                  t('سجل المزود: بلاغ ثاني خلال 3 شهور', c: K.saffronInk, b: true, fs: 13.5),
                  gap(14),
                  Row(children: [aBtn('احذف الرسالة'), const SizedBox(width: 10), aBtn('نبّه المزود', bg: K.saffronInk), const SizedBox(width: 10), aBtn('أوقف الحساب', bg: Colors.white, fg: K.coral), const SizedBox(width: 10), aBtn('ما فيه شيء', bg: A.soft, fg: A.c)]),
                  gap(10),
                  t('الإيقاف ما يلغي حجوزاته المؤكدة. والطرفين يوصلهم قرارك.', c: K.muted, fs: 13),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ],
);

Widget a06Deposits() => desk(
  ASec.deposits,
  title: 'خلافات الدفعات',
  sub: 'العريس سجّل إنه دفع، والمزود قال ما وصلت. اعّرست ما يمسك فلوس: نساعدهم يتفاهمون',
  body: [
    panel(
      border: K.coral,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('فرقة الأفراح ↔ محمد الحمدي', style: tx(19, w: bold)),
            t('الزفة 21 يناير · 100,000 ر.ي صنعاء · جوالي · 20 نوفمبر', c: K.muted, fs: 14),
            gap(14),
            Row(children: [
              Expanded(child: panel(c: K.bg, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [t('العريس', c: K.muted, fs: 13), t('«حوّلت من جوالي وهذا السند»', b: true), gap(8), Container(height: 90, decoration: BoxDecoration(color: A.soft, borderRadius: BorderRadius.circular(12)), child: const Center(child: Icon(LucideIcons.receipt, color: K.muted)))]))),
              const SizedBox(width: 12),
              Expanded(child: panel(c: K.bg, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [t('المزود', c: K.muted, fs: 13), t('«ما وصلني شيء على رقمي»', b: true), gap(8), t('رقم المزود في الاتفاق: 771 554 220', fs: 13.5), t('رقم في السند: 771 554 202', fs: 13.5, c: K.coral, b: true)]))),
            ]),
          ])),
        ],
      ),
    ),
    gap(14),
    Row(children: [
      aBtn('أرسل للطرفين: الرقم مختلف', icon: LucideIcons.send),
      const SizedBox(width: 10),
      aBtn('انحلت', bg: K.green),
      const SizedBox(width: 10),
      aBtn('ما انحلت: سجّل الخلاف', bg: Colors.white, fg: K.coral),
    ]),
    gap(10),
    t('الخلاف المسجل يظهر للطرفين في الحجز، وما يأثر على التقييم لين ينحل.', c: K.muted, fs: 13),
  ],
);

Widget a07Listings() => desk(
  ASec.listings,
  title: 'ملفات الدليل',
  sub: 'مزودين ما عندهم حساب. يستقبلون طلبات، ويوصلهم رابط واتساب يستلمون منه الملف',
  actions: [aBtn('استيراد ملف CSV', bg: A.soft, fg: A.c, icon: LucideIcons.upload), aBtn('أضف ملف', icon: LucideIcons.plus)],
  body: [
    table(
      const [('الملف', 4), ('القسم', 2), ('الطلبات', 2), ('الرابط', 3), ('الحالة', 2)],
      [
        [t2('مصور الحارة', 'صنعاء · 777 300 118'), t('تصوير'), t('2 ينتظرون', b: true, c: K.coral), t('انرسل مرتين · آخره أمس'), tag('ما استلمه', K.saffronInk, K.saffronSoft)],
        [t2('مطابخ الخير', 'إب'), t('طباخين'), t('1'), t('انرسل اليوم'), tag('ما استلمه', K.saffronInk, K.saffronSoft)],
        [t2('استوديو لحظة', 'صنعاء'), t('تصوير'), t('—'), t('استلمه 12 أكتوبر'), tag('استلمه', K.green, K.greenSoft)],
        [t2('فرقة النجوم', 'عدن'), t('مزمار وبرع'), t('0'), t('رقم بدون واتساب'), tag('اتصل بهم', K.coral, K.coralSoft)],
      ],
    ),
    gap(12),
    t('آخر استيراد: 214 ملف من دليل صنعاء · 9 مكررة ما انضافت · 3 أرقام غلط', c: K.muted, fs: 13.5),
  ],
);

Widget a08Categories() => desk(
  ASec.categories,
  title: 'الأقسام',
  sub: 'قسم واحد للعريس والعروسة · النموذج المقترح والمزود يقدر يغيّره',
  actions: [aBtn('قسم جديد', icon: LucideIcons.plus)],
  body: [
    table(
      const [('القسم', 3), ('عند العريس', 2), ('عند العروسة', 2), ('النموذج المقترح', 3), ('المدة', 2), ('المزودين', 1)],
      [
        [t('الصالات', b: true), t('القاعات'), t('الصالات'), t('أكثر من قاعة'), t('ليلة أو فترة'), t('64')],
        [t('الفنانين', b: true), t('الفنانين'), t('الفنانات'), t('عرس واحد في الفترة'), t('فترة'), t('41')],
        [t('التصوير', b: true), t('المصورين'), t('المصورات'), t('أكثر من فريق'), t('فترة'), t('88')],
        [t('المزمار والبرع', b: true), t('المزمار والبرع'), t('— ما يظهر'), t('عرس واحد في الفترة'), t('فترة'), t('23')],
        [t('الكوش والزينة', b: true), t('الكوش'), t('الكوش والتنسيق'), t('أكثر من طقم'), t('أيام'), t('37')],
        [t('السيارات', b: true), t('سيارات الزفة'), t('سيارات الزفة'), t('أكثر من قطعة · بالعدد'), t('يوم'), t('19')],
        [t('الملابس', b: true), t('ملابس العريس'), t('— ما يظهر'), t('أبيع'), t('—'), t('12')],
        [t('الماء والوجبات', b: true), t('الماء والضيافة'), t('الماء والضيافة'), t('أبيع'), t('—'), t('26')],
      ],
    ),
  ],
);

Widget a09Support() => desk(
  ASec.support,
  title: 'الدعم',
  sub: 'ابحث برقم الهاتف',
  body: [
    panel(pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(children: [const Icon(LucideIcons.search, color: K.muted), const SizedBox(width: 10), t('777 123 456', b: true)])),
    gap(14),
    Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('محمد الحمدي', style: tx(19, w: bold)),
            t('حساب من 2 أكتوبر · جهازين', c: K.muted, fs: 13.5),
            gap(12),
            for (final r in const [('خطته', 'عرس محمد · 21 يناير · نشطة'), ('مشارك في', 'عرس صالح · مساعد'), ('مزود؟', 'لا'), ('آخر رمز', 'وصل 9:40 · ما فيه قفل')])
              Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [SizedBox(width: 110, child: t(r.$1, c: K.muted)), Expanded(child: t(r.$2, b: true))])),
          ]))),
          const SizedBox(width: 16),
          Expanded(child: panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('اللي تقدر تسويه', style: tx(17, w: bold)),
            gap(10),
            for (final r in const [
              (LucideIcons.unlock, 'فك قفل الرموز', 'بعد 5 محاولات غلط'),
              (LucideIcons.logOut, 'اطلعه من كل الأجهزة', 'لو جواله انسرق'),
              (LucideIcons.rotateCcw, 'رجّع حساب قيد الحذف', 'خلال الـ30 يوم'),
              (LucideIcons.archiveRestore, 'رجّع خطة من الذكريات', 'بطلب صاحبها'),
            ])
              Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [Icon(r.$1, color: A.c, size: 20), const SizedBox(width: 10), Expanded(child: t2(r.$2, r.$3))])),
            gap(8),
            t('ما تشوف مال الخطة ولا ضيوفها. وكل إجراء ينسجل.', c: K.muted, fs: 13),
          ]))),
        ],
      ),
    ),
  ],
);

Widget a10Settings() => desk(
  ASec.settings,
  title: 'الإعدادات',
  sub: 'الأرقام اللي تمشّي القواعد · كل تغيير ينسجل',
  body: [
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الطلبات والحجز', style: tx(17, w: bold)),
          gap(8),
          for (final r in const [('الطلب ينتهي بدون رد بعد', '7 أيام'), ('صلاحية العرض الافتراضية', '10 أيام'), ('طلب الحجز ينتظر تأكيد المزود', 'يومين'), ('الحجز المبدئي الافتراضي', '3 أيام'), ('«فاضي» يظهر لو التقويم محدّث خلال', '14 يوم'), ('الحجز يتحسب «تم» لو المزود ما بلّغ خلال', 'يومين')])
            Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [Expanded(child: t(r.$1)), softAction(r.$2, fg: A.c, bg: A.soft)])),
        ]))),
        const SizedBox(width: 16),
        Expanded(child: panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('العملات وأسعار الصرف', style: tx(17, w: bold)),
          gap(8),
          for (final r in const [('دولار · صنعاء', '536 · اليوم 9 الصبح'), ('دولار · عدن', '1,628 · اليوم 9 الصبح'), ('سعودي · صنعاء', '141'), ('سعودي · عدن', '428')])
            Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [Expanded(child: t(r.$1)), t(r.$2, b: true)])),
          gap(14),
          Text('الحساب والمساعد', style: tx(17, w: bold)),
          gap(8),
          for (final r in const [('مهلة حذف الحساب', '30 يوم'), ('طلبات المساعد في اليوم', '30'), ('محاولات الرمز قبل الوقفة', '5 · 15 دقيقة')])
            Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [Expanded(child: t(r.$1)), softAction(r.$2, fg: A.c, bg: A.soft)])),
        ]))),
      ],
    ),
  ],
);

Widget a11Log() => desk(
  ASec.log,
  title: 'السجل',
  sub: 'كل إجراء إداري، مين سواه ومتى وليش',
  body: [
    table(
      const [('متى', 2), ('مين', 2), ('وش سوى', 5), ('السبب', 4)],
      [
        [t('اليوم 10:41'), t('رشاد'), t('طلب تعديل: استوديو لحظة (حقلين)', b: true), t('صور فيها وجوه، باقة بدون «يشمل»')],
        [t('اليوم 9:02'), t('نادية'), t('وثّقت: قاعة سبأ', b: true), t('سجل تجاري سليم · المستند انحذف')],
        [t('أمس 6:15'), t('رشاد'), t('أوقف: مصور س (مؤقت)', b: true), t('3 بلاغات تأخير تسليم · 5 حجوزات مستمرة')],
        [t('أمس 2:30'), t('نادية'), t('رجّعت حساب قيد الحذف: 770 998 321', b: true), t('بطلب صاحبه')],
        [t('أمس 11:00'), t('النظام'), t('استيراد CSV: 214 ملف', b: true), t('9 مكررة · 3 أرقام غلط')],
      ],
    ),
  ],
);
