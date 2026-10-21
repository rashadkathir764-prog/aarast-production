// Journey prototype v3: the participant, closing what the first pass left
// open. The permission request reaches the owner, the rafd writer has a
// screen of his own, providers can be view-only, the bride's helpers see her
// colours, and the plan's later states reach the participant too.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import 'gaps_a.dart' show gNote, gOption;
import 'lights.dart' show bigHero;

Widget _who(String hello, String plan, String role, String l, Color c) => Padding(
  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(hello, style: tx(24, w: bold)),
            Row(
              children: [
                Text('$plan · ', style: tx(14, c: K.muted)),
                tag(role, K.teal, K.tealSoft),
              ],
            ),
          ],
        ),
      ),
      avatar(l, c, s: 44),
    ],
  ),
);

// ============================================================ طلب صلاحية

/// The owner's side of «اطلب صلاحية»: the request arrives and he answers.
Widget qPermissionRequest() => Phone(
  nav: Sec.home,
  sheet: sheet(
    title: 'صالح يطلب يشوف المال',
    sub: 'من شاشة المال قبل ساعة',
    children: [
      Box(
        pad: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            avatar('ص', K.saffronInk, s: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Text('«أشتي أسجّل اللي أدفعه للغداء عشان ما ننسى»',
                  style: tx(14.5, h: 1.5)),
            ),
          ],
        ),
      ),
      gap(12),
      gOption('يشوف ويسجّل', sub: 'يسجّل الدفعات اللي هو يدفعها. المصادر والسلف تبقى لك', on: true),
      gOption('يشوف بس', sub: 'المجاميع بدون أزرار'),
      gOption('لا، مو الآن', sub: 'توصله رسالة هادية بدون سبب'),
      gap(6),
      btn('تمام', wide: true, v: 16, fs: 17),
    ],
  ),
  children: [gap(20)],
);

/// What the participant sees after asking.
Widget qRequestSent() => Phone(
  nav: Sec.money,
  children: [
    tabHeader(Sec.money.label, 'عرس محمد · أنت مساعد', sec: Sec.money),
    gap(30),
    Center(child: iconTile(LucideIcons.send, K.teal, K.tealSoft, s: 80, r: 26)),
    gap(18),
    Center(child: Text('طلبك وصل محمد', style: tx(23, w: bold))),
    gap(6),
    Center(
      child: Text('أول ما يرد نبلّغك. ما تحتاج تطلب مرة ثانية.',
          textAlign: TextAlign.center, style: tx(15, c: K.muted, h: 1.5)),
    ),
    gap(22),
    Box(
      pad: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(LucideIcons.clock, size: 20, color: K.muted),
          const SizedBox(width: 10),
          Expanded(child: Text('طلبت «يشوف ويسجّل» · قبل ساعة', style: tx(14.5))),
          Text('ألغِ', style: tx(14, w: bold, c: K.coral)),
        ],
      ),
    ),
  ],
);

// ============================================================ كاتب الرفد

/// The rafd writer's whole app on the wedding day: one big button and what he
/// wrote, no totals.
Widget qRafdWriter() => Phone(
  children: [
    _who('أهلًا عبدالله', 'عرس محمد', 'كاتب الرفد', 'ع', K.sky),
    gap(14),
    Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: K.teal, borderRadius: BorderRadius.circular(26)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('اليوم الزفاف', style: tx(14, c: Colors.white70)),
          Text('سجّل الرفد أول بأول', style: tx(22, w: bold, c: Colors.white)),
          gap(16),
          btn('سجّل رفد', wide: true, v: 18, fs: 19, bg: Colors.white, fg: K.teal, icon: LucideIcons.plus),
        ],
      ),
    ),
    sectionTitle('اللي كتبته', action: '23 اسم'),
    whiteList([
      listRow(icon: LucideIcons.user, fg: K.teal, soft: K.tealSoft, title: 'عبدالله الحمدي', sub: 'قبل 5 دقايق',
          trailing: Text('50,000', style: tx(15, w: bold))),
      listRow(icon: LucideIcons.user, fg: K.teal, soft: K.tealSoft, title: 'يحيى السنيدار', sub: 'قبل 12 دقيقة',
          trailing: Text('30,000', style: tx(15, w: bold))),
      listRow(icon: LucideIcons.user, fg: K.teal, soft: K.tealSoft, title: 'أحمد ناجي', sub: 'ينتظر النت',
          trailing: const Icon(LucideIcons.clock, size: 18, color: K.faint)),
    ]),
    gap(12),
    gNote('تشوف اللي كتبته أنت بس، وتقدر تصلّحه لين ينتهي اليوم. المجموع عند محمد.',
        i: LucideIcons.lock),
  ],
);

