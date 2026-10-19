// Journey prototype v3: the hard states. Each screen closes a lifecycle the
// happy path left open (no date, participants, pledges, provider refusals,
// cancellations, rafd after the wedding, sign-in errors, conflicts).
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import '../c_journey/screens_home.dart' show homeHeader;
import 'home.dart' show nextStep;

// ------------------------------------------------------------ shared bits

/// What happens if you go ahead: one consequence per row.
Widget _effect(IconData i, String s, {Color c = K.muted, String? end}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 7),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(i, size: 18, color: c),
      const SizedBox(width: 10),
      Expanded(child: Text(s, style: tx(14.5, h: 1.45))),
      if (end != null) ...[
        const SizedBox(width: 8),
        Text(end, style: tx(14, w: bold, c: c)),
      ],
    ],
  ),
);

/// A radio choice inside a sheet.
Widget _option(String s, {String? sub, bool on = false, Color c = K.teal}) =>
    Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: on ? c : K.line, width: on ? 2 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: on ? c : K.line, width: on ? 7 : 2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s, style: tx(15, w: bold)),
                if (sub != null) Text(sub, style: tx(13, c: K.muted)),
              ],
            ),
          ),
        ],
      ),
    );

Widget _note(String s, {Color c = K.teal, Color bg = K.tealSoft, IconData i = LucideIcons.info}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, size: 18, color: c),
          const SizedBox(width: 10),
          Expanded(child: Text(s, style: tx(13.5, w: bold, c: c, h: 1.45))),
        ],
      ),
    );

Widget _row(String a, String b, {Color c = K.ink}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(
    children: [
      SizedBox(width: 80, child: Text(a, style: tx(14, c: K.muted))),
      Expanded(child: Text(b, style: tx(15, w: bold, c: c))),
    ],
  ),
);

// ============================================================ بدون موعد

