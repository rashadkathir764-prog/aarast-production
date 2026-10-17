// Journey prototype: tasks, guests, providers, and the family page.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'kit.dart';

Widget _avatar(String l, Color c, {double s = 28}) => Container(
  width: s,
  height: s,
  alignment: Alignment.center,
  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  child: Text(
    l,
    style: tx(s * 0.45, w: bold, c: Colors.white),
  ),
);

// ================================================================ المهام

Widget _task(
  String title,
  String meta,
  String who,
  Color whoC, {
  String? link,
  Color linkFg = K.sky,
  Color linkBg = K.skySoft,
  bool late = false,
  bool done = false,
}) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? K.green : Colors.transparent,
          border: Border.all(
            color: done ? K.green : (late ? K.coral : K.line),
            width: 2,
          ),
        ),
        child: done
            ? const Icon(LucideIcons.check, size: 15, color: Colors.white)
            : null,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: tx(15.5, w: bold, c: done ? K.faint : K.ink),
            ),
            Text(
              meta,
              style: tx(
                12.5,
                w: late ? bold : FontWeight.w400,
                c: late ? K.coral : K.muted,
              ),
            ),
            if (link != null) ...[
              gap(8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: linkBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      link,
                      style: tx(13, w: bold, c: linkFg),
                    ),
                    const SizedBox(width: 4),
                    Icon(LucideIcons.arrowLeft, size: 14, color: linkFg),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      _avatar(who, whoC),
    ],
  ),
);

Widget _group(
  String title,
  String count,
  List<Widget> rows, {
  Color c = K.ink,
}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
      child: Row(
        children: [
          Text(
            title,
            style: tx(16, w: bold, c: c),
          ),
          const SizedBox(width: 8),
          Text(count, style: tx(14, c: K.muted)),
        ],
      ),
    ),
    whiteList(rows),
  ],
);

Widget tasks() => Phone(
  nav: Sec.tasks,
  children: [
    tabHeader(
      'المهام',
      'باقي 3 هذا الأسبوع، وواحدة متأخرة',
      actions: [LucideIcons.share2, LucideIcons.plus],
    ),
    Row(
      children: [
        chip('الكل', on: true, onBg: K.saffronInk),
        const SizedBox(width: 8),
        chip('لي'),
        const SizedBox(width: 8),
        chip('لسلمى'),
        const SizedBox(width: 8),
        chip('للأهل'),
        const Spacer(),
        Text(
          '12 من 30',
          style: tx(14, w: bold, c: K.saffronInk),
        ),
      ],
    ),
    gap(4),
    _group('متأخرة', '1', [
      _task(
        'احجز الكوشة والزينة',
        'كان موعدها 12 أكتوبر',
        'م',
        K.teal,
        late: true,
        link: 'شوف الكوشات',
      ),
    ], c: K.coral),
    _group('هذا الأسبوع', '3', [
      _task(
        'اختر المصور',
        'السبت · وصلك عرضين',
        'م',
        K.teal,
        link: 'قارن العروض',
      ),
      _task(
        'ادفع دفعة القاعة',
        'الخميس · 500 ألف',
        'م',
        K.teal,
        link: 'سجّل الدفعة',
        linkFg: K.teal,
        linkBg: K.tealSoft,
      ),
      _task('اختيار فستان الحناء', 'الجمعة', 'س', K.lilac),
    ]),
    _group('هذا الشهر', '4', [
      _task(
        'ارسل الدعوات',
        'قبل 30 أكتوبر',
        'م',
        K.teal,
        link: 'افتح الضيوف',
        linkFg: K.lilac,
        linkBg: K.lilacSoft,
      ),
      _task(
        'احجز الفرقة',
        'قبل 15 نوفمبر',
        'ص',
        K.saffronInk,
        link: 'ابحث عن فرقة',
      ),
      _task('استلم الذهب', '15 نوفمبر', 'م', K.teal),
    ]),
    gap(12),
    Box(
      pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          iconTile(
            LucideIcons.checkCircle2,
            K.green,
            K.greenSoft,
            s: 36,
            r: 12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('خلصت 12 مهمة', style: tx(15, w: bold)),
          ),
          Text(
            'عرض',
            style: tx(14, w: bold, c: K.saffronInk),
          ),
        ],
      ),
    ),
  ],
);

