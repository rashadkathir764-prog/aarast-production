// Provider journey prototype: account, joining, review, home. The running
// example is «استوديو ضوء صنعاء», a Sana'a photo studio with four teams, one of
// them women photographers.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import 'pkit.dart';

const _join = ['نشاطك', 'وين', 'شغلك', 'طريقتك', 'خدماتك', 'أرسل'];

// ============================================================ الحساب

Widget p01Register() => pPhone(
  action: pBtn('إنشاء حساب مزود'),
  children: [
    subHeader('حساب مزود'),
    Text('ابدأ استقبال طلبات العرسان', style: tx(26, w: bold)),
    gap(4),
    Text('حسابك أنت. نشاطك وأسعارك نسألك عنها بعدين.', style: tx(15, c: K.muted)),
    gap(18),
    pField('اسمك', 'علي الشامي', focused: true),
    gap(10),
    pField('رقم الهاتف', ltr('773 210 455'), icon: LucideIcons.phone),
    gap(10),
    pField('كلمة المرور', '••••••••', icon: LucideIcons.lock),
    gap(12),
    pNote('بعدها رمز على واتساب. ونفس الرقم تقدر تسوي فيه خطة عرسك بعدين.', i: LucideIcons.messageCircle),
    gap(14),
    Center(child: Text('عندي حساب؟ تسجيل الدخول', style: tx(14.5, w: bold, c: P.c))),
  ],
);

Widget p02Claim() => pPhone(
  action: pBtn('إيه، هذا ملفي', icon: LucideIcons.check),
  children: [
    subHeader(''),
    Center(child: iconTile(LucideIcons.store, P.c, P.soft, s: 76, r: 24)),
    gap(14),
    Center(child: Text('لقينا ملف بنفس رقمك', style: tx(24, w: bold))),
    gap(4),
    Center(child: Text('فريق اعّرست أضافه من الدليل. استلمه وكمّله.', style: tx(15, c: K.muted))),
    gap(18),
    Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          pBiz(kind: 'تصوير · صنعاء'),
          gap(12),
          eff(LucideIcons.inbox, 'عندك طلبين من عرسان ينتظرونك', c: K.coral),
          eff(LucideIcons.eye, '38 شافوا ملفك هذا الشهر'),
          eff(LucideIcons.pencil, 'بعد ما تستلمه تعدّل كل شيء فيه'),
        ],
      ),
    ),
    gap(12),
    pGhost('مو أنا، أشتي ملف جديد'),
  ],
);

// ============================================================ الانضمام

Widget p03Business() => pPhone(
  action: pBtn('التالي'),
  children: [
    subHeader('طلب الانضمام'),
    pSteps(_join, 0),
    gap(18),
    Text('نشاطك', style: tx(24, w: bold)),
    gap(12),
    pField('اسم النشاط كما يعرفه الناس', 'استوديو ضوء صنعاء', focused: true),
    gap(10),
    pField('القسم', 'التصوير', icon: LucideIcons.camera),
    gap(16),
    Text('يخدم مين؟', style: tx(15, w: bold)),
    gap(8),
    pOption('الرجال', sub: 'أعراس الرجال: السمرة، والمقيل، والزفة'),
    pOption('النساء', sub: 'حفلات النساء، والنقش، والزفة'),
    pOption('الاثنين', sub: 'عندي فرق للرجال وفرق للنساء', on: true),
    gap(4),
    pNote('القسم واحد للعريس والعروسة. العريس يشوفك عند «المصورين»، والعروسة عند «المصورات» إذا عندك فريق نساء.'),
  ],
);

Widget p04Where() => pPhone(
  action: pBtn('التالي'),
  children: [
    subHeader('طلب الانضمام'),
    pSteps(_join, 1),
    gap(18),
    Text('وين تشتغل؟', style: tx(24, w: bold)),
    gap(12),
    pField('المدينة', 'صنعاء', icon: LucideIcons.mapPin, focused: true),
    gap(12),
    Text('المناطق اللي تغطيها', style: tx(15, w: bold)),
    gap(8),
    Wrap(spacing: 8, runSpacing: 8, children: [
      pChip('كل صنعاء', on: true),
      pChip('همدان'),
      pChip('بني مطر'),
      pChip('سنحان'),
    ]),
    gap(16),
    Box(
      pad: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('تسافر لمحافظة ثانية؟', style: tx(15.5, w: bold)),
                Text('ذمار، إب، الحديدة… تتفق على المواصلات في العرض', style: tx(12.5, c: K.muted)),
              ],
            ),
          ),
          pToggle(true),
        ],
      ),
    ),
    gap(10),
    pField('مكان المحل (اختياري)', 'شارع الزبيري، جنب جولة كنتاكي', icon: LucideIcons.navigation),
  ],
);