// ============================================================ المزودين يشوف

Widget qProvidersView() => Phone(
  nav: Sec.providers,
  children: [
    tabHeader(Sec.providers.label, 'عرس محمد · تشوف بس', sec: Sec.providers),
    Box(
      c: K.line,
      pad: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(LucideIcons.eye, size: 18, color: K.muted),
          const SizedBox(width: 8),
          Expanded(child: Text('المواعيد ومين تكلّم يوم العرس. الأسعار والعروض عند محمد.',
              style: tx(13.5, w: bold, c: K.muted))),
        ],
      ),
    ),
    gap(12),
    whiteList([
      listRow(icon: LucideIcons.building2, fg: K.sky, soft: K.skySoft, title: 'قاعة سبأ',
          sub: 'الخميس 21 · بعد المغرب', trailing: tag('محجوز', K.green, K.greenSoft)),
      listRow(icon: LucideIcons.music, fg: K.sky, soft: K.skySoft, title: 'فرقة الأفراح',
          sub: 'الخميس 21 · الزفة بعد العشاء', trailing: tag('محجوز', K.green, K.greenSoft)),
      listRow(icon: LucideIcons.camera, fg: K.sky, soft: K.skySoft, title: 'ضوء صنعاء',
          sub: 'ينتظر تأكيدهم', trailing: tag('ينتظر', K.saffronInk, K.saffronSoft)),
    ]),
    gap(12),
    Box(
      pad: const EdgeInsets.all(14),
      child: Row(
        children: [
          iconTile(LucideIcons.phone, K.sky, K.skySoft, s: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مسؤول القاعة يوم العرس', style: tx(15, w: bold)),
                Text('أبو فهد · محمد شاركه معك', style: tx(12.5, c: K.muted)),
              ],
            ),
          ),
          softAction('اتصل', fg: K.sky, bg: K.skySoft),
        ],
      ),
    ),
  ],
);

// ============================================================ في خطة العروسة

/// A helper in the bride's plan sees her colours and her wording.
Widget qBrideHelper() {
  const rose = Color(0xFFB4536A), roseSoft = Color(0xFFF8E4EA);
  // No tab bar here: the shared bar is drawn in the groom's colour.
  return Phone(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('أهلًا نورة', style: tx(24, w: bold)),
                  Row(
                    children: [
                      Text('عرس سلمى · ', style: tx(14, c: K.muted)),
                      tag('أنتِ مساعدة', rose, roseSoft),
                    ],
                  ),
                ],
              ),
            ),
            avatar('ن', K.saffronInk, s: 44),
          ],
        ),
      ),
      gap(14),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: rose, borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: [
            Text('96', style: tx(46, w: bold, c: Colors.white, h: 1)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('يوم على عرس أختك', style: tx(17, w: bold, c: Colors.white)),
                  Text('الخميس 21 يناير · صالة الياسمين', style: tx(13, c: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
      sectionTitle('مهامك', action: '2'),
      whiteList([
        listRow(icon: LucideIcons.users, fg: K.lilac, soft: K.lilacSoft, title: 'ذكّري بنات العم اللي ما ردّن',
            sub: '6 ضيفات · قبل 1 يناير'),
        listRow(icon: LucideIcons.sparkles, fg: K.saffronInk, soft: K.saffronSoft, title: 'موعد المنقشة',
            sub: 'الأربعاء 20 · بعد العصر'),
      ]),
      gap(12),
      gNote('الخطة بألوان صاحبتها. لو عندك خطة أنتِ، تبدّلين لها من «اختر المسار».',
          c: rose, bg: roseSoft, i: LucideIcons.palette),
    ],
  );
}

// ============================================================ أسبوع العرس ويومه

Widget qWeddingDay() => Phone(
  nav: Sec.home,
  children: [
    _who('أهلًا صالح', 'عرس محمد', 'أنت مساعد', 'ص', K.saffronInk),
    bigHero(day: true, whose: 'عرس أخوك'),
    sectionTitle('عليك اليوم'),
    whiteList([
      listRow(icon: LucideIcons.soup, fg: K.saffronInk, soft: K.saffronSoft, title: 'استلام الغداء من أبو علي',
          sub: 'الظهر · بيت الوالد', trailing: softAction('خلصت')),
      listRow(icon: LucideIcons.car, fg: K.saffronInk, soft: K.saffronSoft, title: 'سيارات الزفة عند القاعة',
          sub: 'بعد العشاء · 4 سيارات'),
    ]),
    sectionTitle('برنامج اليوم'),
    whiteList([
      listRow(icon: LucideIcons.sun, fg: K.teal, soft: K.tealSoft, title: 'البرع', sub: 'الضحى · الحارة'),
      listRow(icon: LucideIcons.leaf, fg: K.teal, soft: K.tealSoft, title: 'المقيل', sub: 'بعد العصر · بيت الوالد'),
      listRow(icon: LucideIcons.partyPopper, fg: K.teal, soft: K.tealSoft, title: 'الزفة', sub: 'بعد العشاء · قاعة سبأ'),
    ]),
  ],
);

// ============================================================ حالات الخطة

Widget qPlanStates() {
  Widget st(IconData i, Color c, Color soft, String t, String s, String? act) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: card(),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        iconTile(i, c, soft, s: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: tx(16.5, w: bold)),
              Text(s, style: tx(13.5, c: K.muted, h: 1.45)),
              if (act != null) ...[gap(10), softAction(act, fg: c, bg: soft)],
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    children: [
      subHeader('عرس محمد', sub: 'لما الخطة تتغير'),
      st(LucideIcons.pauseCircle, K.saffronInk, K.saffronSoft, 'الخطة متوقفة',
          'محمد أوقفها. مهامك وقفت معها، وما يوصلك شيء لين يرجّعها.', null),
      st(LucideIcons.calendarClock, K.sky, K.skySoft, 'العرس تأجل إلى 4 فبراير',
          'مهامك انتقلت معه. شوف ايش تغير عليك.', 'شوف مهامك'),
      st(LucideIcons.archive, K.muted, K.line, 'الخطة في الذكريات',
          'العرس تم الحمد لله. تشوف اللي سويته للقراءة بس.', 'اللي سجّلته'),
      st(LucideIcons.trash2, K.coral, K.coralSoft, 'الخطة انحذفت',
          'محمد حذفها. اللي سجّلته أنت راح معها.', null),
    ],
  );
}