Widget addTaskSheet() => Phone(
  nav: Sec.tasks,
  sheet: sheet(
    title: 'مهمة جديدة',
    children: [
      field('وش المهمة؟', 'تذوّق كيكة العرس', focused: true),
      gap(16),
      Text(
        'متى؟',
        style: tx(14, w: bold, c: K.muted),
      ),
      gap(8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('هذا الأسبوع'),
          chip('هذا الشهر', on: true, onBg: K.saffronInk),
          chip('قبل العرس بأسبوع'),
          chip('تاريخ', icon: LucideIcons.calendarDays),
        ],
      ),
      gap(16),
      Text(
        'لمين؟',
        style: tx(14, w: bold, c: K.muted),
      ),
      gap(8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('أنا', on: true, onBg: K.saffronInk),
          chip('سلمى'),
          chip('صالح أخوي'),
          chip('شخص ثاني', icon: LucideIcons.plus),
        ],
      ),
      gap(16),
      Row(
        children: [
          const Icon(LucideIcons.lock, size: 17, color: K.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text('خاصة بي (ما تشوفها سلمى)', style: tx(15, c: K.muted)),
          ),
          Container(
            width: 46,
            height: 28,
            padding: const EdgeInsets.all(3),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: K.line,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
      gap(18),
      btn('حفظ المهمة', wide: true, v: 16, fs: 17, bg: K.saffronInk),
    ],
  ),
  children: [tabHeader('المهام', 'باقي 3 هذا الأسبوع، وواحدة متأخرة')],
);

// ================================================================ الضيوف

Widget guests() {
  Widget groupRow(String name, int all, int yes, int wait, Color c) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(name, style: tx(16, w: bold)),
            ),
            Text('$all', style: tx(16, w: bold)),
            Text('  مدعو', style: tx(13, c: K.muted)),
          ],
        ),
        gap(8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 7,
            child: Row(
              children: [
                Expanded(
                  flex: yes,
                  child: Container(color: K.lilac),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: wait,
                  child: Container(color: K.saffron),
                ),
                const SizedBox(width: 2),
                Expanded(
                  flex: all - yes - wait,
                  child: Container(color: K.line),
                ),
              ],
            ),
          ),
        ),
        gap(6),
        Row(
          children: [
            Text(
              'أكد $yes',
              style: tx(12.5, w: bold, c: K.lilac),
            ),
            const SizedBox(width: 12),
            Text(
              'ما رد $wait',
              style: tx(12.5, w: bold, c: K.saffronInk),
            ),
            const SizedBox(width: 12),
            Text('اعتذر ${all - yes - wait}', style: tx(12.5, c: K.muted)),
          ],
        ),
      ],
    ),
  );
  Widget person(String n, String side, String status, Color fg, Color bg) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            _avatar(n.characters.first, K.lilac.withValues(alpha: 0.75), s: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n, style: tx(15.5, w: bold)),
                  Text(side, style: tx(12.5, c: K.muted)),
                ],
              ),
            ),
            tag(status, fg, bg),
          ],
        ),
      );
  return Phone(
    nav: Sec.guests,
    children: [
      tabHeader(
        'الضيوف',
        '124 مدعو · 86 أكدوا · 20 ما ردّوا',
        actions: [LucideIcons.search, LucideIcons.plus],
      ),
      nextCard(
        eyebrow: 'الخطوة الجاية',
        title: '20 ضيف ما ردّوا',
        sub: 'نرسل لهم تذكير على واتساب برابط الرد',
        action: 'ذكّرهم الآن',
        why: 'القاعة تحتاج العدد النهائي قبل العرس بشهر',
        icon: LucideIcons.send,
        fg: K.lilac,
        soft: K.lilacSoft,
        actionBg: K.lilac,
      ),
      gap(12),
      Box(
        c: K.lilacSoft,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('المقاعد المتوقعة', style: tx(14, c: K.muted)),
                  Text('104 من 150', style: tx(24, w: bold)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'سعة قاعة سبأ 150',
                  style: tx(13.5, w: bold, c: K.lilac),
                ),
                Text('باقي 46 مقعد', style: tx(13, c: K.muted)),
              ],
            ),
          ],
        ),
      ),
      sectionTitle('حسب الأهل', ac: K.lilac, action: 'المجموعات'),
      whiteList([
        groupRow('أهل العريس', 52, 40, 8, K.lilac),
        groupRow('أهل العروسة', 44, 30, 8, K.lilac),
        groupRow('الأصحاب', 28, 16, 4, K.lilac),
      ]),
      sectionTitle('آخر الردود', ac: K.lilac, action: 'الكل'),
      whiteList([
        person(
          'عبدالله الحمدي',
          'أهل العريس · قبل ساعة',
          'أكد',
          K.lilac,
          K.lilacSoft,
        ),
        person(
          'فاطمة السقاف',
          'أهل العروسة · أمس',
          'أكدت',
          K.lilac,
          K.lilacSoft,
        ),
        person('ياسر الأهدل', 'الأصحاب · أمس', 'اعتذر', K.muted, K.bg),
      ], dividers: false),
    ],
  );
}