Widget vHomeNoDate() {
  Widget step(int n, String t, String sub, {bool done = false, bool now = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done ? K.teal : (now ? K.saffronSoft : K.bg),
            shape: BoxShape.circle,
          ),
          child: done
              ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
              : Text('$n', style: tx(14, w: bold, c: now ? K.saffronInk : K.muted)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: tx(15.5, w: bold, c: done ? K.muted : K.ink)),
              Text(sub, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    nav: Sec.home,
    children: [
      homeHeader(),
      gap(14),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [K.teal, K.tealDark],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الموعد لسا ما ثبت', style: tx(22, w: bold, c: Colors.white)),
                  gap(4),
                  Text('ولا يهمك. نرتب لك الخطوات بالترتيب، ولما يثبت الموعد تتوزع على الأيام لحالها.',
                      style: tx(13.5, c: Colors.white70, h: 1.5)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(LucideIcons.calendarClock, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
      gap(12),
      nextStep(
        when: 'لما تقدر',
        title: 'تقريبًا متى العرس؟',
        sub: 'شهر أو موسم يكفي: بعد رمضان، الصيف، آخر السنة',
        why: 'لأن القاعات تنحجز قبل بشهرين، ونبغى ننبهك في وقتها',
        action: 'اختر تقريبًا',
        second: 'ثبت الموعد',
        icon: LucideIcons.calendarDays,
      ),
      sectionTitle('خطواتك بالترتيب', action: 'كلها'),
      whiteList([
        step(1, 'اتفق على المهر', 'سجّلته: 3 مليون', done: true),
        step(2, 'حدد موعد عقد القران', 'قبل كل شي ثاني', now: true),
        step(3, 'احجز القاعة', 'لما يكون عندك شهر تقريبي'),
        step(4, 'ابدأ قائمة ضيوفك', 'تقدر تبدأ الحين، ما تحتاج موعد'),
      ]),
    ],
  );
}

Widget vDateApprox() => Phone(
  nav: Sec.home,
  sheet: sheet(
    title: 'تقريبًا متى؟',
    sub: 'نرتب المهام على التقريبي، ونعدّلها لما يثبت',
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('بعد رمضان'),
          chip('بعد العيد الكبير', on: true),
          chip('الصيف'),
          chip('آخر السنة'),
          chip('ما ندري بعد'),
        ],
      ),
      gap(14),
      Box(
        pad: const EdgeInsets.all(14),
        child: Row(
          children: [
            iconTile(LucideIcons.moon, K.teal, K.tealSoft, s: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ذو الحجة إلى محرّم', style: tx(16, w: bold)),
                  Text('يونيو إلى يوليو تقريبًا', style: tx(13, c: K.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
      gap(12),
      _note('القاعات في موسم العيد تنحجز بدري. بنذكّرك تحجز في مارس.',
          c: K.saffronInk, bg: K.saffronSoft, i: LucideIcons.sparkles),
      gap(16),
      btn('رتّب خطتي على هذا', wide: true, v: 16, fs: 17),
    ],
  ),
  children: [homeHeader()],
);

Widget vMoneyNoBudget() => Phone(
  nav: Sec.money,
  children: [
    tabHeader('المال', 'ما حطيت ميزانية بعد', actions: [LucideIcons.share2]),
    Box(
      pad: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('اللي سجّلته لين الحين', style: tx(14, c: K.muted)),
          gap(4),
          Text('3,000,000 ر.ي', style: tx(30, w: bold)),
          Text('المهر بس · دفعت منه 2 مليون', style: tx(13.5, c: K.muted)),
          gap(14),
          bar(0.66, K.teal),
        ],
      ),
    ),
    gap(12),
    nextStep(
      when: 'دقيقة وحدة',
      title: 'كم تقريبًا بتصرف على عرسك؟',
      sub: 'رقم تقريبي يكفي، وتعدّله متى ما تبغى',
      why: 'بدونه ما نقدر نقول لك كم ناقصك ولا ننبهك قبل ما تتعدى',
      action: 'حط رقم',
      second: 'ساعدني أقدّر',
      icon: LucideIcons.wallet,
      fg: K.teal,
      soft: K.tealSoft,
    ),
    sectionTitle('ساعدني أقدّر'),
    Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('عرسان صنعاء بـ 100 إلى 150 ضيف', style: tx(15, w: bold)),
          gap(2),
          Text('صرفوا على عرس الرجال بين 6 و 9 مليون', style: tx(14, c: K.muted)),
          gap(12),
          Row(
            children: [
              Text('6 مليون', style: tx(12, c: K.muted)),
              const SizedBox(width: 8),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    bar(1, K.tealSoft, h: 10),
                    Row(
                      children: [
                        const Spacer(flex: 2),
                        Expanded(flex: 3, child: bar(1, K.teal, h: 10)),
                        const Spacer(flex: 2),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('9 مليون', style: tx(12, c: K.muted)),
            ],
          ),
          gap(10),
          Text('من عرسان سجّلوا في اعّرست · بدون المهر', style: tx(12, c: K.faint)),
        ],
      ),
    ),
  ],
);

// ============================================================ المشاركين

Widget vFromFamily() => Phone(
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
    child: btn('افتح الرابط', wide: true, v: 16, fs: 17),
  ),
  children: [
    subHeader(''),
    gap(10),
    Center(child: iconTile(LucideIcons.users, K.teal, K.tealSoft, s: 76, r: 24)),
    gap(18),
    Center(child: Text('تساعد في عرس أحد؟', style: tx(26, w: bold))),
    gap(6),
    Center(
      child: Text('العريس أو العروسة يضيفونك من خطتهم،\nويوصلك رابط على واتساب.',
          textAlign: TextAlign.center, style: tx(15, c: K.muted, h: 1.5)),
    ),
    gap(24),
    field('الصق رابط الدعوة', 'aarast.app/j/7KQ2…', icon: LucideIcons.link, focused: true),
    gap(10),
    _note('لقينا رابط في الحافظة. نفتحه؟', i: LucideIcons.clipboardCheck),
    gap(22),
    Row(
      children: [
        const Expanded(child: Divider(color: K.line)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text('ما عندك رابط؟', style: tx(13, c: K.muted)),
        ),
        const Expanded(child: Divider(color: K.line)),
      ],
    ),
    gap(14),
    Box(
      pad: const EdgeInsets.all(14),
      child: Row(
        children: [
          iconTile(LucideIcons.messageCircle, K.green, K.greenSoft, s: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('اطلب منه يضيفك', style: tx(15.5, w: bold)),
                Text('نجهز لك رسالة ترسلها له', style: tx(13, c: K.muted)),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronLeft, size: 18, color: K.faint),
        ],
      ),
    ),
    gap(10),
    Center(child: Text('أو أنت عريس؟ ابدأ خطتك', style: tx(14, w: bold, c: K.teal))),
  ],
);

Widget vInviteLanding() {
  Widget perm(IconData i, String s, bool on) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
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
    gradient: const LinearGradient(
      colors: [K.tealSoft, K.bg],
      begin: Alignment.topCenter,
      end: Alignment.center,
    ),
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: Column(
        children: [
          btn('أبشر، معك', wide: true, v: 16, fs: 17),
          gap(10),
          Text('مو الحين', style: tx(15, w: bold, c: K.muted)),
        ],
      ),
    ),
    children: [
      gap(30),
      Center(child: wordmark(s: 30)),
      gap(26),
      Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            avatar('م', K.teal, s: 84),
            Positioned(
              bottom: -4,
              left: -4,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: K.saffron, shape: BoxShape.circle),
                child: const Icon(LucideIcons.heartHandshake, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      gap(16),
      Center(child: Text('محمد يبغاك معه في عرسه', style: tx(24, w: bold))),
      gap(4),
      Center(child: Text('الخميس 21 يناير · صنعاء', style: tx(15, c: K.muted))),
      gap(22),
      Box(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('بتقدر:', style: tx(14, w: bold, c: K.muted)),
            gap(4),
            perm(LucideIcons.calendarDays, 'تشوف الموعد والبرنامج', true),
            perm(LucideIcons.listChecks, 'تشوف المهام وتخلّصها', true),
            perm(LucideIcons.users, 'تضيف ضيوف وترتبهم', true),
            perm(LucideIcons.gem, 'تكتب الرفد يوم العرس', true),
            perm(LucideIcons.wallet, 'المال', false),
          ],
        ),
      ),
      gap(12),
      _note('محمد يقدر يغيّرها متى ما بغى، وأنت تقدر تطلع من الخطة بضغطة.',
          i: LucideIcons.shieldCheck),
    ],
  );
}

