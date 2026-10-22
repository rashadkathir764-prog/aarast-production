// Admin prototype, grounded in what admin-web already has (see
// docs/superpowers/audit/admin_current_map.md). Each screen keeps the existing
// page, its endpoints and permissions, and adds only what the audit found
// missing or what the new provider and plan journeys need.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import 'akit.dart';

// ============================================================ نظرة عامة

/// Existing DashboardPage: same stats call, plus the queues every role
/// actually works from, and alerts the journeys create.
Widget a01Dashboard() => desk(
  'dash',
  crumb: 'نظرة عامة',
  title: 'مرحباً، نادية',
  sub: 'اللي ينتظرك اليوم حسب صلاحيتك',
  body: [
    Row(children: [
      stat('8', 'طلبات جديدة', sub: 'أقدمها من يومين'),
      const SizedBox(width: 12),
      stat('4', 'أُعيد إرسالها', c: K.sky, sub: 'بعد «يحتاج تعديل»'),
      const SizedBox(width: 12),
      stat('6', 'بانتظار التوثيق', sub: 'مستندات مرفوعة'),
      const SizedBox(width: 12),
      stat('2', 'خلافات دفعات', c: K.coral, sub: 'العريس دفع والمزود ما استلم'),
    ]),
    gap(12),
    Row(children: [
      stat('18,402', 'المستخدمون'),
      const SizedBox(width: 12),
      stat('412', 'المزودون', sub: '388 نشط · 31 بلا حساب'),
      const SizedBox(width: 12),
      stat('6,930', 'خطط الزواج'),
      const SizedBox(width: 12),
      stat('3,910', 'طلبات العروض', sub: 'آخر 30 يوم'),
    ]),
    gap(12),
    Expanded(
      child: panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تنبيهات السوق', style: tx(16, w: bold)),
            gap(6),
            for (final r in const [
              (LucideIcons.calendarX, '31 مزود ما حدّثوا تقويمهم من 14 يوم', 'العرسان يشوفون عندهم «اسأل عن التوفر»'),
              (LucideIcons.timerOff, '18 طلب عرض انتهى بدون رد هذا الأسبوع', 'أغلبها مصورين في عدن'),
              (LucideIcons.store, '9 ملفات بلا حساب وصلها طلب وما استلمها صاحبها', 'رابط واتساب انرسل لهم'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [Icon(r.$1, color: K.muted, size: 19), const SizedBox(width: 10), Expanded(child: t2(r.$2, r.$3)), softAction('شوفها', fg: A.c, bg: A.soft)]),
              ),
          ],
        ),
      ),
    ),
  ],
);

/// Existing ReportsPage (success report + market prices from 4.21), with
/// the date range the backend already accepts and no developer wording.
Widget a02Reports() => desk(
  'reports',
  crumb: 'السوق',
  title: 'التقارير',
  sub: 'من 1 سبتمبر لين 30 سبتمبر',
  actions: [aBtn('آخر 30 يوم', bg: A.soft, fg: A.c, icon: LucideIcons.calendarDays), aBtn('تنزيل', bg: A.soft, fg: A.c, icon: LucideIcons.download)],
  body: [
    Row(children: [
      stat('4,120 من 18,402', 'مستخدمون نشطون هذا الأسبوع'),
      const SizedBox(width: 12),
      stat('14', 'تكاليف مسجلة لكل خطة'),
      const SizedBox(width: 12),
      stat('28٪', 'طلبات عروض صارت حجز', sub: '1,102 من 3,910'),
      const SizedBox(width: 12),
      stat('388', 'مزودون يراهم العرسان'),
    ]),
    gap(12),
    table(
      const [('المدينة', 2), ('القسم', 2), ('المزودون', 1), ('أقل سعر', 2), ('الوسيط', 2), ('أعلى سعر', 2)],
      [
        [t('صنعاء'), t('التصوير'), t('24'), t('180,000'), t('350,000', b: true), t('900,000')],
        [t('صنعاء'), t('الصالات'), t('19'), t('600,000'), t('1,500,000', b: true), t('4,000,000')],
        [t('عدن'), t('التصوير'), t('11'), t('120,000 عدن'), t('260,000 عدن', b: true), t('700,000 عدن')],
        [t('تعز'), t('الكوش'), t('2'), t('—'), t('ما يكفي', c: K.muted), t('—')],
      ],
    ),
    gap(8),
    t('السعر يظهر لما يكون عندنا 3 مزودين على الأقل. وكل مدينة بعملتها.', c: K.muted, fs: 12.5),
  ],
);