Widget p05Work() {
  Widget ph(Color c, {bool add = false, bool face = false}) => Container(
    width: 104,
    height: 104,
    decoration: BoxDecoration(
      color: add ? Colors.white : c,
      borderRadius: BorderRadius.circular(16),
      border: add ? Border.all(color: K.line, width: 2) : null,
    ),
    child: add
        ? const Icon(LucideIcons.plus, color: K.faint, size: 28)
        : Icon(face ? LucideIcons.users : LucideIcons.image, color: Colors.white70, size: 28),
  );
  return pPhone(
    action: pBtn('التالي'),
    children: [
      subHeader('طلب الانضمام'),
      pSteps(_join, 2),
      gap(18),
      Text('وريهم شغلك', style: tx(24, w: bold)),
      Text('3 صور على الأقل. أفضل شغل عندك.', style: tx(15, c: K.muted)),
      gap(14),
      Wrap(spacing: 10, runSpacing: 10, children: [
        ph(const Color(0xFF7D8A80)),
        ph(const Color(0xFF9C8B74)),
        ph(const Color(0xFF6E7F8C)),
        ph(K.line, add: true),
      ]),
      gap(14),
      Box(
        pad: const EdgeInsets.all(14),
        child: Row(
          children: [
            iconTile(LucideIcons.music2, P.c, P.soft, s: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('اربط تيك توك أو إنستغرام', style: tx(15, w: bold)),
                  Text('يظهر كمعرض شغلك، بدون ما ترفع كل شيء', style: tx(12.5, c: K.muted)),
                ],
              ),
            ),
            pSoft('اربط'),
          ],
        ),
      ),
      gap(12),
      pNote('شغل النساء: بدون وجوه. صوّر الكوشة، والزينة، والنقش، والفستان من الخلف. ونراجع كل صورة قبل ما تظهر.',
          c: K.coral, bg: K.coralSoft, i: LucideIcons.eyeOff),
    ],
  );
}

Widget p05bModel() => pPhone(
  action: pBtn('التالي'),
  children: [
    subHeader('طلب الانضمام'),
    pSteps(_join, 3),
    gap(18),
    Text('كيف تشتغل؟', style: tx(24, w: bold)),
    Text('يحدد كيف يشوف العرسان توفرك. تقدر تغيّره بعدين.', style: tx(15, c: K.muted)),
    gap(14),
    pOption('أبيع منتجات', sub: 'ملابس، ماء، حلويات، وجبات. العريس يطلب كمية وموعد تسليم', icon: LucideIcons.shoppingBag),
    pOption('أخدم عرس واحد في الفترة', sub: 'أنا أو فرقتي. فنان، مزمار، برع، منقشة، صالة بقاعة وحدة', icon: LucideIcons.user),
    pOption('أقدر أخدم أكثر من عرس في نفس الوقت', sub: 'عندي فرق أو قاعات أو سيارات. استوديو بأربع فرق، صالة بقاعتين، مكتب سيارات', on: true, icon: LucideIcons.users),
    gap(4),
    pNote('عندك أكثر من نوع؟ مثلًا تصوّر وتبيع ألبومات. كل خدمة تختار طريقتها.'),
  ],
);