Widget vHelperHome() => Phone(
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
                Text('أهلًا صالح', style: tx(24, w: bold)),
                Row(
                  children: [
                    Text('عرس محمد · ', style: tx(14, c: K.muted)),
                    tag('أنت مساعد', K.teal, K.tealSoft),
                  ],
                ),
              ],
            ),
          ),
          avatar('ص', K.saffronInk, s: 44),
        ],
      ),
    ),
    gap(14),
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: K.teal, borderRadius: BorderRadius.circular(24)),
      child: Row(
        children: [
          Text('96', style: tx(46, w: bold, c: Colors.white, h: 1)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('يوم على عرس أخوك', style: tx(17, w: bold, c: Colors.white)),
                Text('الخميس 21 يناير · قاعة سبأ', style: tx(13, c: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    ),
    gap(12),
    nextStep(
      when: 'الجمعة',
      title: 'رتّب الغداء مع أبو علي',
      sub: 'محمد عطاك هذي المهمة',
      why: 'لأن أبو علي يبغى العدد قبل أسبوعين',
      action: 'خلصت',
      second: 'كلّم أبو علي',
      icon: LucideIcons.soup,
    ),
    sectionTitle('مهامك', action: '3'),
    whiteList([
      listRow(
        icon: LucideIcons.users,
        fg: K.lilac,
        soft: K.lilacSoft,
        title: 'ذكّر آل الحمدي اللي ما ردّوا',
        sub: '8 ضيوف · قبل 1 يناير',
      ),
      listRow(
        icon: LucideIcons.car,
        fg: K.saffronInk,
        soft: K.saffronSoft,
        title: 'رتّب سيارات الزفة',
        sub: 'قبل 15 يناير',
      ),
    ]),
    gap(12),
    _note('المال مخفي عنك. لو تحتاج تسجّل مبلغ، اطلب من محمد يفتح لك.',
        c: K.muted, bg: Colors.white, i: LucideIcons.eyeOff),
  ],
);

Widget vParticipantStates() {
  Widget m(String l, Color c, String name, String sub, Widget end, {bool dim = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        Opacity(opacity: dim ? 0.45 : 1, child: avatar(l, c, s: 42)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: tx(15.5, w: bold, c: dim ? K.faint : K.ink)),
              Text(sub, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        end,
      ],
    ),
  );
  return Phone(
    children: [
      subHeader('المشاركين', sub: 'مين معك، ومين لسا'),
      whiteList([
        m('ص', K.saffronInk, 'صالح', 'أخوي · مساعد · فعّال', tag('معك', K.green, K.greenSoft)),
        m('س', K.lilac, 'سلمى', 'العروسة · الموعد والبرنامج', tag('معك', K.green, K.greenSoft)),
      ]),
      sectionTitle('ينتظرون'),
      whiteList([
        m('ع', K.teal, 'الوالد', 'الدعوة وصلت أمس · ما فتحها',
            softAction('ذكّره')),
        m('ع', K.sky, 'عادل', 'ما نعرف إذا وصلت · رقمه ما عليه واتساب؟',
            softAction('أرسلها نصية', fg: K.saffronInk, bg: K.saffronSoft)),
      ]),
      sectionTitle('طلعوا'),
      whiteList([
        m('ف', K.faint, 'فهد', 'طلع من الخطة 10 أكتوبر · مهامه رجعت لك',
            Text('أضفه', style: tx(13.5, w: bold, c: K.teal)), dim: true),
      ]),
      gap(12),
      _note('لما تشيل أحد أو يطلع، مهامه ترجع لك، واللي سجّله يبقى باسمه.',
          i: LucideIcons.info),
    ],
  );
}

// ============================================================ الموعود

Widget vPledgeCheck() => Phone(
  nav: Sec.money,
  sheet: sheet(
    title: 'وصلت فلوس عادل؟',
    sub: 'وعدك بـ 1,200,000 قبل العرس · دين',
    children: [
      _option('وصلت كلها', sub: 'تنتقل من موعود إلى معك', on: true),
      _option('وصل جزء', sub: 'تكتب كم، والباقي يبقى موعود'),
      _option('لسا', sub: 'نسألك مرة ثانية بعد أسبوع'),
      _option('ما بتوصل', sub: 'تنشال من حسابك، ويزيد الناقص', c: K.coral),
      gap(6),
      Box(
        c: K.tealSoft,
        pad: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(child: Text('معك يصير', style: tx(14, c: K.teal))),
            Text('2.9', style: tx(15, c: K.muted)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(LucideIcons.arrowLeft, size: 16, color: K.teal),
            ),
            Text('4.1 مليون', style: tx(17, w: bold, c: K.teal)),
          ],
        ),
      ),
      gap(16),
      btn('تمام', wide: true, v: 16, fs: 17),
    ],
  ),
  children: [tabHeader('المال', 'ماشية، بس ناقصك 2.5 مليون')],
);

// ============================================================ المزودين

