// Journey prototype v3: the participant. Someone the groom or the bride adds
// to their plan. They see the same plan screens, in the owner's colours,
// limited by their permissions. Entry follows the app's invite flow: phone,
// account and code, then the invite decision.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import 'home.dart' show nextStep;

Widget _steps(int at) {
  const labels = ['رقم الهاتف', 'التحقق', 'الدعوة'];
  return Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: K.line),
    ),
    child: Row(
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: i == at ? K.teal : (i < at ? K.tealSoft : Colors.transparent),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                labels[i],
                style: tx(13, w: bold, c: i == at ? Colors.white : (i < at ? K.teal : K.muted)),
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _inviter() => Box(
  pad: const EdgeInsets.all(14),
  child: Row(
    children: [
      avatar('م', K.teal, s: 46),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('محمد يشتيك معه في عرسه', style: tx(16, w: bold)),
            Text('الخميس 21 يناير · صنعاء', style: tx(13, c: K.muted)),
          ],
        ),
      ),
    ],
  ),
);

/// Locked section: shown in place of a tab the participant cannot open.
Widget _locked(Sec sec, String title, String why, String ask) => Phone(
  nav: sec,
  children: [
    tabHeader(sec.label, 'عرس محمد · أنت مساعد', sec: sec),
    gap(30),
    Center(child: iconTile(LucideIcons.lock, sec.color, sec.soft, s: 80, r: 26)),
    gap(18),
    Center(child: Text(title, style: tx(23, w: bold))),
    gap(6),
    Center(
      child: Text(why, textAlign: TextAlign.center, style: tx(15, c: K.muted, h: 1.5)),
    ),
    gap(22),
    Center(child: btn(ask, bg: sec.soft, fg: sec.color, icon: LucideIcons.messageCircle)),
  ],
);

// ============================================================ الدخول

Widget qPhone() => Phone(
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
    child: btn('إرسال رمز التحقق', wide: true, v: 16, fs: 17, icon: LucideIcons.send),
  ),
  children: [
    subHeader('دعوة للمشاركة'),
    _steps(0),
    gap(16),
    _inviter(),
    gap(16),
    field('رقم الهاتف', ltr('771 554 220'), icon: LucideIcons.phone, focused: true),
    gap(8),
    Text('نفس الرقم اللي وصلته الدعوة عليه.', style: tx(13, c: K.muted)),
  ],
);

Widget qAccount() => Phone(
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
    child: btn('متابعة إلى رمز التحقق', wide: true, v: 16, fs: 17),
  ),
  children: [
    subHeader('حسابك في اعّرست'),
    _steps(1),
    gap(16),
    Text('أول مرة تدخل؟ نسوي لك حساب، وتقدر بعدين تبدأ خطتك أنت كمان.',
        style: tx(14.5, c: K.muted, h: 1.5)),
    gap(14),
    field('اسمك', 'صالح الحمدي', focused: true),
    gap(10),
    field('كلمة المرور', '••••••••', icon: LucideIcons.lock),
    gap(10),
    field('تأكيد كلمة المرور', '••••••••', icon: LucideIcons.lock),
  ],
);

Widget qDecision() {
  Widget perm(IconData i, String s, bool on) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(i, size: 19, color: on ? K.teal : K.faint),
        const SizedBox(width: 12),
        Expanded(child: Text(s, style: tx(15, c: on ? K.ink : K.faint))),
        Icon(on ? LucideIcons.check : LucideIcons.x, size: 18, color: on ? K.green : K.faint),
      ],
    ),
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: Row(
        children: [
          Expanded(child: btn('قبول والانضمام', v: 16, fs: 16.5)),
          const SizedBox(width: 10),
          btn('رفض الدعوة', bg: K.bg, fg: K.muted, v: 16, fs: 15),
        ],
      ),
    ),
    children: [
      subHeader('الدعوة'),
      _steps(2),
      gap(16),
      _inviter(),
      sectionTitle('دورك: مساعد'),
      Box(
        child: Column(
          children: [
            perm(LucideIcons.calendarDays, 'الموعد والبرنامج', true),
            perm(LucideIcons.listChecks, 'المهام: تشوف وتخلّص', true),
            perm(LucideIcons.users, 'الضيوف: تضيف وترتب', true),
            perm(LucideIcons.gem, 'تكتب الرفد يوم العرس', true),
            perm(LucideIcons.wallet, 'المال', false),
            perm(LucideIcons.store, 'المزودين', false),
          ],
        ),
      ),
      gap(12),
      Text('محمد يقدر يغيّرها، وأنت تقدر تطلع من الخطة متى ما تشتي.',
          style: tx(13.5, c: K.muted)),
    ],
  );
}