Widget contactsPicker() {
  Widget c(String n, String p, bool on) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    child: Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: on ? K.lilac : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: on ? K.lilac : K.line, width: 2),
          ),
          child: on
              ? const Icon(LucideIcons.check, size: 15, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 12),
        _avatar(n.characters.first, on ? K.lilac : K.faint, s: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n, style: tx(15.5, w: bold)),
              Text(p, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      child: btn(
        'أضف 12 ضيف إلى أهل العريس',
        wide: true,
        v: 16,
        fs: 17,
        bg: K.lilac,
      ),
    ),
    children: [
      subHeader('من جهات الاتصال', sub: 'اختر كثير مرة وحدة'),
      field('ابحث', 'آل الحمدي', icon: LucideIcons.search),
      gap(12),
      Row(
        children: [
          Text('يضافون إلى:', style: tx(14, c: K.muted)),
          const SizedBox(width: 8),
          chip('أهل العريس', on: true, onBg: K.lilac),
          const SizedBox(width: 8),
          chip('أهل العروسة'),
        ],
      ),
      gap(12),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          children: [
            Text(
              'اخترت 12',
              style: tx(15, w: bold, c: K.lilac),
            ),
            const Spacer(),
            Text(
              'اختر الكل',
              style: tx(14, w: bold, c: K.lilac),
            ),
          ],
        ),
      ),
      gap(8),
      whiteList([
        c('أحمد الحمدي', ltr('777 210 334'), true),
        c('علي الحمدي', ltr('771 908 120'), true),
        c('عبدالله الحمدي', ltr('733 455 001'), true),
        c('محمد الحمدي (عمي)', ltr('777 004 556'), true),
        c('هاني الحمدي', ltr('770 112 889'), false),
        c('ياسين الحمدي', ltr('735 660 210'), true),
      ], dividers: false),
    ],
  );
}