Widget vProvHard() {
  Widget card2({
    required IconData i,
    required String name,
    required String state,
    required Color c,
    required Color soft,
    required String body,
    required List<Widget> actions,
  }) => Box(
    pad: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            iconTile(i, K.sky, K.skySoft, s: 40),
            const SizedBox(width: 12),
            Expanded(child: Text(name, style: tx(16, w: bold))),
            tag(state, c, soft),
          ],
        ),
        gap(10),
        Text(body, style: tx(14, c: K.muted, h: 1.5)),
        gap(12),
        Wrap(spacing: 8, runSpacing: 8, children: actions),
      ],
    ),
  );
  return Phone(
    nav: Sec.providers,
    children: [
      tabHeader('المزودين', 'محجوز 3 من 6 · 3 يحتاجونك', actions: [LucideIcons.search]),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: K.coralSoft, borderRadius: BorderRadius.circular(18)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(LucideIcons.alertTriangle, size: 19, color: K.coral),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'ضيافة الأصالة موقوفة مؤقتًا في اعّرست. حجزك ودفعاتك ما تتأثر، بس كلّمهم وتأكد إن موعدك ثابت.',
                style: tx(13.5, w: bold, c: K.coral, h: 1.45),
              ),
            ),
          ],
        ),
      ),
      gap(12),
      card2(
        i: LucideIcons.music,
        name: 'الفنان أيمن الأنسي',
        state: 'اعتذر',
        c: K.coral,
        soft: K.coralSoft,
        body: 'مشغول يوم 21 يناير. لقينا لك 3 فنانين فاضيين يومك وعلى قد بندك.',
        actions: [
          btn('شوف البدائل', bg: K.sky, v: 10, fs: 14),
          btn('اطلب يوم ثاني', bg: K.bg, fg: K.muted, v: 10, fs: 14),
        ],
      ),
      gap(10),
      card2(
        i: LucideIcons.leaf,
        name: 'مقوّت الروضة',
        state: 'شاف وما رد',
        c: K.saffronInk,
        soft: K.saffronSoft,
        body: 'فتح طلبك قبل يومين. اللي يردون عادة يردون خلال يوم.',
        actions: [
          btn('ذكّره', bg: K.sky, v: 10, fs: 14),
          btn('اطلب من غيره', bg: K.bg, fg: K.muted, v: 10, fs: 14),
        ],
      ),
      gap(10),
      card2(
        i: LucideIcons.camera,
        name: 'عدسة سبأ',
        state: 'سحب عرضه',
        c: K.muted,
        soft: K.bg,
        body: 'عرض 480 ألف ما عاد متاح. باقي عندك عرض ضوء صنعاء 550 ألف.',
        actions: [
          btn('افتح العرض الثاني', bg: K.sky, v: 10, fs: 14),
          btn('اسألهم ليش', bg: K.bg, fg: K.muted, v: 10, fs: 14),
        ],
      ),
    ],
  );
}

Widget vRejectOffer() => Phone(
  nav: Sec.providers,
  sheet: sheet(
    title: 'ما يناسبك العرض؟',
    sub: 'ضوء صنعاء · 550 ألف',
    children: [
      Text('ليش؟ (اختياري)', style: tx(14, w: bold, c: K.muted)),
      gap(8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('السعر فوق بندي', on: true, onBg: K.sky),
          chip('اخترت غيرهم'),
          chip('الموعد ما يناسب'),
          chip('بدون سبب'),
        ],
      ),
      gap(14),
      Text('يوصلهم كذا:', style: tx(14, w: bold, c: K.muted)),
      gap(8),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Text(
          'الله يعطيكم العافية. شكرًا على العرض، السعر هذي المرة فوق اللي حاطه للتصوير. إذا عندكم باقة أخف نتشرف.',
          style: tx(14.5, h: 1.55),
        ),
      ),
      gap(10),
      Row(
        children: [
          const Icon(LucideIcons.pencil, size: 15, color: K.sky),
          const SizedBox(width: 6),
          Text('عدّل الرسالة', style: tx(13.5, w: bold, c: K.sky)),
          const Spacer(),
          Text('بندك ما ينذكر', style: tx(12.5, c: K.muted)),
        ],
      ),
      gap(16),
      btn('أرسل واعتذر', wide: true, v: 16, fs: 17, bg: K.sky),
    ],
  ),
  children: [tabHeader('المزودين', 'محجوز 3 من 6')],
);

Widget vCancelBooking() => Phone(
  nav: Sec.providers,
  sheet: sheet(
    title: 'إلغاء حجز ضيافة الأصالة',
    sub: 'قبل ما تلغي، هذا اللي بيصير',
    children: [
      Box(
        pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            _effect(LucideIcons.bellRing, 'يوصلهم إن الحجز انلغى'),
            _effect(LucideIcons.calendarClock, 'دفعة 20 ديسمبر تنشال', end: '400 ألف'),
            _effect(LucideIcons.listChecks, 'مهمة "تذوّق الضيافة" تنلغي'),
            _effect(LucideIcons.wallet, 'بند الضيافة يرجع بدون مزود'),
          ],
        ),
      ),
      gap(12),
      Text('العربون اللي دفعته: 300,000', style: tx(15, w: bold)),
      gap(8),
      Row(
        children: [
          Expanded(child: chip('رجّعوه كله')),
          const SizedBox(width: 6),
          Expanded(child: chip('رجّعوا جزء', on: true, onBg: K.coral)),
          const SizedBox(width: 6),
          Expanded(child: chip('ما رجّعوه')),
        ],
      ),
      gap(10),
      amountField('كم رجع؟', '150,000', 'مية وخمسين ألف ريال', focused: false),
      gap(8),
      Text('الباقي 150 ألف ينكتب خسارة في البند، عشان أرقامك تبقى صادقة.',
          style: tx(13, c: K.muted)),
      gap(16),
      btn('ألغِ الحجز', wide: true, v: 16, fs: 17, bg: K.coral),
    ],
  ),
  children: [tabHeader('المزودين', 'محجوز 3 من 6')],
);