/// More than one role on the same phone: own plan, someone else's, provider.
Widget qChoosePath() {
  Widget ctx(Color c, String l, String t, String sub, String role, {bool on = false}) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: on ? K.teal : K.line, width: on ? 2 : 1),
    ),
    child: Row(
      children: [
        avatar(l, c, s: 46),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: tx(16.5, w: bold)),
              Text(sub, style: tx(13, c: K.muted)),
            ],
          ),
        ),
        tag(role, c, c.withValues(alpha: 0.12)),
      ],
    ),
  );
  return Phone(
    children: [
      gap(14),
      Center(child: wordmark(s: 26)),
      gap(20),
      Text('اختر المسار', style: tx(28, w: bold)),
      Text('ايش تفتح الآن؟ ما نطلب منك دخول مرة ثانية.', style: tx(15, c: K.muted)),
      gap(20),
      ctx(K.teal, 'م', 'عرس محمد', 'أخوك · الخميس 21 يناير', 'مساعد', on: true),
      ctx(const Color(0xFFB4536A), 'ل', 'عرس ليلى', 'بنت عمك · تكتب الرفد', 'مساهم'),
      ctx(K.saffronInk, 'ص', 'عرسي', 'بدأت خطتك · بدون موعد', 'عريس'),
      gap(6),
      Center(child: Text('تقدر تبدّل بينهم من حسابي', style: tx(13, c: K.muted))),
    ],
  );
}

// ============================================================ داخل الخطة

/// Read-only money: the participant can see but not record.
Widget qMoneyView() => Phone(
  nav: Sec.money,
  children: [
    tabHeader('المال', 'عرس محمد · تشوف بس'),
    Box(
      pad: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('العرس بيكلف 10 مليون', style: tx(16, w: bold)),
          gap(4),
          Text('اندفع 4.6 · ناقص 2.5', style: tx(14, c: K.muted)),
          gap(12),
          moneyBar(0.46, 0.29, 0.25),
        ],
      ),
    ),
    gap(12),
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: K.tealSoft, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          const Icon(LucideIcons.eye, color: K.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text('صلاحيتك "تشوف بس". ما فيه أزرار تسجيل، والمصادر والسلف مخفية.',
                style: tx(13.5, w: bold, c: K.teal, h: 1.45)),
          ),
        ],
      ),
    ),
    sectionTitle('الدفعات الجاية'),
    whiteList([
      listRow(icon: LucideIcons.building2, fg: K.teal, soft: K.tealSoft, title: 'دفعة القاعة', sub: 'بعد 5 أيام', trailing: Text('500 ألف', style: tx(14, w: bold))),
      listRow(icon: LucideIcons.heartHandshake, fg: K.teal, soft: K.tealSoft, title: 'باقي المهر', sub: '15 نوفمبر', trailing: Text('مليون', style: tx(14, w: bold))),
    ]),
  ],
);

Widget qMoneyLocked() => _locked(
  Sec.money,
  'المال خاص بمحمد',
  'ما عندك صلاحية تشوف المال في هذي الخطة.\nلو تحتاج تسجّل مبلغ، اطلب منه.',
  'اطلب من محمد',
);

Widget qProvidersLocked() => _locked(
  Sec.providers,
  'المزودين عند محمد',
  'تشوف مواعيدهم في البرنامج،\nبس الطلبات والعروض خاصة بمحمد.',
  'اطلب صلاحية',
);

Widget qTasksMine() {
  Widget t(String title, String meta, {bool done = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? K.green : null,
            border: Border.all(color: done ? K.green : K.line, width: 2),
          ),
          child: done ? const Icon(LucideIcons.check, size: 14, color: Colors.white) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: tx(15.5, w: bold, c: done ? K.muted : K.ink)),
              Text(meta, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    nav: Sec.tasks,
    children: [
      tabHeader('المهام', 'عرس محمد · معك 4', sec: Sec.tasks),
      Row(
        children: [
          chip('لي', on: true, onBg: K.saffronInk),
          const SizedBox(width: 8),
          chip('كل مهام الخطة'),
        ],
      ),
      sectionTitle('لك'),
      whiteList([
        t('رتّب الغداء مع أبو علي', 'الجمعة · محمد عطاك هذي المهمة'),
        t('ذكّر آل الحمدي اللي ما ردّوا', '8 ضيوف · قبل 1 يناير'),
        t('رتّب سيارات الزفة', 'قبل 15 يناير'),
        t('استلم البدلة', 'خلصت أمس', done: true),
      ]),
      gap(12),
      Text('المهام اللي ما هي لك تشوفها في "كل مهام الخطة"، وما تقدر تعدّلها.',
          style: tx(13, c: K.muted)),
    ],
  );
}