// ============================================================ المزودين

/// Existing ProviderApplicationsPage: same filters, plus how long each has
/// waited and whether it came back after changes (needs a resubmit state).
Widget a03Applications() => desk(
  'apps',
  crumb: 'المزودين',
  title: 'طلبات الانضمام',
  sub: 'الأقدم أول · نوعد المزود برد خلال يومين',
  actions: [aBtn('جديد 8', bg: A.c), aBtn('أُعيد إرسالها 4', bg: K.skySoft, fg: K.sky), aBtn('يحتاج تعديل 6', bg: A.soft, fg: A.c), aBtn('مرفوض', bg: A.soft, fg: A.c)],
  body: [
    table(
      const [('المزود', 4), ('القسم والطريقة', 3), ('المدينة', 2), ('ينتظر', 2), ('ملاحظة', 4)],
      [
        [t2('استوديو ضوء صنعاء', 'علي الشامي · 773 210 455'), t('تصوير · أكثر من فريق'), t('صنعاء'), t('يومين', b: true, c: K.coral), tag('أُعيد إرساله · كان يحتاج تعديل', K.sky, K.skySoft)],
        [t2('فرقة الأمجاد للبرع', 'صالح العزي'), t('برع · عرس واحد في الفترة'), t('ذمار'), t('يوم'), tag('صورتين فيهن وجوه (فحص آلي)', K.coral, K.coralSoft)],
        [t2('محلات الأناقة', 'منصور الحداد'), t('ملابس · بيع'), t('صنعاء'), t('يوم'), tag('رقمه يطابق ملف بلا حساب', K.saffronInk, K.saffronSoft)],
        [t2('كوافيرة أم ريان', 'من البيت'), t('كوافير · عرس واحد'), t('عدن'), t('5 ساعات'), tag('للنساء · الرقم مخفي', K.lilac, K.lilacSoft)],
      ],
      hi: 0,
    ),
  ],
);