Widget vRateSent() => Phone(
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
    child: btn('قيّم قاعة سبأ', wide: true, v: 16, fs: 17, bg: K.saffronInk),
  ),
  children: [
    subHeader('تقييمك'),
    gap(10),
    Center(child: iconTile(LucideIcons.star, K.saffronInk, K.saffronSoft, s: 76, r: 24)),
    gap(16),
    Center(child: Text('وصل تقييمك لفرقة الأفراح', style: tx(22, w: bold))),
    gap(4),
    Center(child: Text('شكرًا، العرسان الجايين بيستفيدون منه', style: tx(15, c: K.muted))),
    gap(22),
    Box(
      pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          _effect(LucideIcons.checkCircle2, 'انرسل', c: K.green, end: 'الحين'),
          _effect(LucideIcons.clock, 'نراجعه خلال يوم', c: K.saffronInk),
          _effect(LucideIcons.circle, 'ينشر باسمك الأول بس', c: K.faint),
        ],
      ),
    ),
    gap(12),
    _note('نراجع كل تقييم عشان ما ينزل كلام جارح أو أرقام جوال. وإذا ما نشرناه نقول لك ليش.',
        c: K.saffronInk, bg: K.saffronSoft, i: LucideIcons.shieldCheck),
    sectionTitle('باقي تقيّم'),
    whiteList([
      listRow(icon: LucideIcons.building2, fg: K.sky, soft: K.skySoft, title: 'قاعة سبأ', sub: 'القاعة'),
      listRow(icon: LucideIcons.utensils, fg: K.sky, soft: K.skySoft, title: 'ضيافة الأصالة', sub: 'الضيافة'),
    ]),
  ],
);

// ============================================================ الرفد بعد العرس

Widget vRafdLater() {
  Widget due(String l, String name, String when, String amt, {bool soon = false, bool done = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        avatar(l, done ? K.faint : K.saffronInk, s: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: tx(15.5, w: bold, c: done ? K.muted : K.ink)),
              Text(when, style: tx(12.5, w: soon ? bold : FontWeight.w400, c: soon ? K.saffronInk : K.muted)),
            ],
          ),
        ),
        done
            ? tag('رديته', K.green, K.greenSoft)
            : Text(amt, style: tx(14.5, w: bold)),
      ],
    ),
  );
  return Phone(
    nav: Sec.home,
    children: [
      homeHeader(hello: 'مبروك يا محمد'),
      gap(4),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: tag('خطتك محفوظة · دفتر الرفد معك', K.teal, K.tealSoft),
      ),
      gap(14),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [K.saffron, K.saffronInk],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الخميس الجاي', style: tx(13, w: bold, c: Colors.white70)),
            gap(2),
            Text('عرس عبدالله الحمدي', style: tx(22, w: bold, c: Colors.white)),
            gap(4),
            Text('رفدك بـ 20,000 يوم عرسك، وهذا وقت تردّها له.',
                style: tx(14.5, c: Colors.white, h: 1.45)),
            gap(14),
            Row(
              children: [
                btn('سجّل اللي رديته', bg: Colors.white, fg: K.saffronInk, v: 10, fs: 14),
                const SizedBox(width: 8),
                btn('ذكّرني الخميس', bg: Colors.white24, v: 10, fs: 14),
              ],
            ),
          ],
        ),
      ),
      sectionTitle('ترده قريبًا', action: 'الدفتر'),
      whiteList([
        due('ع', 'عبدالله الحمدي', 'الخميس 11 مارس', '20,000', soon: true),
        due('س', 'سالم الأهدل', 'أبريل · سمعنا من صالح', '50,000'),
        due('ي', 'ياسر الأهدل', 'رديته في عرسه 2 مارس', '10,000', done: true),
      ]),
      gap(12),
      _note('أعراس أصحابك تنضاف لما تعرف موعدها، أو لما يرسلون لك دعوة من اعّرست.',
          i: LucideIcons.sparkles),
    ],
  );
}

// ============================================================ التراجع والإلغاء

Widget vPaymentReversed() => Phone(
  children: [
    subHeader('دفعة الفنان', sub: 'انعكست'),
    Box(
      c: K.bg,
      border: K.line,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '100,000 ر.ي',
                  style: tx(28, w: bold, c: K.faint).copyWith(
                    decoration: TextDecoration.lineThrough,
                    decorationColor: K.faint,
                  ),
                ),
                Text('ما تنحسب في أي رقم', style: tx(13.5, c: K.muted)),
              ],
            ),
          ),
          tag('انعكست', K.coral, K.coralSoft),
        ],
      ),
    ),
    gap(12),
    Box(
      child: Column(
        children: [
          _row('ليش', 'سجلتها على الفنان وهي للتصوير'),
          _row('مين', 'أنت · 9:40 الصبح'),
          _row('الرصيد', 'رجعت 100 ألف لمدخراتك', c: K.green),
        ],
      ),
    ),
    gap(12),
    _note('الدفعة ما تنمسح، تبقى مشطوبة عشان السجل يبقى صادق ومشاركينك يعرفون وش صار.',
        c: K.muted, bg: Colors.white, i: LucideIcons.fileText),
    gap(12),
    Box(
      c: K.tealSoft,
      pad: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(LucideIcons.camera, color: K.teal),
          const SizedBox(width: 10),
          Expanded(child: Text('سجّلها على التصوير بدالها؟', style: tx(15, w: bold, c: K.teal))),
          btn('سجّل', v: 9, fs: 14),
        ],
      ),
    ),
  ],
);