Widget inviteCard() => Phone(
  bg: const Color(0xFFE9EEEC),
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
    child: Column(
      children: [
        btn(
          'أرسلها على واتساب لـ 124 ضيف',
          wide: true,
          v: 16,
          fs: 17,
          bg: K.green,
          icon: LucideIcons.send,
        ),
        gap(10),
        Text(
          'كل ضيف يوصله رابط خاص يرد منه بضغطة',
          style: tx(13.5, c: K.muted),
        ),
      ],
    ),
  ),
  children: [
    subHeader('بطاقة الدعوة', sub: 'بدون صور، باسمكم وموعدكم'),
    gap(4),
    Container(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [K.tealDark, K.teal],
        ),
      ),
      child: Column(
        children: [
          Text('بكل الحب والسرور', style: tx(15, c: Colors.white70)),
          gap(6),
          Text('ندعوكم لحضور حفل زفاف', style: tx(17, c: Colors.white)),
          gap(18),
          Text(
            'محمد',
            style: tx(40, w: bold, c: Colors.white, h: 1.1),
          ),
          Text('و', style: tx(22, c: K.saffron)),
          Text(
            'سلمى',
            style: tx(40, w: bold, c: Colors.white, h: 1.1),
          ),
          gap(20),
          Container(height: 1, color: Colors.white24),
          gap(16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text('الخميس', style: tx(13, c: Colors.white70)),
                  Text(
                    '21 يناير',
                    style: tx(17, w: bold, c: Colors.white),
                  ),
                ],
              ),
              Column(
                children: [
                  Text('الساعة', style: tx(13, c: Colors.white70)),
                  Text(
                    '7 مساءً',
                    style: tx(17, w: bold, c: Colors.white),
                  ),
                ],
              ),
              Column(
                children: [
                  Text('المكان', style: tx(13, c: Colors.white70)),
                  Text(
                    'قاعة سبأ',
                    style: tx(17, w: bold, c: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          gap(22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            decoration: BoxDecoration(
              color: K.saffron,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text('أكّد حضورك', style: tx(16, w: bold)),
          ),
          gap(14),
          wordmark(s: 16, c: Colors.white54),
        ],
      ),
    ),
    gap(14),
    Row(
      children: [
        Expanded(child: chip('رجال ونساء', on: true)),
        const SizedBox(width: 8),
        Expanded(child: chip('رجال')),
        const SizedBox(width: 8),
        Expanded(child: chip('نساء')),
      ],
    ),
  ],
);

// ================================================================ المزودين

const provTabs = ['طلباتي', 'استكشف', 'المحادثات', 'المفضلة'];

Widget _stage(int at) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    for (var i = 0; i < 3; i++) ...[
      Container(
        width: 22,
        height: 5,
        decoration: BoxDecoration(
          color: i < at ? K.sky : K.line,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      if (i < 2) const SizedBox(width: 3),
    ],
  ],
);

Widget providersRequests() {
  Widget svc(IconData i, String name, String who, int stage, Widget trailing) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            iconTile(i, K.sky, K.skySoft, s: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: tx(15.5, w: bold)),
                  Text(who, style: tx(12.5, c: K.muted)),
                  gap(6),
                  _stage(stage),
                ],
              ),
            ),
            trailing,
          ],
        ),
      );
  return Phone(
    nav: Sec.providers,
    children: [
      tabHeader(
        'المزودين',
        'محجوز 3 من 7 · عرضين ينتظرونك',
        actions: [LucideIcons.search],
      ),
      topTabs(provTabs, 0, c: K.sky),
      gap(14),
      nextCard(
        eyebrow: 'الخطوة الجاية',
        title: 'التصوير: وصلك عرضين',
        sub: 'ضوء صنعاء 550 ألف · عدسة سبأ 480 ألف',
        action: 'قارن واختر',
        why: 'العرضين ينتهون بعد 6 أيام',
        icon: LucideIcons.camera,
        fg: K.sky,
        soft: K.skySoft,
        actionBg: K.sky,
      ),
      gap(6),
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 14, 6, 10),
        child: Row(
          children: [
            Expanded(
              child: Text('خدمات عرسك', style: tx(17, w: bold)),
            ),
            Text('طلب · عرض · محجوز', style: tx(13, c: K.muted)),
          ],
        ),
      ),
      whiteList([
        svc(
          LucideIcons.building2,
          'القاعة',
          'قاعة سبأ · 2 مليون',
          3,
          tag('محجوز', K.green, K.greenSoft),
        ),
        svc(
          LucideIcons.utensils,
          'الضيافة',
          'ضيافة الأصالة · 1.2 مليون',
          3,
          tag('محجوز', K.green, K.greenSoft),
        ),
        svc(
          LucideIcons.gem,
          'الذهب',
          'مجوهرات الحمدي · خارج اعّرست',
          3,
          tag('محجوز', K.green, K.greenSoft),
        ),
        svc(
          LucideIcons.camera,
          'التصوير',
          'عرضين وصلوا',
          2,
          softAction('قارن', fg: K.sky, bg: K.skySoft),
        ),
        svc(
          LucideIcons.sparkles,
          'الكوشة والزينة',
          'طلب لـ 2 · ينتظر الرد',
          1,
          tag('بعد يومين', K.muted, K.bg),
        ),
        svc(
          LucideIcons.music,
          'الفرقة',
          'ما بدأت',
          0,
          softAction('ابحث', fg: K.sky, bg: K.skySoft),
        ),
        svc(
          LucideIcons.shirt,
          'الكسوة',
          'ما بدأت',
          0,
          softAction('ابحث', fg: K.sky, bg: K.skySoft),
        ),
      ]),
    ],
  );
}