Widget qRemoved() => Phone(
  children: [
    gap(40),
    Center(child: iconTile(LucideIcons.userMinus, K.muted, K.line, s: 80, r: 26)),
    gap(18),
    Center(child: Text('ما عاد عندك وصول لعرس محمد', style: tx(22, w: bold))),
    gap(6),
    Center(
      child: Text('محمد رتّب المشاركين من جديد. شكرًا على مساعدتك.',
          textAlign: TextAlign.center, style: tx(15, c: K.muted, h: 1.5)),
    ),
    gap(20),
    Box(
      child: Column(
        children: [
          Row(children: [
            const Icon(LucideIcons.checkCircle2, size: 18, color: K.green),
            const SizedBox(width: 10),
            Expanded(child: Text('اللي سجّلته يبقى باسمك عنده', style: tx(14.5))),
          ]),
          gap(10),
          Row(children: [
            const Icon(LucideIcons.listChecks, size: 18, color: K.muted),
            const SizedBox(width: 10),
            Expanded(child: Text('مهامك الثلاث رجعت لمحمد', style: tx(14.5))),
          ]),
        ],
      ),
    ),
    gap(20),
    btn('ابدأ خطة عرسك', wide: true, v: 15, bg: K.tealSoft, fg: K.teal),
    gap(10),
    btn('خططي الثانية', wide: true, v: 15, bg: K.surface, fg: K.muted),
  ],
);

Widget qNotifications() {
  Widget n(IconData i, Color c, Color soft, String t, String s, {bool unread = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        iconTile(i, c, soft, s: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(t, style: tx(15, w: bold)), Text(s, style: tx(12.5, c: K.muted))],
          ),
        ),
        if (unread) dot(K.teal, 9),
      ],
    ),
  );
  return Phone(
    children: [
      subHeader('التنبيهات', sub: 'من عرس محمد'),
      whiteList([
        n(LucideIcons.listChecks, K.saffronInk, K.saffronSoft, 'محمد عطاك مهمة', 'رتّب سيارات الزفة · قبل 15 يناير', unread: true),
        n(LucideIcons.wallet, K.teal, K.tealSoft, 'صرت تشوف المال وتسجّل', 'محمد وافق على طلبك', unread: true),
        n(LucideIcons.bell, K.lilac, K.lilacSoft, 'مهمتك بكرة', 'ذكّر آل الحمدي اللي ما ردّوا'),
        n(LucideIcons.calendarClock, K.sky, K.skySoft, 'العرس تأجل', 'صار 4 فبراير، ومهامك انتقلت معه'),
      ]),
      gap(12),
      gNote('توصلك بس الأشياء اللي تخصك. ومبالغ ما تطلع على شاشة القفل.', i: LucideIcons.bellRing),
    ],
  );
}