Widget vCancelItem() => Phone(
  nav: Sec.money,
  sheet: sheet(
    title: 'تشيل بند السيارات؟',
    sub: 'حطيت له 200 ألف، وما دفعت منه شي',
    children: [
      Box(
        pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          children: [
            _effect(LucideIcons.wallet, 'ميزانيتك تخف', end: '200 ألف'),
            _effect(LucideIcons.listChecks, 'مهمة "حجز سيارات الزفة" تنلغي'),
            _effect(LucideIcons.store, 'ما فيه مزود مرتبط'),
          ],
        ),
      ),
      gap(12),
      _option('شيله', sub: 'يروح من البنود، ويبقى في السجل', on: true, c: K.coral),
      _option('خلّه، بس بدون مبلغ', sub: 'لو بتتكفل فيه العائلة مثلًا'),
      gap(10),
      btn('شيل البند', wide: true, v: 16, fs: 17, bg: K.coral),
    ],
  ),
  children: [tabHeader('المال', 'ماشية، بس ناقصك 2.5 مليون')],
);

Widget vTaskMenu() => Phone(
  nav: Sec.tasks,
  sheet: sheet(
    title: 'رتّب سيارات الزفة',
    sub: 'لصالح · قبل 15 يناير',
    children: [
      for (final r in const [
        (LucideIcons.userPlus, 'حوّلها لأحد ثاني', 'الوالد، أو أنت', K.ink),
        (LucideIcons.calendarClock, 'غيّر موعدها', 'تقدر تكتب "بعد العصر"', K.ink),
        (LucideIcons.refreshCw, 'أعد فتحها', 'لو انقفلت بالغلط', K.ink),
        (LucideIcons.x, 'ما نحتاجها', 'تنلغي وتبقى في السجل', K.coral),
      ])
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Icon(r.$1, size: 20, color: r.$4),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.$2, style: tx(15.5, w: bold, c: r.$4)),
                    Text(r.$3, style: tx(13, c: K.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  ),
  children: [tabHeader('المهام', '6 هذا الشهر · 2 متأخرة', sec: Sec.tasks)],
);

// ============================================================ الدخول

Widget vOtpWrong() {
  Widget box(String d) => Container(
    width: 58,
    height: 64,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: K.coralSoft,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: K.coral, width: 2),
    ),
    child: Text(d, style: tx(26, w: bold, c: K.coral)),
  );
  return Phone(
    children: [
      subHeader(''),
      gap(8),
      Text('أدخل الرمز', style: tx(28, w: bold)),
      gap(4),
      Text('أرسلناه على واتساب ${ltr('+967 777 123 456')}', style: tx(15, c: K.muted)),
      gap(26),
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [box('4'), box('8'), box('1'), box('9'), box('2')],
        ),
      ),
      gap(14),
      Row(
        children: [
          const Icon(LucideIcons.alertCircle, size: 18, color: K.coral),
          const SizedBox(width: 8),
          Text('الرمز غلط. باقي لك محاولتين.', style: tx(14.5, w: bold, c: K.coral)),
        ],
      ),
      gap(26),
      Box(
        pad: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(LucideIcons.clock, size: 20, color: K.muted),
            const SizedBox(width: 10),
            Expanded(child: Text('تقدر تطلب رمز جديد بعد', style: tx(15))),
            Text(ltr('0:42'), style: tx(16, w: bold, c: K.teal)),
          ],
        ),
      ),
      gap(10),
      Box(
        pad: const EdgeInsets.all(14),
        child: Row(
          children: [
            iconTile(LucideIcons.messageSquare, K.teal, K.tealSoft, s: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ما وصلك على واتساب؟', style: tx(15.5, w: bold)),
                  Text('نرسله رسالة نصية عادية', style: tx(13, c: K.muted)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronLeft, size: 18, color: K.faint),
          ],
        ),
      ),
      gap(14),
      Center(child: Text('الرقم غلط؟ غيّره', style: tx(14, w: bold, c: K.teal))),
    ],
  );
}

Widget vSessionExpired() => Phone(
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
    child: btn('أرسل الرمز على واتساب', wide: true, v: 16, fs: 17, icon: LucideIcons.send),
  ),
  children: [
    gap(40),
    Center(child: iconTile(LucideIcons.lock, K.teal, K.tealSoft, s: 80, r: 26)),
    gap(20),
    Center(child: Text('ادخل مرة ثانية', style: tx(26, w: bold))),
    gap(6),
    Center(
      child: Text('طال غيابك، فقفلنا الدخول لأمانك.\nرمز واحد وترجع مكانك.',
          textAlign: TextAlign.center, style: tx(15, c: K.muted, h: 1.5)),
    ),
    gap(26),
    Box(
      child: Row(
        children: [
          iconTile(LucideIcons.cloudOff, K.saffronInk, K.saffronSoft, s: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('3 أشياء سجّلتها بدون نت', style: tx(15.5, w: bold)),
                Text('محفوظة في جوالك، وتوصل أول ما تدخل', style: tx(13, c: K.muted)),
              ],
            ),
          ),
        ],
      ),
    ),
    gap(10),
    Center(child: Text(ltr('+967 777 123 456'), style: tx(15, w: bold, c: K.muted))),
  ],
);