/// Existing ProviderApplicationDetailsPage, made into a real review: a note
/// per field (today one free-text note), who decided what before, and the
/// work photos (today only logo and cover).
Widget a04Review() {
  Widget f(String l, String v, {String? note, String? was}) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: note != null ? K.coral : K.line, width: note != null ? 2 : 1)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [Expanded(child: t2(l, v)), softAction(note == null ? 'ملاحظة' : 'عدّل', fg: A.c, bg: A.soft)]),
        if (was != null) ...[gap(4), t('قبل التعديل: $was', c: K.sky, fs: 12.5, b: true)],
        if (note != null) ...[gap(6), t('للمزود: $note', c: K.coral, b: true, fs: 13)],
      ],
    ),
  );
  return desk(
    'apps',
    crumb: 'المزودين / تفاصيل طلب',
    title: 'استوديو ضوء صنعاء',
    sub: 'تصوير · صنعاء · أكثر من فريق · أُعيد إرساله اليوم',
    actions: [aBtn('اطلب تعديل', bg: K.saffronInk), aBtn('اعتماد', bg: K.green), aBtn('رفض', bg: Colors.white, fg: K.coral)],
    body: [
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(children: [
                f('النشاط ويخدم', 'استوديو ضوء صنعاء · الرجال والنساء'),
                f('صور الشغل', '6 صور', was: '2 فيهن وجوه، انشالت'),
                f('باقة صور وفيديو', '550,000 ر.ي صنعاء · مصوّرين، 300 صورة، فيلم 10 دقايق، ألبوم', was: 'بدون «يشمل»'),
                f('الفرق', '3 فرق رجال · فريق مصوّرات'),
                f('المناطق', 'كل صنعاء · يسافر'),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('خط المراجعة', style: tx(15, w: bold)),
                    gap(6),
                    for (final r in const [('18 أكتوبر', 'قدّم الطلب'), ('19 أكتوبر', 'رشاد طلب تعديل في حقلين'), ('اليوم 10:02', 'المزود أرسل التعديل')])
                      Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [SizedBox(width: 90, child: t(r.$1, c: K.muted, fs: 12.5)), Expanded(child: t(r.$2, fs: 13.5))])),
                    gap(10),
                    Text('فحص سريع', style: tx(15, w: bold)),
                    chk(true, 'الرقم مأكد برمز واتساب'),
                    chk(true, 'ما فيه وجوه نساء في الصور'),
                    chk(true, 'كل باقة فيها «يشمل»'),
                    chk(true, 'ما فيه ملف بنفس الاسم'),
                    gap(8),
                    t('ملاحظتك تظهر للمزود جنب الحقل نفسه.', c: K.muted, fs: 12.5),
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

/// Existing ProvidersPage, with the columns the audit found missing:
/// verified, featured, without account, bookings.
Widget a05Directory() => desk(
  'providers',
  crumb: 'المزودين',
  title: 'دليل المزودين',
  sub: '412 مزود · 388 نشط',
  actions: [aBtn('أضف مزود بلا حساب', bg: A.soft, fg: A.c, icon: LucideIcons.plus), aBtn('استيراد ملف', bg: A.soft, fg: A.c, icon: LucideIcons.upload)],
  body: [
    table(
      const [('المزود', 4), ('الحالة', 2), ('المدينة', 2), ('علامات', 4), ('الحجوزات', 2), ('التقييم', 2)],
      [
        [t2('قاعة سبأ', 'الصالات · قاعتين'), tag('نشط', K.green, K.greenSoft), t('صنعاء'), Wrap(spacing: 4, children: [tag('موثّق', K.green, K.greenSoft), tag('مميز', K.saffronInk, K.saffronSoft)]), t('46'), t('4.8 · 63')],
        [t2('استوديو ضوء صنعاء', 'التصوير · 4 فرق'), tag('نشط', K.green, K.greenSoft), t('صنعاء'), tag('موثّق', K.green, K.greenSoft), t('31'), t('4.7 · 38')],
        [t2('مصور الحارة', 'التصوير'), tag('نشط', K.green, K.greenSoft), t('صنعاء'), tag('بلا حساب', K.muted, K.line), t('—'), t('—')],
        [t2('مصور س', 'التصوير'), tag('موقوف', K.coral, K.coralSoft), t('عدن'), tag('تقويم قديم', K.saffronInk, K.saffronSoft), t('5 جاية'), t('3.9 · 21')],
      ],
    ),
  ],
);

/// Existing ProviderDetailsPage. Suspending today hides the provider and
/// notifies him only; here the dialog says what happens to his work.
Widget a06ProviderSuspend() => confirm(
  desk(
    'providers',
    crumb: 'المزودين / تفاصيل مزود',
    title: 'مصور س',
    sub: 'التصوير · عدن · نشط من مارس',
    actions: [aBtn('إيقاف', bg: K.coral), aBtn('إلغاء التوثيق', bg: A.soft, fg: A.c)],
    body: [
      Row(children: [stat('5', 'حجوزات جاية'), const SizedBox(width: 12), stat('3', 'طلبات مفتوحة'), const SizedBox(width: 12), stat('3', 'بلاغات'), const SizedBox(width: 12), stat('3.9', 'التقييم', sub: '21 تقييم')]),
    ],
  ),
  title: 'إيقاف مصور س',
  effects: const [
    'يختفي من الدليل وما توصله طلبات جديدة.',
    '5 حجوزات مؤكدة تكمل كما هي، والعرسان يوصلهم إن المزود موقوف وحجزهم قائم.',
    '3 طلبات مفتوحة تنقفل، والعرسان يوصلهم يطلبون من غيره.',
    'يوصله السبب، ويقدر يتواصل مع الدعم.',
  ],
  reasonLabel: 'السبب (يوصل المزود)',
  go: 'أوقف',
  goC: K.coral,
);

/// New page from the existing «add without account» and CSV cards: who
/// received requests and never claimed, and the WhatsApp link follow-up.
Widget a07Listed() => desk(
  'listed',
  crumb: 'المزودين',
  title: 'ملفات بلا حساب',
  sub: 'يستلمها صاحبها برقمه · 31 ملف',
  actions: [aBtn('تنزيل القالب', bg: A.soft, fg: A.c), aBtn('استيراد ملف', icon: LucideIcons.upload)],
  body: [
    table(
      const [('الملف', 4), ('القسم', 2), ('طلبات تنتظره', 2), ('رابط الاستلام', 3), ('الحالة', 2)],
      [
        [t2('مصور الحارة', 'صنعاء · 777 300 118'), t('التصوير'), t('2', b: true, c: K.coral), t('انرسل مرتين · آخره أمس'), tag('ما استلمه', K.saffronInk, K.saffronSoft)],
        [t2('مطابخ الخير', 'إب'), t('الطباخين'), t('1'), t('انرسل اليوم'), tag('ما استلمه', K.saffronInk, K.saffronSoft)],
        [t2('فرقة النجوم', 'عدن'), t('المزمار والبرع'), t('1'), t('الرقم بدون واتساب'), tag('اتصل به', K.coral, K.coralSoft)],
        [t2('استوديو ضوء صنعاء', 'صنعاء'), t('التصوير'), t('—'), t('استلمه 12 أكتوبر'), tag('استلمه', K.green, K.greenSoft)],
      ],
    ),
    gap(10),
    panel(
      c: A.soft,
      child: t('آخر استيراد: 214 صف · انضاف 202 · 9 مكررة · 3 أرقام غلط (نزّل تقرير الأخطاء)', fs: 13.5),
    ),
  ],
);

// ============================================================ الكتالوج

/// Existing CategoriesPage: same fields (Arabic and English names, groom
/// and bride flags), plus the bride-side name, the suggested provider model
/// and period, and re-enable for disabled rows.
Widget a08Categories() => desk(
  'catalog',
  crumb: 'النظام / الكتالوج',
  title: 'الأقسام',
  sub: 'قسم واحد للعريس والعروسة · المزود يقدر يغيّر الطريقة المقترحة',
  actions: [aBtn('قسم جديد', icon: LucideIcons.plus)],
  body: [
    table(
      const [('القسم', 3), ('عند العريس', 2), ('عند العروسة', 2), ('الطريقة المقترحة', 3), ('المدة', 2), ('الحالة', 2)],
      [
        [t('الصالات', b: true), t('القاعات'), t('الصالات'), t('أكثر من قاعة'), t('ليلة أو فترة'), tag('نشط', K.green, K.greenSoft)],
        [t('الفنانين', b: true), t('الفنانين'), t('الفنانات'), t('عرس واحد في الفترة'), t('فترة'), tag('نشط', K.green, K.greenSoft)],
        [t('التصوير', b: true), t('المصورين'), t('المصورات'), t('أكثر من فريق'), t('فترة'), tag('نشط', K.green, K.greenSoft)],
        [t('المزمار والبرع', b: true), t('المزمار والبرع'), t('ما يظهر', c: K.muted), t('عرس واحد في الفترة'), t('فترة'), tag('نشط', K.green, K.greenSoft)],
        [t('الكوش والزينة', b: true), t('الكوش'), t('الكوش والتنسيق'), t('أكثر من طقم'), t('أيام'), tag('نشط', K.green, K.greenSoft)],
        [t('الملابس', b: true), t('ملابس العريس'), t('ما يظهر', c: K.muted), t('بيع'), t('—'), tag('نشط', K.green, K.greenSoft)],
        [t('القات', b: true), t('القات'), t('ما يظهر', c: K.muted), t('بيع'), t('—'), Row(mainAxisSize: MainAxisSize.min, children: [tag('معطّل', K.muted, K.line), const SizedBox(width: 6), softAction('فعّله', fg: A.c, bg: A.soft)])],
      ],
    ),
  ],
);

/// Existing ReferenceCatalogsPage (tasks.starter): the item's days-before
/// lives in metadata the UI can't edit today; draft vs published side by side.
Widget a09Catalogs() => desk(
  'catalog',
  crumb: 'النظام / الكتالوج',
  title: 'الكتالوجات',
  sub: 'تتحدث في التطبيق بدون إصدار جديد',
  actions: [aBtn('قوالب المهام', bg: A.c), aBtn('تصنيفات الميزانية', bg: A.soft, fg: A.c)],
  body: [
    Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: table(
              const [('المهمة', 4), ('قبل العرس', 2), ('لمين', 2), ('الحالة', 2)],
              [
                [t2('احجز القاعة', 'المكان'), t('120 يوم'), t('العريس والعروسة'), tag('منشورة', K.green, K.greenSoft)],
                [t2('أوراق العقد عند الأمين الشرعي', 'العقد'), t('30 يوم'), t('العريس'), tag('مسودة', K.saffronInk, K.saffronSoft)],
                [t2('رتّب القات مع المقوّت', 'الضيافة'), t('3 أيام'), t('العريس'), tag('منشورة', K.green, K.greenSoft)],
                [t2('موعد المنقشة', 'التجهيز'), t('2 يوم'), t('العروسة'), tag('منشورة', K.green, K.greenSoft)],
              ],
              hi: 1,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('أوراق العقد · مسودة', style: tx(15, w: bold)),
                  gap(10),
                  Row(children: [Expanded(child: t('المنشور', c: K.muted, fs: 12.5)), Expanded(child: t('المسودة', c: K.muted, fs: 12.5))]),
                  gap(4),
                  Row(children: [Expanded(child: t('قبل 21 يوم')), Expanded(child: t('قبل 30 يوم', b: true, c: K.sky))]),
                  Row(children: [Expanded(child: t('العقد')), Expanded(child: t('العقد'))]),
                  gap(14),
                  Row(children: [aBtn('انشر المسودة'), const SizedBox(width: 8), aBtn('ارجع للمنشور', bg: A.soft, fg: A.c)]),
                  gap(8),
                  t('النشر يوصل الخطط الجديدة بس، والخطط القائمة ما تتغير.', c: K.muted, fs: 12.5),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ],
);

// ============================================================ الرقابة

/// Existing ReviewsPage: hide now asks for a reason and tells the reviewer;
/// reviews people report get their own queue; the provider's reply shows.
Widget a10Reviews() => desk(
  'reviews',
  crumb: 'الرقابة',
  title: 'التقييمات',
  sub: 'تنشر على طول · المخالف ينخفي بسبب',
  role: Role.moderator,
  who: 'سارة',
  actions: [aBtn('مبلّغ عنها 5', bg: A.c), aBtn('الكل', bg: A.soft, fg: A.c), aBtn('مخفية', bg: A.soft, fg: A.c)],
  body: [
    table(
      const [('التقييم', 6), ('المزود', 2), ('البلاغ', 3), ('', 3)],
      [
        [t2('★★☆☆☆ «اتصلوا على 77… لو تشتي رقمهم الصح»', 'عادل · 20 يناير'), t('فرقة الأفراح'), t('فيه رقم جوال'), Row(mainAxisSize: MainAxisSize.min, children: [softAction('أخفِ', fg: K.coral, bg: K.coralSoft), const SizedBox(width: 6), softAction('خلّه', fg: A.c, bg: A.soft)])],
        [t2('★☆☆☆☆ «ما جوا أصلًا»', 'فهد · 4 فبراير · رد المزود: «العريس لغى قبل يوم»'), t('مصور س'), t('المزود: كذب'), Row(mainAxisSize: MainAxisSize.min, children: [softAction('شوف الحجز', fg: A.c, bg: A.soft)])],
      ],
    ),
    gap(10),
    t('الإخفاء يطلب سبب، ويوصل للمقيّم. والتقييم بعد حجز «تم» ما ينحذف بسبب إن المزود ما عجبه.', c: K.muted, fs: 12.5),
  ],
);

/// Existing ConversationReportsPage: today it shows no message and offers
/// no sanction. Here the reported message only, both parties, a note.
Widget a11ChatReports() => desk(
  'reports_c',
  crumb: 'الرقابة',
  title: 'البلاغات',
  sub: 'المحادثة ما تنفتح إلا داخل البلاغ',
  role: Role.moderator,
  who: 'سارة',
  body: [
    Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: table(
              const [('البلاغ', 4)],
              [
                [t2('كلام غير لائق', 'عادل بلّغ عن فرقة الأفراح · أمس')],
                [t2('احتيال: طلب تحويل لرقم ثاني', 'محمد بلّغ عن مصور مجهول · اليوم')],
                [t2('إزعاج', 'مزود بلّغ عن عريس · قبل 3 أيام')],
              ],
              hi: 0,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('كلام غير لائق', style: tx(17, w: bold)),
                  t('المبلّغ: عادل الريمي · المبلّغ عنه: فرقة الأفراح · طلب الزفة 21 يناير', c: K.muted, fs: 13),
                  gap(10),
                  panel(c: K.bg, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    t('الرسالة المبلّغ عنها · فرقة الأفراح 9:12', c: K.muted, fs: 12),
                    t('«…»', b: true),
                    t('ما قبلها وما بعدها بس. باقي المحادثة ما تظهر.', c: K.muted, fs: 12),
                  ])),
                  gap(8),
                  t('سجل فرقة الأفراح: بلاغ ثاني خلال 3 شهور', c: K.saffronInk, b: true, fs: 13),
                  gap(12),
                  Row(children: [aBtn('احذف الرسالة'), const SizedBox(width: 8), aBtn('نبّه المزود', bg: K.saffronInk), const SizedBox(width: 8), aBtn('اطلب إيقافه', bg: Colors.white, fg: K.coral), const SizedBox(width: 8), aBtn('ما فيه شيء', bg: A.soft, fg: A.c)]),
                  gap(8),
                  t('الإشراف ما يقدر يوقف مزود. «اطلب إيقافه» يروح لفريق التشغيل.', c: K.muted, fs: 12.5),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ],
);

/// New: bookings exist in the backend with no admin view. Deposits are
/// records both sides confirm; a dispute is when they disagree.
Widget a12Bookings() => desk(
  'bookings',
  crumb: 'الرقابة',
  title: 'الحجوزات والخلافات',
  sub: 'اعّرست ما يمسك فلوس: نوري الفرق ونساعد الطرفين',
  actions: [aBtn('خلافات 2', bg: K.coral), aBtn('كل الحجوزات', bg: A.soft, fg: A.c)],
  body: [
    panel(
      border: K.coral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ضيافة الأصالة مع محمد الحمدي', style: tx(18, w: bold)),
          t('الضيافة 21 يناير · دفعة 200,000 ر.ي صنعاء · جوالي · أمس', c: K.muted, fs: 13.5),
          gap(12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: panel(c: K.bg, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [t('العريس سجّل', c: K.muted, fs: 12), t('«حوّلت من جوالي، وهذا السند»', b: true), gap(6), t('رقم المستلم في السند: 771 554 202', fs: 13)]))),
            const SizedBox(width: 12),
            Expanded(child: panel(c: K.bg, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [t('المزود رد', c: K.muted, fs: 12), t('«ما وصلني شيء»', b: true), gap(6), t('رقمه في الاتفاق: 771 554 220', fs: 13, c: K.coral, b: true)]))),
          ]),
          gap(12),
          Row(children: [aBtn('أرسل للطرفين: الرقم مختلف', icon: LucideIcons.send), const SizedBox(width: 8), aBtn('انحلّت', bg: K.green), const SizedBox(width: 8), aBtn('ما انحلّت', bg: Colors.white, fg: K.coral)]),
        ],
      ),
    ),
    gap(12),
    table(
      const [('الحجز', 4), ('المزود', 3), ('اليوم', 2), ('الحالة', 2)],
      [
        [t2('محمد الحمدي', 'الزفة · فريق 2'), t('استوديو ضوء صنعاء'), t('21 يناير'), tag('مؤكد', K.green, K.greenSoft)],
        [t2('فهد العمري', 'الزفة'), t('مصور س'), t('4 فبراير'), tag('ما صار · بلاغ', K.coral, K.coralSoft)],
      ],
    ),
  ],
);