/// Model 3: the teams, each with whom it serves and who goes.
Widget p06Units() {
  Widget u(String n, String sub, String serve, Color c) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        iconTile(LucideIcons.camera, c, c.withValues(alpha: 0.12), s: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(n, style: tx(15, w: bold)), Text(sub, style: tx(12.5, c: K.muted))],
          ),
        ),
        tag(serve, c, c.withValues(alpha: 0.12)),
      ],
    ),
  );
  return pPhone(
    action: pBtn('التالي'),
    children: [
      subHeader('طلب الانضمام'),
      pSteps(_join, 4),
      gap(18),
      Text('فرقك وخدماتك', style: tx(24, w: bold)),
      gap(12),
      sectionTitle('فرق التصوير', action: '+ فريق', ac: P.c),
      whiteList([
        u('فريق 1', 'مصوّرين رجال · صور وفيديو', 'رجال', P.c),
        u('فريق 2', 'مصوّرين رجال · صور وفيديو ودرون', 'رجال', P.c),
        u('فريق 3', 'مصوّرين رجال · صور', 'رجال', P.c),
        u('فريق النساء', 'مصوّرات · صور وفيديو', 'نساء', K.coral),
      ]),
      gap(6),
      Text('يعني تقدر تاخذ 4 أعراس في نفس الليلة: 3 للرجال وواحد للنساء.', style: tx(13, c: K.muted)),
      sectionTitle('الباقات', action: '+ باقة', ac: P.c),
      whiteList([
        listRow(icon: LucideIcons.package, fg: P.c, soft: P.soft, title: 'صور فقط', sub: 'الزفاف · 300 صورة معدّلة',
            trailing: Text('350,000', style: tx(14.5, w: bold))),
        listRow(icon: LucideIcons.package, fg: P.c, soft: P.soft, title: 'صور وفيديو', sub: 'الزفاف · فيلم 10 دقايق',
            trailing: Text('550,000', style: tx(14.5, w: bold))),
      ]),
      gap(8),
      Text('الأسعار بريال صنعاء. تقدر تكتب «حسب الطلب».', style: tx(13, c: K.muted)),
    ],
  );
}

/// Model 1: a sales catalogue with sizes and stock.
Widget p06Catalog() {
  Widget it(String n, String sub, String price, {bool out = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Container(width: 52, height: 52, decoration: BoxDecoration(color: const Color(0xFF8C8273), borderRadius: BorderRadius.circular(12)),
            child: const Icon(LucideIcons.shirt, color: Colors.white70)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(n, style: tx(15, w: bold)), Text(sub, style: tx(12.5, c: K.muted))],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(price, style: tx(14.5, w: bold)),
            out ? tag('خلص', K.muted, K.line) : tag('متوفر', K.green, K.greenSoft),
          ],
        ),
      ],
    ),
  );
  return pPhone(
    action: pBtn('التالي'),
    children: [
      subHeader('طلب الانضمام'),
      pSteps(_join, 4),
      gap(18),
      Text('اللي تبيعه', style: tx(24, w: bold)),
      Text('محلات الأناقة · ملابس العرسان', style: tx(15, c: K.muted)),
      gap(12),
      whiteList([
        it('ثوب أبيض', 'المقاسات 52 لين 60 · تفصيل', '35,000'),
        it('كوت شتوي', 'المقاسات 48 لين 56', '60,000'),
        it('شال كشميري', 'مقاس واحد', '25,000'),
        it('عسيب جنبية', 'مطرز', '18,000', out: true),
      ]),
      gap(10),
      pBtn('أضف قطعة', icon: LucideIcons.plus, bg: P.soft, fg: P.c, v: 14, fs: 15),
      gap(12),
      pNote('ما فيه تقويم: العريس يطلب القطع والمقاسات وموعد الاستلام، وأنت تقبل وتجهّزها.', i: LucideIcons.shoppingBag),
    ],
  );
}

Widget p07Submit() => pPhone(
  action: pBtn('أرسل للمراجعة', icon: LucideIcons.send),
  children: [
    subHeader('طلب الانضمام'),
    pSteps(_join, 5),
    gap(18),
    Text('كذا بيشوفك العرسان', style: tx(24, w: bold)),
    gap(12),
    Container(
      clipBehavior: Clip.antiAlias,
      decoration: card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 120, color: const Color(0xFF6E7F8C), child: const Icon(LucideIcons.image, color: Colors.white54, size: 36)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                pBiz(kind: 'تصوير · كل صنعاء · يسافر'),
                gap(10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  tag('للرجال والنساء', P.c, P.soft),
                  tag('فريق مصوّرات', K.coral, K.coralSoft),
                  tag('من 350,000 ر.ي صنعاء', K.green, K.greenSoft),
                ]),
              ],
            ),
          ),
        ],
      ),
    ),
    gap(12),
    Box(
      child: Column(
        children: [
          eff(LucideIcons.checkCircle2, 'نشاطك ومناطقك', c: K.green),
          eff(LucideIcons.checkCircle2, '6 صور', c: K.green),
          eff(LucideIcons.checkCircle2, '4 فرق وباقتين', c: K.green),
          eff(LucideIcons.circle, 'التوثيق: اختياري الآن، يرفع ظهورك', c: K.faint),
        ],
      ),
    ),
    gap(10),
    Text('نراجع خلال يومين عادة. والفريق ممكن يتصل يساعدك.', style: tx(13, c: K.muted)),
  ],
);