Widget _photo(
  List<Color> colors,
  IconData i, {
  double h = 120,
  double r = 18,
}) => Container(
  height: h,
  width: double.infinity,
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(r),
    gradient: LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: colors,
    ),
  ),
  child: Icon(i, size: h * 0.32, color: Colors.white.withValues(alpha: 0.55)),
);

Widget providersExplore() {
  Widget pcard(
    String name,
    String area,
    String rating,
    String price,
    List<Color> cs,
    IconData i, {
    bool verified = false,
    bool fit = false,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: card(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            _photo(cs, i, h: 130, r: 22),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.heart, size: 18, color: K.ink),
              ),
            ),
            if (fit)
              Positioned(
                top: 12,
                right: 12,
                child: tag('ضمن ميزانيتك', K.green, K.greenSoft),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name, style: tx(17, w: bold)),
                  ),
                  const Icon(LucideIcons.star, size: 15, color: K.saffron),
                  Text(' $rating', style: tx(14, w: bold)),
                ],
              ),
              Row(
                children: [
                  Text(area, style: tx(13, c: K.muted)),
                  if (verified) ...[
                    const SizedBox(width: 8),
                    const Icon(LucideIcons.badgeCheck, size: 15, color: K.sky),
                    Text(
                      ' موثّق',
                      style: tx(12.5, w: bold, c: K.sky),
                    ),
                  ],
                ],
              ),
              gap(6),
              Text(
                price,
                style: tx(15, w: bold, c: K.sky),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    nav: Sec.providers,
    children: [
      tabHeader(
        'المزودين',
        'محجوز 3 من 7 · عرضين ينتظرونك',
        actions: [LucideIcons.search],
      ),
      topTabs(provTabs, 1, c: K.sky),
      gap(14),
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            chip('الفرق', on: true, onBg: K.sky, icon: LucideIcons.music),
            const SizedBox(width: 8),
            chip('التصوير', icon: LucideIcons.camera),
            const SizedBox(width: 8),
            chip('الكوشة', icon: LucideIcons.sparkles),
            const SizedBox(width: 8),
            chip('الكسوة', icon: LucideIcons.shirt),
          ],
        ),
      ),
      gap(12),
      Box(
        c: K.skySoft,
        pad: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(LucideIcons.sparkles, size: 18, color: K.sky),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'فرق في صنعاء قريبة من بندك 400 ألف، وفاضية يوم 21 يناير',
                style: tx(14, w: bold, c: K.sky),
              ),
            ),
          ],
        ),
      ),
      gap(12),
      pcard(
        'فرقة الأفراح',
        'صنعاء · حدة',
        '4.9 (88)',
        '350 - 450 ألف ر.ي',
        const [Color(0xFF2F6E9E), Color(0xFF6A4FA3)],
        LucideIcons.music,
        verified: true,
        fit: true,
      ),
      pcard(
        'الفنان أيمن الآنسي',
        'صنعاء · الأصبحي',
        '4.7 (41)',
        '500 - 700 ألف ر.ي',
        const [Color(0xFF0B6E69), Color(0xFF2F6E9E)],
        LucideIcons.mic,
      ),
    ],
  );
}