/// The bride as a participant in the groom's plan: the date and programme.
Widget qBrideView() => Phone(
  nav: Sec.home,
  children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('عرس محمد', style: tx(24, w: bold)),
                Row(
                  children: [
                    Text('أنتِ مشاركة · ', style: tx(14, c: K.muted)),
                    tag('الموعد والبرنامج', K.teal, K.tealSoft),
                  ],
                ),
              ],
            ),
          ),
          avatar('س', const Color(0xFFB4536A), s: 44),
        ],
      ),
    ),
    gap(14),
    Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: K.teal, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          Text('96', style: tx(46, w: bold, c: Colors.white, h: 1)),
          const SizedBox(width: 12),
          Expanded(
            child: Text('يوم على العرس · الخميس 21 يناير', style: tx(16, w: bold, c: Colors.white)),
          ),
        ],
      ),
    ),
    sectionTitle('برنامج عرس الرجال'),
    whiteList([
      listRow(icon: LucideIcons.moon, fg: K.teal, soft: K.tealSoft, title: 'السمرة', sub: 'الثلاثاء 19 · الديوان'),
      listRow(icon: LucideIcons.leaf, fg: K.teal, soft: K.tealSoft, title: 'المقيل', sub: 'الأربعاء 20 · بيت الوالد'),
      listRow(icon: LucideIcons.partyPopper, fg: K.teal, soft: K.tealSoft, title: 'الزفاف', sub: 'الخميس 21 · قاعة سبأ'),
    ]),
    gap(12),
    Text('هذي خطة محمد بألوانها. خطتك أنتِ في "اختر المسار".', style: tx(13, c: K.muted)),
  ],
);

// ============================================================ حسابه

Widget qAccountPlans() {
  Widget p(Color c, String l, String t, String sub, String role) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        avatar(l, c, s: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: tx(15.5, w: bold)),
              Text(sub, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        tag(role, c, c.withValues(alpha: 0.12)),
      ],
    ),
  );
  return Phone(
    children: [
      subHeader('حسابي', sub: 'صالح الحمدي · ${ltr('771 554 220')}'),
      sectionTitle('الخطط اللي أشارك فيها'),
      whiteList([
        p(K.teal, 'م', 'عرس محمد', 'مساعد · المهام والضيوف والرفد', 'مساعد'),
        p(const Color(0xFFB4536A), 'ل', 'عرس ليلى', 'تكتب الرفد يوم العرس بس', 'مساهم'),
      ]),
      sectionTitle('خطتي'),
      whiteList([
        listRow(icon: LucideIcons.plus, fg: K.saffronInk, soft: K.saffronSoft, title: 'ابدأ خطة عرسك', sub: 'بنفس حسابك'),
      ]),
      sectionTitle('في عرس محمد'),
      whiteList([
        listRow(icon: LucideIcons.history, fg: K.muted, soft: K.bg, title: 'اللي سجّلته', sub: '12 حركة · تبقى باسمك'),
        listRow(icon: LucideIcons.logOut, fg: K.coral, soft: K.coralSoft, title: 'اطلع من الخطة', sub: 'مهامك ترجع لمحمد'),
      ]),
    ],
  );
}

Widget qLeave() => Phone(
  sheet: sheet(
    title: 'تطلع من عرس محمد؟',
    sub: 'تقدر ترجع لو أرسل لك دعوة ثانية',
    children: [
      Box(
        pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            for (final r in const [
              (LucideIcons.listChecks, 'مهامك الأربع ترجع لمحمد'),
              (LucideIcons.gem, 'الرفد اللي كتبته يبقى في دفتره باسمك'),
              (LucideIcons.bellOff, 'توقف تنبيهات هذي الخطة'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Icon(r.$1, size: 18, color: K.muted),
                    const SizedBox(width: 10),
                    Expanded(child: Text(r.$2, style: tx(14.5))),
                  ],
                ),
              ),
          ],
        ),
      ),
      gap(16),
      btn('اطلع من الخطة', wide: true, v: 16, fs: 17, bg: K.coral),
      gap(10),
      Center(child: Text('رجوع', style: tx(15, w: bold, c: K.muted))),
    ],
  ),
  children: [subHeader('حسابي')],
);

/// When the owner changes what the participant can do.
Widget qChanged() => Phone(
  nav: Sec.home,
  children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          Expanded(child: Text('أهلًا صالح', style: tx(24, w: bold))),
          avatar('ص', K.saffronInk, s: 44),
        ],
      ),
    ),
    gap(14),
    Box(
      c: K.saffronSoft,
      pad: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          iconTile(LucideIcons.key, K.saffronInk, Colors.white, s: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('محمد فتح لك المال', style: tx(16, w: bold)),
                Text('تقدر الآن تسجّل الدفعات والكاش اللي معك. المصادر والسلف تبقى خاصة فيه.',
                    style: tx(13.5, c: K.muted, h: 1.45)),
              ],
            ),
          ),
        ],
      ),
    ),
    gap(12),
    nextStep(
      when: 'اليوم',
      title: 'سجّل اللي صرفته من العهدة',
      sub: 'معك 120 ألف للسمرة والمقيل',
      why: 'لأن محمد فتح لك المال، والعهدة تنقفل بعد العرس',
      action: 'سجّل',
      icon: LucideIcons.wallet,
      fg: K.teal,
      soft: K.tealSoft,
    ),
    gap(12),
    Box(
      pad: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(LucideIcons.userX, color: K.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text('ولو شالك محمد من الخطة، توصلك رسالة هادية، واللي سجّلته يبقى باسمك.',
                style: tx(13.5, c: K.muted, h: 1.45)),
          ),
        ],
      ),
    ),
  ],
);