// ============================================================ المراجعة

Widget _state({required IconData icon, required Color c, required Color soft, required String title,
    required String sub, required List<Widget> body, Widget? action}) =>
    pPhone(
      action: action,
      children: [
        gap(10),
        pBiz(),
        gap(22),
        Center(child: iconTile(icon, c, soft, s: 78, r: 24)),
        gap(14),
        Center(child: Text(title, textAlign: TextAlign.center, style: tx(24, w: bold))),
        gap(6),
        Center(child: Text(sub, textAlign: TextAlign.center, style: tx(15, c: K.muted, h: 1.5))),
        gap(18),
        ...body,
      ],
    );

Widget p08Pending() => _state(
  icon: LucideIcons.hourglass, c: K.saffronInk, soft: K.saffronSoft,
  title: 'طلبك قيد المراجعة',
  sub: 'أرسلته اليوم 10 الصبح. نرد عليك خلال يومين على واتساب وهنا.',
  action: pGhost('عدّل طلبك', icon: LucideIcons.pencil, fg: P.c),
  body: [
    Box(
      child: Column(
        children: [
          eff(LucideIcons.eyeOff, 'ملفك مخفي عن العرسان لين نوافق'),
          eff(LucideIcons.pencil, 'تقدر تعدّل وتضيف صور وأنت تنتظر'),
          eff(LucideIcons.phone, 'ممكن يتصل بك فريق اعّرست يتأكد من البيانات'),
        ],
      ),
    ),
    gap(10),
    pGhost('شوف ملفك مثل العرسان', icon: LucideIcons.eye, fg: P.c),
  ],
);

Widget p09NeedsChanges() => pPhone(
  action: pBtn('أرسلت التعديل', icon: LucideIcons.send),
  children: [
    subHeader('يحتاج تعديل بسيط'),
    pNote('ملفك قريب. صلّح الملاحظتين تحت وأرسله، ونراجعه أول بأول.', c: K.saffronInk, bg: K.saffronSoft, i: LucideIcons.clipboardCheck),
    gap(14),
    pField('اسم النشاط', 'استوديو ضوء صنعاء'),
    gap(10),
    pField('صور الشغل', '6 صور', note: 'صورتين فيهن وجوه نساء واضحة. شيلهن أو بدّلهن.'),
    gap(10),
    pField('باقة «صور وفيديو»', '550,000', note: 'اكتب ايش تشمل: كم صورة، ومدة الفيلم، والألبوم.'),
    gap(10),
    pField('المناطق', 'كل صنعاء'),
    gap(10),
    Text('الملاحظات من فريق المراجعة · أمس', style: tx(12.5, c: K.muted)),
  ],
);

Widget p10Approved() => _state(
  icon: LucideIcons.partyPopper, c: K.green, soft: K.greenSoft,
  title: 'مبروك، صرت في اعّرست',
  sub: 'العرسان في صنعاء يشوفونك من الآن.',
  action: pBtn('ابدأ'),
  body: [
    sectionTitle('ثلاث خطوات أولى'),
    whiteList([
      listRow(icon: LucideIcons.calendarDays, fg: P.c, soft: P.soft, title: 'حدّث تقويمك', sub: 'الليالي المحجوزة من برا، عشان ما ينحجز يوم مرتين'),
      listRow(icon: LucideIcons.badgeCheck, fg: P.c, soft: P.soft, title: 'وثّق ملفك', sub: 'شارة «موثّق» تزيد الطلبات'),
      listRow(icon: LucideIcons.bell, fg: P.c, soft: P.soft, title: 'شغّل التنبيهات', sub: 'الطلب اللي يتأخر رده يقل ظهورك'),
    ]),
  ],
);

Widget p11Rejected() => _state(
  icon: LucideIcons.fileX, c: K.coral, soft: K.coralSoft,
  title: 'ما قدرنا نوافق الآن',
  sub: 'مو نهاية الطريق. صلّح اللي تحت وقدّم من جديد.',
  action: pBtn('صلّح وقدّم من جديد'),
  body: [
    Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('السبب', style: tx(13, c: K.muted)),
          gap(4),
          Text('الصور مأخوذة من حساب ثاني على إنستغرام. نحتاج صور شغلك أنت.', style: tx(15.5, w: bold, h: 1.5)),
        ],
      ),
    ),
    gap(10),
    pGhost('تكلّم مع الدعم', icon: LucideIcons.messageCircle, fg: P.c),
  ],
);