Widget providerPage() => Phone(
  pad: false,
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
    child: Row(
      children: [
        Expanded(child: btn('اطلب عرض سعر', bg: K.sky, v: 16, fs: 17)),
        const SizedBox(width: 10),
        btn(
          'واتساب',
          bg: K.greenSoft,
          fg: K.green,
          v: 16,
          fs: 16,
          icon: LucideIcons.messageCircle,
        ),
      ],
    ),
  ),
  children: [
    Stack(
      children: [
        _photo(
          const [Color(0xFF2F6E9E), Color(0xFF13211F)],
          LucideIcons.camera,
          h: 230,
          r: 0,
        ),
        Positioned(
          top: 12,
          right: 16,
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.arrowRight, size: 20, color: K.ink),
          ),
        ),
        Positioned(
          top: 12,
          left: 16,
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.heart, size: 20, color: K.coral),
          ),
        ),
        Positioned(
          bottom: 14,
          left: 16,
          child: tag('1 / 24 صورة', Colors.white, Colors.black45),
        ),
      ],
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('استوديو ضوء صنعاء', style: tx(24, w: bold)),
              ),
              const Icon(LucideIcons.badgeCheck, color: K.sky, size: 22),
            ],
          ),
          Row(
            children: [
              const Icon(LucideIcons.star, size: 16, color: K.saffron),
              Text(' 4.8', style: tx(15, w: bold)),
              Text(' (63 تقييم) · صنعاء، حدة', style: tx(14, c: K.muted)),
            ],
          ),
          gap(14),
          Box(
            c: K.skySoft,
            pad: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('عرسان دفعوا فعلًا', style: tx(13, c: K.muted)),
                      Text(
                        '450 - 600 ألف ر.ي',
                        style: tx(19, w: bold, c: K.sky),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.checkCircle2,
                      size: 16,
                      color: K.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'ضمن بندك',
                      style: tx(14, w: bold, c: K.green),
                    ),
                  ],
                ),
              ],
            ),
          ),
          sectionTitle('الباقات', ac: K.sky),
          whiteList([
            listRow(
              icon: LucideIcons.camera,
              fg: K.sky,
              soft: K.skySoft,
              title: 'صور فقط',
              sub: 'مصور واحد · 300 صورة',
              trailing: Text('350 ألف', style: tx(15, w: bold)),
            ),
            listRow(
              icon: LucideIcons.video,
              fg: K.sky,
              soft: K.skySoft,
              title: 'صور وفيديو',
              sub: 'مصورين · فيلم 10 دقائق · ألبوم',
              trailing: Text('550 ألف', style: tx(15, w: bold)),
            ),
          ]),
          sectionTitle('من التقييمات', ac: K.sky),
          Box(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('عمار · تزوج في سبتمبر', style: tx(14, w: bold)),
                    const Spacer(),
                    const Icon(LucideIcons.star, size: 14, color: K.saffron),
                    Text(' 5', style: tx(14, w: bold)),
                  ],
                ),
                gap(4),
                Text(
                  'التزموا بالموعد، والفيلم وصل بعد أسبوعين بالضبط.',
                  style: tx(14.5, c: K.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ],
);