// ============================================================ المشاركين معًا

Widget vConflict() {
  Widget pick(String l, Color c, String who, String when, String v, {bool on = false}) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: on ? K.teal : K.line, width: on ? 2 : 1),
    ),
    child: Row(
      children: [
        avatar(l, c, s: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(who, style: tx(15, w: bold)),
              Text(when, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        Text(v, style: tx(18, w: bold, c: on ? K.teal : K.ink)),
      ],
    ),
  );
  return Phone(
    nav: Sec.money,
    sheet: sheet(
      title: 'تعديلين على نفس البند',
      sub: 'الغداء · كل واحد عدّل وهو بدون نت',
      children: [
        pick('ص', K.saffronInk, 'صالح', 'أمس 8:10 مساءً', '1,000,000'),
        pick('ع', K.teal, 'الوالد', 'أمس 9:30 مساءً · الأحدث', '1,200,000', on: true),
        gap(4),
        _note('باقي التعديلات (3) اندمجت لحالها، هذا بس اللي يحتاج قرارك.',
            i: LucideIcons.gitMerge),
        gap(16),
        btn('اعتمد رقم الوالد', wide: true, v: 16, fs: 17),
        gap(10),
        Center(child: Text('اسألهم في المحادثة', style: tx(14, w: bold, c: K.teal))),
      ],
    ),
    children: [tabHeader('المال', 'ماشية، بس ناقصك 2.5 مليون')],
  );
}

Widget vActivity() {
  Widget a(String l, Color c, String who, String what, String when, {IconData? i}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        avatar(l, c, s: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$who ', style: tx(14.5, w: bold)),
                    TextSpan(text: what, style: tx(14.5)),
                  ],
                ),
              ),
              Text(when, style: tx(12, c: K.faint)),
            ],
          ),
        ),
        if (i != null) Icon(i, size: 17, color: K.faint),
      ],
    ),
  );
  return Phone(
    children: [
      subHeader('وش صار', sub: 'كل اللي سوّاه المشاركين في خطتك'),
      Row(
        children: [
          chip('الكل', on: true),
          const SizedBox(width: 8),
          chip('المال'),
          const SizedBox(width: 8),
          chip('المهام'),
          const SizedBox(width: 8),
          chip('الضيوف'),
        ],
      ),
      sectionTitle('اليوم'),
      whiteList([
        a('ص', K.saffronInk, 'صالح', 'سجّل دفعة الغداء 200 ألف لأبو علي', '10:20 الصبح', i: LucideIcons.wallet),
        a('م', K.teal, 'أنت', 'عكست دفعة الفنان 100 ألف', '9:40 الصبح', i: LucideIcons.refreshCw),
        a('ع', K.teal, 'الوالد', 'أضاف 12 ضيف من آل السقاف', '8:05 الصبح', i: LucideIcons.users),
      ]),
      sectionTitle('أمس'),
      whiteList([
        a('ص', K.saffronInk, 'صالح', 'خلّص "استلم البدلة"', '7:45 مساءً', i: LucideIcons.checkCircle2),
        a('س', K.lilac, 'سلمى', 'انضمت للخطة', '4:00 العصر', i: LucideIcons.userPlus),
        a('ف', K.faint, 'فهد', 'طلع من الخطة', '1:15 الظهر', i: LucideIcons.logOut),
      ]),
    ],
  );
}

// ============================================================ أول مرة

Widget _empty({
  required Sec sec,
  required String title,
  required String status,
  required IconData icon,
  required Color c,
  required Color soft,
  required String big,
  required String sub,
  required List<(IconData, String, String)> ways,
}) => Phone(
  nav: sec,
  children: [
    tabHeader(title, status, sec: sec),
    gap(18),
    Center(child: iconTile(icon, c, soft, s: 84, r: 28)),
    gap(16),
    Center(child: Text(big, textAlign: TextAlign.center, style: tx(23, w: bold))),
    gap(6),
    Center(
      child: Text(sub, textAlign: TextAlign.center, style: tx(15, c: K.muted, h: 1.5)),
    ),
    gap(22),
    for (var i = 0; i < ways.length; i++)
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: i == 0 ? Border.all(color: c, width: 2) : null,
        ),
        child: Row(
          children: [
            iconTile(ways[i].$1, c, soft, s: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ways[i].$2, style: tx(15.5, w: bold)),
                  Text(ways[i].$3, style: tx(13, c: K.muted)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronLeft, size: 18, color: K.faint),
          ],
        ),
      ),
  ],
);

Widget vGuestsEmpty() => _empty(
  sec: Sec.guests,
  title: 'الضيوف',
  status: 'ما أضفت أحد بعد',
  icon: LucideIcons.users,
  c: K.lilac,
  soft: K.lilacSoft,
  big: 'مين بتعزم؟',
  sub: 'ابدأ بالقريبين. العدد يساعدنا\nنحسب لك الضيافة والقاعة.',
  ways: const [
    (LucideIcons.contact, 'من جهات الاتصال', 'تختار، ونرتبهم حسب العائلة'),
    (LucideIcons.hash, 'عدد تقريبي بس', 'مثل 120، والأسماء بعدين'),
    (LucideIcons.userPlus, 'ضيف واحد', 'اسم، وكم معه'),
  ],
);