// ============================================================ الحسابات

/// Existing UserDetailsPage: disabling now confirms what it revokes, and the
/// account-deletion grace period is visible to support.
Widget a13User() => confirm(
  desk(
    'users',
    crumb: 'الناس / تفاصيل مستخدم',
    title: 'محمد الحمدي',
    sub: '777 123 456 · من 2 أكتوبر',
    actions: [aBtn('تعطيل الحساب', bg: Colors.white, fg: K.coral)],
    body: [
      Row(children: [stat('خطة 1', 'صاحب خطة'), const SizedBox(width: 12), stat('1', 'مشارك في خطة'), const SizedBox(width: 12), stat('جهازين', 'مسجّل دخول'), const SizedBox(width: 12), stat('لا', 'طلب حذف')]),
    ],
  ),
  title: 'تعطيل حساب محمد الحمدي',
  effects: const [
    'يطلع من جهازينه الآن.',
    'دعوتين أرسلها للمشاركين تنلغي.',
    'خطته تبقى، والمشاركين معه يكملون.',
    'ما تقدر تشوف مال خطته ولا ضيوفه.',
  ],
  go: 'عطّل',
  goC: K.coral,
);

/// New: admins are created by a CLI script today, always as super admin,
/// and the panel never shows anyone's role.
Widget a14Team() => desk(
  'team',
  crumb: 'الفريق',
  title: 'فريق الإدارة',
  sub: 'مين يدخل اللوحة وبأي دور',
  role: Role.superAdmin,
  who: 'رشاد',
  actions: [aBtn('أضف عضو', icon: LucideIcons.userPlus)],
  body: [
    table(
      const [('العضو', 3), ('الدور', 2), ('يقدر', 5), ('آخر دخول', 2)],
      [
        [t2('رشاد', '777 000 111'), tag('مدير أعلى', A.c, A.soft), t('كل شيء، والسجل، والفريق، والقواعد'), t('الآن')],
        [t2('نادية', '771 222 333'), tag('تشغيل', K.sky, K.skySoft), t('المزودين، والخدمات، والكتالوج، والمستخدمين، والتقارير'), t('قبل ساعة')],
        [t2('سارة', '773 444 555'), tag('إشراف محتوى', K.lilac, K.lilacSoft), t('التقييمات، والبلاغات، وقراءة المزودين'), t('أمس')],
        [t2('عمر', '770 666 777'), tag('دعم', K.green, K.greenSoft), t('قراءة: المستخدمين والمزودين والكتالوج'), t('قبل 3 أيام')],
      ],
    ),
    gap(10),
    t('الدخول بكلمة مرور ورمز واتساب، والجهاز الموثوق 30 يوم. وكل تغيير في الأدوار ينسجل.', c: K.muted, fs: 12.5),
  ],
);