Widget p12Suspended() => _state(
  icon: LucideIcons.pauseOctagon, c: K.coral, soft: K.coralSoft,
  title: 'حسابك موقوف مؤقتًا',
  sub: 'من أمس. ما توصلك طلبات جديدة لين ينحل الموضوع.',
  action: pBtn('تكلّم مع الدعم', icon: LucideIcons.messageCircle),
  body: [
    Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('السبب', style: tx(13, c: K.muted)),
          Text('3 بلاغات عن تأخير تسليم الصور أكثر من شهرين.', style: tx(15, w: bold, h: 1.5)),
        ],
      ),
    ),
    gap(10),
    Box(
      c: K.greenSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('حجوزاتك المؤكدة مستمرة', style: tx(15, w: bold, c: K.green)),
          Text('5 أعراس جاية. العرسان معتمدين عليك، كمّلها.', style: tx(13.5, c: K.green)),
        ],
      ),
    ),
  ],
);

// ============================================================ الرئيسية

Widget p13Home() => pPhone(
  tab: PTab.home,
  badge: 3,
  children: [
    Row(
      children: [
        Expanded(child: pBiz()),
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: const Icon(LucideIcons.bell, size: 20),
        ),
      ],
    ),
    gap(16),
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: P.c, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ينتظرونك', style: tx(14, c: Colors.white70)),
          Text('3 طلبات ما رديت عليها', style: tx(22, w: bold, c: Colors.white)),
          gap(4),
          Text('أقدمها من أمس · ينتهي بعد 6 أيام', style: tx(13, c: Colors.white70)),
          gap(14),
          btn('ردّ الآن', bg: Colors.white, fg: P.c),
        ],
      ),
    ),
    gap(12),
    Box(
      pad: const EdgeInsets.all(14),
      child: Row(
        children: [
          iconTile(LucideIcons.calendarCheck, K.saffronInk, K.saffronSoft, s: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('محمد قبل عرضك', style: tx(15.5, w: bold)),
                Text('يشتي يحجز الخميس 21 يناير · أكّد اليوم', style: tx(12.5, c: K.muted)),
              ],
            ),
          ),
          pSoft('أكّد', fg: K.saffronInk, bg: K.saffronSoft),
        ],
      ),
    ),
    sectionTitle('هذا الأسبوع', action: 'التقويم', ac: P.c),
    whiteList([
      listRow(icon: LucideIcons.camera, fg: K.green, soft: K.greenSoft, title: 'الأربعاء · السمرة', sub: 'عرس عادل الريمي · فريق 2'),
      listRow(icon: LucideIcons.camera, fg: K.green, soft: K.greenSoft, title: 'الخميس · الزفة', sub: '3 أعراس · فريق 1 و2 و3'),
      listRow(icon: LucideIcons.camera, fg: K.coral, soft: K.coralSoft, title: 'الخميس · حفلة نساء', sub: 'عرس سلمى · فريق النساء'),
    ]),
  ],
);

Widget p14HomeNew() => pPhone(
  tab: PTab.home,
  children: [
    pBiz(),
    gap(18),
    Center(child: iconTile(LucideIcons.sprout, P.c, P.soft, s: 76, r: 24)),
    gap(12),
    Center(child: Text('ما وصلك طلب لسا', style: tx(23, w: bold))),
    gap(4),
    Center(child: Text('طبيعي أول أسبوعين. هذا اللي يخليك تنشاف أكثر:', style: tx(15, c: K.muted))),
    gap(16),
    whiteList([
      listRow(icon: LucideIcons.image, fg: P.c, soft: P.soft, title: 'أضف 6 صور ثانية', sub: 'الملفات اللي فيها 12 صورة تجيها طلبات أكثر', trailing: pSoft('أضف')),
      listRow(icon: LucideIcons.badgeCheck, fg: P.c, soft: P.soft, title: 'وثّق ملفك', sub: 'بالبطاقة أو صورة المحل', trailing: pSoft('وثّق')),
      listRow(icon: LucideIcons.share2, fg: P.c, soft: P.soft, title: 'شارك رابط ملفك', sub: 'في حالة الواتساب وتيك توك', trailing: pSoft('شارك')),
    ]),
    gap(12),
    Box(
      pad: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(LucideIcons.eye, color: K.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text('شاف ملفك 14 عريس هذا الأسبوع', style: tx(14.5, w: bold))),
        ],
      ),
    ),
  ],
);