Widget vProvidersEmpty() => _empty(
  sec: Sec.providers,
  title: 'المزودين',
  status: 'ما طلبت من أحد بعد',
  icon: LucideIcons.store,
  c: K.sky,
  soft: K.skySoft,
  big: 'نبدأ بالقاعة',
  sub: 'لأنها تحدد يومك وعدد ضيوفك،\nوالقاعات تنحجز قبل بشهرين.',
  ways: const [
    (LucideIcons.building2, 'قاعات فاضية يوم عرسك', 'على قد بندك في صنعاء'),
    (LucideIcons.checkCircle2, 'حجزت برا اعّرست', 'سجّله هنا عشان يدخل خطتك'),
    (LucideIcons.search, 'استكشف كل الخدمات', 'فرق، تصوير، زينة، ضيافة'),
  ],
);

// ============================================================ إيقاف الخطة

/// Stopping the plan if the wedding is called off. No question why, nothing
/// deleted, and help with what is still open (bookings and deposits).
Widget vPausePlan() {
  Widget dep(String name, String paid, {bool asked = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        const Icon(LucideIcons.store, size: 18, color: K.sky),
        const SizedBox(width: 10),
        Expanded(child: Text(name, style: tx(15, w: bold))),
        Text(paid, style: tx(13.5, c: K.muted)),
      ],
    ),
  );
  return Phone(
    sheet: sheet(
      title: 'إيقاف الخطة',
      sub: 'ما نسألك ليش. خطتك تنحفظ، وترجعها متى ما بغيت.',
      children: [
        Box(
          pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              _effect(LucideIcons.bellOff, 'التذكيرات والمهام توقف'),
              _effect(LucideIcons.users, 'المشاركين يشوفون "الخطة متوقفة" بس، بدون سبب'),
              _effect(LucideIcons.mail, 'الضيوف ما يوصلهم شي إلا إذا أنت أرسلت'),
              _effect(LucideIcons.fileText, 'المال والإيصالات والرفد تبقى محفوظة'),
            ],
          ),
        ),
        gap(12),
        Text('حجوزات فيها عرابين', style: tx(14, w: bold, c: K.muted)),
        gap(4),
        Box(
          pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              dep('قاعة سبأ', 'عربون 500 ألف'),
              dep('ضيافة الأصالة', 'عربون 300 ألف'),
              dep('فرقة الأفراح', 'عربون 100 ألف'),
            ],
          ),
        ),
        gap(10),
        _option('بلّغهم عني بأدب، واطلب الاسترجاع', sub: 'رسالة جاهزة لكل مزود، تشوفها قبل ما تنرسل', on: true),
        _option('أبلّغهم بنفسي'),
        gap(8),
        btn('أوقف الخطة', wide: true, v: 16, fs: 17, bg: K.ink),
        gap(10),
        Center(child: Text('تبغى تأجيل بس؟ أجّل العرس', style: tx(14, w: bold, c: K.teal))),
      ],
    ),
    children: [subHeader('حسابي')],
  );
}

Widget vPlanPaused() {
  Widget dep(String name, String paid, Widget state) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        iconTile(LucideIcons.store, K.sky, K.skySoft, s: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: tx(15.5, w: bold)),
              Text(paid, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        state,
      ],
    ),
  );
  return Phone(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Row(
          children: [
            Expanded(child: Text('أهلًا محمد', style: tx(24, w: bold))),
            avatar('م', K.saffron, s: 44),
          ],
        ),
      ),
      gap(14),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                iconTile(LucideIcons.pauseCircle, K.muted, K.bg, s: 44),
                const SizedBox(width: 12),
                Expanded(child: Text('خطتك متوقفة', style: tx(22, w: bold))),
              ],
            ),
            gap(10),
            Text('كل شي محفوظ كما هو. الله يكتب لك الخير، ومتى ما بغيت ترجع، ترجع من نفس المكان.',
                style: tx(14.5, c: K.muted, h: 1.55)),
            gap(14),
            Row(
              children: [
                btn('رجّع الخطة', v: 11, fs: 14),
                const SizedBox(width: 8),
                btn('احذفها نهائيًا', bg: K.bg, fg: K.coral, v: 11, fs: 14),
              ],
            ),
          ],
        ),
      ),
      sectionTitle('العرابين', action: '600 من 900 ألف رجعت'),
      whiteList([
        dep('قاعة سبأ', 'عربون 500 ألف', tag('رجع كله', K.green, K.greenSoft)),
        dep('فرقة الأفراح', 'عربون 100 ألف', tag('رجع كله', K.green, K.greenSoft)),
        dep('ضيافة الأصالة', 'عربون 300 ألف · وعدوا الأسبوع الجاي',
            softAction('ذكّرهم', fg: K.sky, bg: K.skySoft)),
      ]),
      gap(12),
      _note('سلفة خالي أحمد باقي منها 300 ألف. التذكير بالأقساط مستمر إلا إذا أوقفته.',
          c: K.saffronInk, bg: K.saffronSoft, i: LucideIcons.calendarClock),
    ],
  );
}