/// Existing AuditLogsPage: names instead of raw ids, the reason the admin
/// typed, and a link to what was changed.
Widget a15Audit() => desk(
  'audit',
  crumb: 'الفريق',
  title: 'سجل التدقيق',
  sub: 'كل إجراء في اللوحة',
  role: Role.superAdmin,
  who: 'رشاد',
  body: [
    table(
      const [('متى', 2), ('مين', 2), ('ايش سوى', 4), ('على', 3), ('السبب', 4), ('النتيجة', 1)],
      [
        [t('10:41'), t('رشاد · مدير أعلى', fs: 13), t('طلب تعديل', b: true), t('استوديو ضوء صنعاء'), t('حقلين: الصور والباقة'), const Icon(LucideIcons.checkCircle2, color: K.green, size: 18)],
        [t('9:02'), t('نادية · تشغيل', fs: 13), t('وثّق', b: true), t('قاعة سبأ'), t('سجل تجاري'), const Icon(LucideIcons.checkCircle2, color: K.green, size: 18)],
        [t('أمس'), t('نادية · تشغيل', fs: 13), t('أوقف', b: true), t('مصور س'), t('3 بلاغات تأخير تسليم'), const Icon(LucideIcons.checkCircle2, color: K.green, size: 18)],
        [t('أمس'), t('سارة · إشراف', fs: 13), t('أوقف مزود', b: true), t('فرقة الأفراح'), t('—'), const Icon(LucideIcons.xCircle, color: K.coral, size: 18)],
      ],
    ),
    gap(8),
    t('الفاشل ينسجل بعد: سارة حاولت توقف مزود وصلاحيتها ما تسمح.', c: K.muted, fs: 12.5),
  ],
);