Widget compareOffers() {
  Widget col(
    String name,
    String price,
    List<(String, bool)> incl,
    String rating,
    String pay, {
    bool best = false,
  }) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: card(border: best ? K.sky : null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (best) ...[tag('أنسب لك', K.sky, K.skySoft), gap(8)],
          Text(name, style: tx(15.5, w: bold)),
          gap(10),
          Text(price, style: tx(22, w: bold)),
          Text('ر.ي', style: tx(12.5, c: K.muted)),
          gap(12),
          for (final r in incl)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    r.$2 ? LucideIcons.check : LucideIcons.x,
                    size: 16,
                    color: r.$2 ? K.green : K.faint,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      r.$1,
                      style: tx(13.5, c: r.$2 ? K.ink : K.faint),
                    ),
                  ),
                ],
              ),
            ),
          gap(6),
          Row(
            children: [
              const Icon(LucideIcons.star, size: 14, color: K.saffron),
              Text(' $rating', style: tx(13.5, w: bold)),
            ],
          ),
          Text(pay, style: tx(12.5, c: K.muted)),
          gap(14),
          btn(
            'اختر هذا',
            bg: best ? K.sky : K.skySoft,
            fg: best ? Colors.white : K.sky,
            wide: true,
            v: 11,
          ),
        ],
      ),
    ),
  );
  return Phone(
    children: [
      subHeader('قارن عروض التصوير', sub: 'بندك 600 ألف · الموعد 21 يناير'),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          col(
            'ضوء صنعاء',
            '550 ألف',
            const [
              ('مصورين اثنين', true),
              ('فيلم 10 دقائق', true),
              ('ألبوم مطبوع', true),
              ('تصوير جوي', false),
            ],
            '4.8 (63)',
            'عربون 30%، والباقي يوم العرس',
            best: true,
          ),
          const SizedBox(width: 10),
          col(
            'عدسة سبأ',
            '480 ألف',
            const [
              ('مصور واحد', true),
              ('فيلم 5 دقائق', true),
              ('ألبوم مطبوع', false),
              ('تصوير جوي', false),
            ],
            '4.5 (29)',
            'نصف المبلغ مقدم',
          ),
        ],
      ),
      gap(14),
      Box(
        c: K.tealSoft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.wallet, color: K.teal, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'لما تختار، يصير العرض بند في المال بجدول دفعاته، وتنقفل باقي الطلبات بلطف.',
                style: tx(14.5, c: K.tealDark),
              ),
            ),
          ],
        ),
      ),
      gap(10),
      Box(
        child: Row(
          children: [
            const Icon(LucideIcons.messageCircle, color: K.sky, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('عندك سؤال قبل ما تختار؟', style: tx(15, w: bold)),
            ),
            Text(
              'اسألهم',
              style: tx(14, w: bold, c: K.sky),
            ),
          ],
        ),
      ),
    ],
  );
}

// ================================================================ عائلتي

Widget family() {
  Widget member(
    String n,
    String rel,
    String can,
    Color c, {
    bool pending = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        _avatar(n.characters.first, c, s: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(n, style: tx(15.5, w: bold)),
                  const SizedBox(width: 8),
                  Text(rel, style: tx(13, c: K.muted)),
                ],
              ),
              Text(
                can,
                style: tx(
                  13,
                  w: pending ? bold : FontWeight.w400,
                  c: pending ? K.saffronInk : K.muted,
                ),
              ),
            ],
          ),
        ),
        const Icon(LucideIcons.chevronLeft, color: K.faint, size: 18),
      ],
    ),
  );
  Widget role(String t, String s, IconData i, {bool on = false}) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: card(r: 18, border: on ? K.teal : null),
    child: Row(
      children: [
        Icon(i, color: on ? K.teal : K.muted, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: tx(15.5, w: bold)),
              Text(s, style: tx(13, c: K.muted)),
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    children: [
      subHeader('عائلتي', sub: 'مين يشاركك عرسك'),
      whiteList([
        member(
          'سلمى',
          'العروسة',
          'تشوف كل شيء وتعدّل · المال المشترك فقط',
          K.lilac,
        ),
        member(
          'صالح',
          'أخوي',
          'يساعد في المهام والضيوف · بدون المال',
          K.saffronInk,
        ),
        member('الوالد', '', 'يشوف ملخص المال كل شهر', K.teal),
        member(
          'أم محمد',
          'الوالدة',
          'الدعوة وصلت · ما ردت بعد',
          K.faint,
          pending: true,
        ),
      ]),
      sectionTitle('أضف واحد', action: 'من جهات الاتصال'),
      role('يشوف ويعدّل كل شيء', 'للعروسة أو أقرب شخص', LucideIcons.users),
      role(
        'يساعد بدون المال',
        'المهام والضيوف والمزودين',
        LucideIcons.listChecks,
        on: true,
      ),
      role('يشوف بس', 'ملخص بدون تفاصيل الفلوس', LucideIcons.eye),
      gap(6),
      Box(
        c: K.tealSoft,
        child: Row(
          children: [
            const Icon(LucideIcons.lock, color: K.teal, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'فلوسك خاصة، ما يشوفها أحد إلا اللي تسمح له.',
                style: tx(14, c: K.tealDark),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