/// New: the numbers the journeys depend on, read by the backend instead of
/// being hard-coded.
Widget a16Rules() => desk(
  'settings',
  crumb: 'النظام',
  title: 'القواعد',
  sub: 'الأرقام اللي تمشّي التطبيق · كل تغيير ينسجل',
  role: Role.superAdmin,
  who: 'رشاد',
  body: [
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الطلبات والحجز', style: tx(16, w: bold)),
          for (final r in const [('طلب العرض ينتهي بدون رد بعد', '7 أيام'), ('صلاحية العرض الافتراضية', '10 أيام'), ('الحجز المبدئي الافتراضي', '3 أيام'), ('«فاضي» يظهر لو التقويم محدّث خلال', '14 يوم'), ('الحجز يتحسب «تم» لو ما بلّغ المزود خلال', 'يومين')])
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: t(r.$1)), softAction(r.$2, fg: A.c, bg: A.soft)])),
        ]))),
        const SizedBox(width: 14),
        Expanded(child: panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الحسابات والدعوات', style: tx(16, w: bold)),
          for (final r in const [('مهلة حذف الحساب', '30 يوم'), ('صلاحية رابط دعوة المشارك', '7 أيام'), ('محاولات الرمز قبل الوقفة', '5 · 15 دقيقة'), ('طلبات المساعد الذكي في اليوم', '10')])
            Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: t(r.$1)), softAction(r.$2, fg: A.c, bg: A.soft)])),
        ]))),
      ],
    ),
  ],
);


/// Packages and featured listing (owner request: wedding.md section 9,
/// checklist 4.20). The provider pays the owner outside the app; the admin
/// switches the package on by hand. No money moves inside اعّرست.
Widget a17Plans() => desk(
  'plans',
  crumb: 'المزودين',
  title: 'الباقات والظهور المميز',
  sub: 'المزود يدفع لكم برا التطبيق، وأنتم تفعّلون الباقة من هنا',
  actions: [aBtn('فعّل باقة لمزود', icon: LucideIcons.plus)],
  body: [
    Row(children: [
      stat('352', 'مجاني', sub: 'ظهور عادي'),
      const SizedBox(width: 12),
      stat('27', 'مميز', sub: 'فوق في القسم والمدينة'),
      const SizedBox(width: 12),
      stat('9', 'احترافي', sub: 'مميز وإحصائيات وصور أكثر'),
      const SizedBox(width: 12),
      stat('4', 'تنتهي هذا الأسبوع', c: K.saffronInk),
    ]),
    gap(14),
    table(
      const [('المزود', 4), ('الباقة', 2), ('من', 2), ('لين', 2), ('الدفع', 3), ('', 2)],
      [
        [t2('قاعة سبأ', 'الصالات · صنعاء'), tag('احترافي', A.c, A.soft), t('1 أكتوبر'), t('31 ديسمبر'), t2('كاش · 3 شهور', 'سجّلته نادية'), tag('شغّال', K.green, K.greenSoft)],
        [t2('استوديو ضوء صنعاء', 'التصوير · صنعاء'), tag('مميز', K.saffronInk, K.saffronSoft), t('15 سبتمبر'), t('15 أكتوبر'), t2('حوالة الكريمي', 'سجّلتها سارة'), tag('خلص · ذكّره', K.coral, K.coralSoft)],
        [t2('ضيافة الأصالة', 'الضيافة · صنعاء'), tag('مميز', K.saffronInk, K.saffronSoft), t('20 أكتوبر'), t('20 نوفمبر'), t2('ينتظر الدفع', '—'), tag('ما تفعّل', K.muted, K.line)],
      ],
    ),
    gap(14),
    panel(
      c: A.soft,
      child: Row(children: [
        const Icon(LucideIcons.info, color: A.c, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: t('التطبيق ما يستلم فلوس. كل تفعيل ينكتب في سجل العمليات باسم اللي فعّله، والمزود يوصله إشعار ببداية ونهاية باقته. والعرسان يشوفون «مميز» بوضوح، عشان ما يحسبونه ترشيحًا من اعّرست.', c: A.c),
        ),
      ]),
    ),
  ],
);
