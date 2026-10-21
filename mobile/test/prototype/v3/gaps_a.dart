// Journey prototype v3: the gaps the logic audit found, part one. Account
// and sign-in edges, the plan's whole life (edit, switch, date passed,
// archive, delete) and the participant's permissions and invite states.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';

// ------------------------------------------------------------ shared bits

Widget gNote(String s, {Color c = K.teal, Color bg = K.tealSoft, IconData i = LucideIcons.info}) =>
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

Widget gEffect(IconData i, String s, {Color c = K.muted}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 7),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(i, size: 18, color: c),
      const SizedBox(width: 10),
      Expanded(child: Text(s, style: tx(14.5, h: 1.45))),
    ],
  ),
);

Widget gToggle(bool on) => Container(
  width: 46,
  height: 28,
  padding: const EdgeInsets.all(3),
  alignment: on ? Alignment.centerLeft : Alignment.centerRight,
  decoration: BoxDecoration(
    color: on ? K.teal : K.line,
    borderRadius: BorderRadius.circular(999),
  ),
  child: Container(
    width: 22,
    height: 22,
    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
  ),
);

Widget gOption(String s, {String? sub, bool on = false, Color c = K.teal}) => Container(
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

/// Six code cells, as the WhatsApp code has six digits.
Widget gCode(List<String> d, {bool error = false, int at = -1}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      for (var i = 0; i < 6; i++)
        Container(
          width: 50,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: error ? K.coralSoft : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: error ? K.coral : (i == at ? K.teal : K.line),
              width: error || i == at ? 2 : 1,
            ),
          ),
          child: Text(i < d.length ? d[i] : '', style: tx(24, w: bold, c: error ? K.coral : K.ink)),
        ),
    ],
  ),
);

Widget gBottom(Widget child) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
  child: child,
);

Widget gFieldError(String label, String value, String error, {IconData? icon}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: K.coral, width: 2),
      ),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 20, color: K.coral), const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tx(12.5, c: K.coral)),
                Text(value, style: tx(17, w: bold)),
              ],
            ),
          ),
        ],
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle, size: 15, color: K.coral),
          const SizedBox(width: 6),
          Expanded(child: Text(error, style: tx(13, w: bold, c: K.coral))),
        ],
      ),
    ),
  ],
);

Widget _steps(List<String> labels, int at) => Container(
  padding: const EdgeInsets.all(6),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: K.line),
  ),
  child: Row(
    children: [
      for (var i = 0; i < labels.length; i++)
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

// ============================================================ الرمز

/// The WhatsApp code screen with six cells, used for sign-up and sign-in.
Widget vOtp6() => Phone(
  children: [
    subHeader(''),
    gap(8),
    Text('أرسلنا لك رمز على واتساب', style: tx(28, w: bold)),
    gap(4),
    Row(
      children: [
        Text('إلى الرقم ${ltr('+967 777 123 456')}', style: tx(15, c: K.muted)),
        const SizedBox(width: 8),
        Text('تغيير', style: tx(15, w: bold, c: K.teal)),
      ],
    ),
    gap(30),
    gCode(['4', '8', '2'], at: 3),
    gap(24),
    Center(child: Text('ما وصلك؟ نعيد الإرسال بعد ${ltr('0:42')}', style: tx(15, c: K.muted))),
    gap(34),
    Box(
      c: K.tealSoft,
      child: Row(
        children: [
          const Icon(LucideIcons.checkCircle2, color: K.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text('أول ما يكتمل الرمز تنحفظ خطتك وتدخل عليها.',
                style: tx(14.5, c: K.tealDark)),
          ),
        ],
      ),
    ),
  ],
);

// ============================================================ الحساب

Widget vForgotPassword() => Phone(
  bottom: gBottom(btn('حفظ وتسجيل الدخول', wide: true, v: 16, fs: 17)),
  children: [
    subHeader('نسيت كلمة المرور'),
    _steps(const ['رقمك', 'الرمز', 'كلمة جديدة'], 2),
    gap(18),
    Text('اختر كلمة مرور جديدة', style: tx(24, w: bold)),
    gap(4),
    Text('تأكدنا إنه رقمك. خطتك وكل بياناتك كما هي.', style: tx(15, c: K.muted)),
    gap(18),
    field('كلمة المرور الجديدة', '••••••••', icon: LucideIcons.lock, focused: true),
    gap(10),
    field('أعد كتابتها', '••••••••', icon: LucideIcons.lock),
    gap(10),
    Row(
      children: [
        const Icon(LucideIcons.checkCircle2, size: 16, color: K.green),
        const SizedBox(width: 6),
        Text('6 أحرف أو أكثر', style: tx(13, w: bold, c: K.green)),
      ],
    ),
    gap(18),
    gNote('بنطلعك من الأجهزة الثانية، احتياط لو أحد عرف كلمتك القديمة.',
        i: LucideIcons.shieldCheck),
  ],
);

Widget vRegisterErrors() => Phone(
  bottom: gBottom(btn('إنشاء حساب', wide: true, v: 16, fs: 17, bg: K.faint)),
  children: [
    subHeader('احفظ خطتك'),
    field('اسمك', 'محمد الحمدي'),
    gap(10),
    gFieldError('رقم الهاتف', ltr('+967 777 123 456'), 'هذا الرقم عليه حساب من قبل', icon: LucideIcons.phone),
    gap(10),
    Box(
      pad: const EdgeInsets.all(14),
      child: Row(
        children: [
          iconTile(LucideIcons.logIn, K.teal, K.tealSoft, s: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('هذا حسابك؟', style: tx(15.5, w: bold)),
                Text('ادخل عليه، وخطتك اللي على الجهاز نسألك عنها بعدها',
                    style: tx(12.5, c: K.muted)),
              ],
            ),
          ),
          softAction('ادخل'),
        ],
      ),
    ),
    gap(14),
    gFieldError('كلمة المرور', '•••', 'قصيرة. خلّها 6 أحرف أو أكثر', icon: LucideIcons.lock),
  ],
);

Widget vWhatsappMissing() => Phone(
  sheet: sheet(
    title: 'الرمز ما وصل؟',
    sub: 'نرسله على واتساب فقط، وهذا اللي تقدر تسويه',
    children: [
      Box(
        pad: const EdgeInsets.all(14),
        child: Column(
          children: [
            gEffect(LucideIcons.smartphone, 'تأكد إن واتساب شغّال على ${ltr('+967 777 123 456')}'),
            gEffect(LucideIcons.wifi, 'تأكد إن النت واصل للجوال'),
            gEffect(LucideIcons.archive, 'شوف المحادثات المؤرشفة في واتساب'),
          ],
        ),
      ),
      gap(12),
      btn('أعد الإرسال بعد ${ltr('0:42')}', wide: true, v: 15, bg: K.line, fg: K.muted),
      gap(10),
      btn('الدخول بكلمة المرور', wide: true, v: 15, bg: K.tealSoft, fg: K.teal, icon: LucideIcons.lock),
      gap(10),
      Center(child: Text('الرقم غلط؟ غيّره', style: tx(14, w: bold, c: K.teal))),
      gap(10),
      gNote('بعد 5 محاولات غلط نوقف الرموز 15 دقيقة، حماية لحسابك.',
          c: K.saffronInk, bg: K.saffronSoft, i: LucideIcons.clock),
    ],
  ),
  children: [subHeader(''), gap(8), Text('أرسلنا لك رمز على واتساب', style: tx(28, w: bold))],
);

Widget vDevices() {
  Widget d(IconData i, String t, String s, Widget end) => listRow(
    icon: i, fg: K.teal, soft: K.tealSoft, title: t, sub: s, trailing: end,
  );
  return Phone(
    children: [
      subHeader('الأجهزة', sub: 'وين حسابك مفتوح'),
      whiteList([
        d(LucideIcons.smartphone, 'هذا الجوال', 'سامسونج · صنعاء · الآن', tag('أنت هنا', K.green, K.greenSoft)),
        d(LucideIcons.smartphone, 'آيفون', 'الرياض · قبل 3 أيام', softAction('اطلع', fg: K.coral, bg: K.coralSoft)),
        d(LucideIcons.tablet, 'تابلت', 'صنعاء · قبل شهر', softAction('اطلع', fg: K.coral, bg: K.coralSoft)),
      ]),
      gap(14),
      btn('اطلع من كل الأجهزة الثانية', wide: true, v: 15, bg: K.coralSoft, fg: K.coral, icon: LucideIcons.logOut),
      gap(12),
      gNote('ما تعرف جهاز منها؟ اطلعه وغيّر كلمة المرور.', i: LucideIcons.shieldAlert,
          c: K.saffronInk, bg: K.saffronSoft),
    ],
  );
}

Widget vDeleteAccount() => Phone(
  bottom: gBottom(btn('احذف حسابي', wide: true, v: 16, fs: 17, bg: K.coral)),
  children: [
    subHeader('حذف الحساب'),
    Center(child: iconTile(LucideIcons.userX, K.coral, K.coralSoft, s: 76, r: 24)),
    gap(14),
    Center(child: Text('متأكد يا محمد؟', style: tx(24, w: bold))),
    gap(12),
    Box(
      child: Column(
        children: [
          gEffect(LucideIcons.trash2, 'خطتك ومالك ومهامك وضيوفك تنحذف كلها', c: K.coral),
          gEffect(LucideIcons.users, 'صالح والوالد يطلعون من الخطة، ويوصلهم إشعار', c: K.coral),
          gEffect(LucideIcons.store, 'الحجوزات المؤكدة تنلغي، ونبلّغ المزودين', c: K.coral),
          gEffect(LucideIcons.clock, 'عندك 30 يوم ترجع فيها لو غيّرت رأيك', c: K.teal),
        ],
      ),
    ),
    gap(12),
    Box(
      pad: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(LucideIcons.download, size: 20, color: K.teal),
          const SizedBox(width: 10),
          Expanded(child: Text('نزّل نسخة من خطتك قبل الحذف', style: tx(15, w: bold))),
          softAction('نزّلها'),
        ],
      ),
    ),
    gap(14),
    field('اكتب «حذف» للتأكيد', 'حذف', focused: true),
  ],
);

Widget vDeletePending() => Phone(
  children: [
    gap(30),
    Center(child: iconTile(LucideIcons.hourglass, K.saffronInk, K.saffronSoft, s: 80, r: 26)),
    gap(18),
    Center(child: Text('حسابك ينحذف بعد 27 يوم', style: tx(24, w: bold))),
    gap(6),
    Center(
      child: Text('طلبت الحذف 19 أكتوبر. لين 18 نوفمبر تقدر ترجع وكل شيء كما هو.',
          textAlign: TextAlign.center, style: tx(15, c: K.muted, h: 1.5)),
    ),
    gap(24),
    btn('تراجعت، رجّع حسابي', wide: true, v: 16, fs: 17),
    gap(10),
    btn('اطلع', wide: true, v: 15, bg: K.surface, fg: K.muted),
    gap(16),
    gNote('ما أحد يقدر يدخل خطتك خلال هذي المدة، ولا توصلك تذكيرات.', i: LucideIcons.lock),
  ],
);

Widget _pinDots(int filled, {bool error = false}) => Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    for (var i = 0; i < 4; i++)
      Container(
        width: 18,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: i < filled ? (error ? K.coral : K.teal) : Colors.transparent,
          border: Border.all(color: error ? K.coral : K.teal, width: 2),
        ),
      ),
  ],
);

Widget _pinPad({bool dim = false}) {
  Widget k(String s) => Container(
    width: 74,
    height: 62,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: dim ? K.line : Colors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: s == 'del'
        ? Icon(LucideIcons.delete, size: 24, color: dim ? K.faint : K.ink)
        : Text(s, style: tx(26, w: bold, c: dim ? K.faint : K.ink, f: fPlex)),
  );
  Widget row(List<String> s) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (final x in s) k(x)]),
  );
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Column(
      children: [
        row(['1', '2', '3']),
        row(['4', '5', '6']),
        row(['7', '8', '9']),
        row(['', '0', 'del']),
      ],
    ),
  );
}

Widget vPinEntry() => Phone(
  children: [
    gap(30),
    Center(child: wordmark(s: 30)),
    gap(20),
    Center(child: avatar('م', K.saffron, s: 60)),
    gap(12),
    Center(child: Text('أدخل رمز القفل', style: tx(22, w: bold))),
    gap(20),
    _pinDots(2),
    gap(30),
    _pinPad(),
    Center(child: Text('نسيت الرمز؟', style: tx(14.5, w: bold, c: K.teal))),
  ],
);

Widget vPinWrong() => Phone(
  children: [
    gap(30),
    Center(child: wordmark(s: 30)),
    gap(20),
    Center(child: avatar('م', K.saffron, s: 60)),
    gap(12),
    Center(child: Text('الرمز غلط 5 مرات', style: tx(22, w: bold, c: K.coral))),
    gap(4),
    Center(child: Text('جرّب مرة ثانية بعد ${ltr('0:30')}', style: tx(15, c: K.muted))),
    gap(20),
    _pinDots(4, error: true),
    gap(30),
    _pinPad(dim: true),
    gNote('نسيت الرمز؟ ادخل بكلمة المرور أو برمز واتساب، والقفل ينشال وتختار رمز جديد.',
        i: LucideIcons.keyRound),
  ],
);

/// A plan drafted on this phone before signing in to an account that already
/// has one.
Widget vLocalDraft() => Phone(
  sheet: sheet(
    title: 'عندك خطة على هذا الجوال',
    sub: 'سويتها قبل ما تدخل. وحسابك فيه خطة من قبل.',
    children: [
      Row(
        children: [
          Expanded(
            child: Box(
              pad: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('على الجوال', style: tx(12.5, c: K.muted)),
                  Text('5 بنود · 8 مهام', style: tx(15, w: bold)),
                  Text('آخر تعديل اليوم', style: tx(12, c: K.muted)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Box(
              pad: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('في حسابك', style: tx(12.5, c: K.muted)),
                  Text('14 بند · 23 مهمة', style: tx(15, w: bold)),
                  Text('آخر تعديل 2 أكتوبر', style: tx(12, c: K.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
      gap(14),
      gOption('ضمّها لخطتي', sub: 'البنود والمهام تنضاف، والمكرر نوريك إياه', on: true),
      gOption('خلّها خطة ثانية', sub: 'مثلًا لو هي لعرس أخوك'),
      gOption('تجاهلها', sub: 'تنحذف من الجوال بس'),
      gap(8),
      btn('متابعة', wide: true, v: 16, fs: 17),
    ],
  ),
  children: [gap(40), Center(child: wordmark(s: 34))],
);

// ============================================================ الخطة

Widget vEditPlan() => Phone(
  bottom: gBottom(btn('حفظ', wide: true, v: 16, fs: 17)),
  children: [
    subHeader('بيانات الخطة'),
    field('اسم الخطة', 'عرس محمد'),
    gap(10),
    field('موعد العرس', 'الخميس 21 يناير 2027', icon: LucideIcons.calendarDays, focused: true),
    gap(8),
    Row(
      children: [
        chip('غيّر الموعد', on: true, fs: 13),
        const SizedBox(width: 8),
        chip('موعد تقريبي', fs: 13),
        const SizedBox(width: 8),
        chip('ما حددنا', fs: 13),
      ],
    ),
    gap(12),
    field('المحافظة والمديرية', 'صنعاء · السبعين', icon: LucideIcons.mapPin),
    gap(10),
    field('العملة', 'ريال يمني (صنعاء)', icon: LucideIcons.coins),
    gap(10),
    field('ميزانية عرسك (بدون المهر)', '7 مليون', suffix: 'ر.ي'),
    gap(14),
    gNote('لو غيّرت الموعد، المهام والأقساط تتحرك معه، ونسألك قبل ما نبلّغ المزودين.',
        i: LucideIcons.calendarClock),
  ],
);

Widget vPlanSwitcher() {
  Widget p(Color c, String l, String t, String sub, Widget end, {bool on = false}) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: on ? K.teal : K.line, width: on ? 2 : 1),
    ),
    child: Row(
      children: [
        avatar(l, c, s: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(t, style: tx(15.5, w: bold)), Text(sub, style: tx(12.5, c: K.muted))],
          ),
        ),
        end,
      ],
    ),
  );
  return Phone(
    sheet: sheet(
      title: 'خططك',
      children: [
        p(K.teal, 'م', 'عرس محمد', 'خطتك · 96 يوم', tag('مفتوحة', K.teal, K.tealSoft), on: true),
        p(K.saffronInk, 'ص', 'عرس صالح', 'أنت مساعد · مارس', tag('مساعد', K.saffronInk, K.saffronSoft)),
        p(K.faint, 'ع', 'عرس عادل', 'في الذكريات · 2025', tag('مؤرشفة', K.muted, K.line)),
        gap(6),
        btn('خطة جديدة', wide: true, v: 14, bg: K.tealSoft, fg: K.teal, icon: LucideIcons.plus),
        gap(10),
        gNote('تقدر تفتح أكثر من خطة، مثلًا لعرس أخوك. وكل خطة بمشاركينها وفلوسها.'),
      ],
    ),
    children: [gap(20)],
  );
}

Widget vDatePassed() => Phone(
  sheet: sheet(
    title: 'مبروك! تم العرس؟',
    sub: 'موعده كان الخميس 21 يناير',
    children: [
      gOption('إيه، تم العرس', sub: 'تنتقل الخطة لوضع "بعد العرس": الرفد والشكر والتقييم', on: true),
      gOption('تأجل', sub: 'اختر موعد جديد، والمهام والأقساط تتحرك'),
      gOption('ما صار، أوقف الخطة', sub: 'كل شيء ينحفظ وترجع متى ما تشتي'),
      gap(8),
      btn('متابعة', wide: true, v: 16, fs: 17),
      gap(10),
      Center(child: Text('اسألني بكرة', style: tx(14, w: bold, c: K.muted))),
    ],
  ),
  children: [gap(20)],
);

Widget vArchivePlan() => Phone(
  sheet: sheet(
    title: 'حط الخطة في الذكريات',
    sub: 'بعد ما يخلص كل شيء. تقدر ترجعها أي وقت.',
    children: [
      Box(
        pad: const EdgeInsets.all(14),
        child: Column(
          children: [
            gEffect(LucideIcons.eye, 'كل شيء يبقى تشوفه: المال والرفد والصور والضيوف', c: K.teal),
            gEffect(LucideIcons.gem, 'الرفد المتأخر تقدر تسجله، والشكر ترسله', c: K.teal),
            gEffect(LucideIcons.bellOff, 'التذكيرات توقف، إلا أقساط السلف'),
            gEffect(LucideIcons.users, 'المشاركين يشوفونها للقراءة بس'),
          ],
        ),
      ),
      gap(12),
      gNote('باقي عليك 300 ألف لخالي أحمد. تذكير القسط مستمر لين تخلّصه.',
          c: K.saffronInk, bg: K.saffronSoft, i: LucideIcons.banknote),
      gap(14),
      btn('حطها في الذكريات', wide: true, v: 16, fs: 17, icon: LucideIcons.archive),
    ],
  ),
  children: [subHeader('حسابي')],
);

Widget vArchivedView() => Phone(
  nav: Sec.home,
  children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          Expanded(child: Text('عرس محمد', style: tx(24, w: bold))),
          avatar('م', K.saffron, s: 44),
        ],
      ),
    ),
    gap(12),
    Box(
      c: K.line,
      pad: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(LucideIcons.archive, size: 20, color: K.muted),
          const SizedBox(width: 10),
          Expanded(child: Text('في الذكريات من 15 فبراير', style: tx(15, w: bold, c: K.muted))),
          softAction('رجّعها'),
        ],
      ),
    ),
    gap(12),
    Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الخميس 21 يناير 2027', style: tx(13, c: K.muted)),
          Text('الحمد لله على التمام', style: tx(22, w: bold)),
          gap(12),
          Row(
            children: [
              for (final s in const [('9.6 مليون', 'المصروف'), ('118', 'حضروا'), ('1.8 مليون', 'الرفد')])
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(s.$1, style: tx(18, w: bold)), Text(s.$2, style: tx(12.5, c: K.muted))],
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
    gap(12),
    whiteList([
      listRow(icon: LucideIcons.gem, fg: K.teal, soft: K.tealSoft, title: 'سجّل رفد وصل متأخر', sub: 'الدفتر مفتوح دايم'),
      listRow(icon: LucideIcons.heartHandshake, fg: K.lilac, soft: K.lilacSoft, title: 'الشكر', sub: '38 باقي ما وصلهم شكر'),
      listRow(icon: LucideIcons.download, fg: K.sky, soft: K.skySoft, title: 'نزّل ملخص العرس', sub: 'PDF فيه كل شيء'),
    ]),
  ],
);

Widget vDeletePlan() => Phone(
  bottom: gBottom(btn('احذف الخطة نهائيًا', wide: true, v: 16, fs: 17, bg: K.coral)),
  children: [
    subHeader('حذف الخطة'),
    Center(child: iconTile(LucideIcons.trash2, K.coral, K.coralSoft, s: 76, r: 24)),
    gap(14),
    Center(child: Text('حذف "عرس محمد"', style: tx(24, w: bold))),
    gap(4),
    Center(child: Text('ما ترجع بعدها. حسابك يبقى.', style: tx(15, c: K.muted))),
    gap(14),
    Box(
      child: Column(
        children: [
          gEffect(LucideIcons.wallet, 'المال والإيصالات والرفد', c: K.coral),
          gEffect(LucideIcons.listChecks, '20 مهمة و124 ضيف', c: K.coral),
          gEffect(LucideIcons.users, 'صالح والوالد يطلعون ويوصلهم إشعار', c: K.coral),
          gEffect(LucideIcons.store, 'حجزين مؤكدين ينلغون، ونبلّغ المزودين', c: K.coral),
        ],
      ),
    ),
    gap(12),
    gNote('تشتي ترتاح فترة؟ أوقف الخطة بدل الحذف، أو حطها في الذكريات.',
        i: LucideIcons.pauseCircle),
    gap(14),
    field('اكتب اسم الخطة للتأكيد', 'عرس محمد', focused: true),
  ],
);

// ============================================================ المشاركين

/// Adding a participant: a ready role, then each section's level.
Widget vAddParticipant2() {
  Widget lvl(IconData i, String s, int on, {List<String> o = const ['لا', 'يشوف', 'يعدّل']}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(i, size: 19, color: K.teal),
        const SizedBox(width: 10),
        Expanded(child: Text(s, style: tx(15, w: bold))),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: K.line, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              for (var j = 0; j < o.length; j++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: j == on ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(o[j], style: tx(12.5, w: bold, c: j == on ? K.teal : K.muted)),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    sheet: sheet(
      title: 'أضف صالح',
      sub: ltr('771 554 220'),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip('مساعد', on: true, fs: 13),
            chip('أهل', fs: 13),
            chip('كاتب الرفد', fs: 13),
            chip('يشوف بس', fs: 13),
            chip('العروسة', fs: 13),
          ],
        ),
        gap(12),
        Box(
          pad: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              lvl(LucideIcons.listChecks, 'المهام', 2),
              lvl(LucideIcons.users, 'الضيوف', 2),
              lvl(LucideIcons.store, 'المزودين', 0),
              lvl(LucideIcons.wallet, 'المال', 0),
              lvl(LucideIcons.gem, 'الرفد', 1, o: const ['لا', 'يكتب']),
            ],
          ),
        ),
        gap(10),
        gNote('الموعد والبرنامج يشوفه كل مشارك. "المال: يشوف" يعني المجاميع بدون مصادر الفلوس والسلف.',
            i: LucideIcons.lock),
        gap(12),
        btn('أرسل الدعوة على واتساب', wide: true, v: 16, fs: 17, icon: LucideIcons.send),
      ],
    ),
    children: [subHeader('المشاركين')],
  );
}

Widget vInviteStates() {
  Widget st(IconData i, Color c, Color soft, String t, String s, String act) => Container(
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
              gap(10),
              softAction(act, fg: c, bg: soft),
            ],
          ),
        ),
      ],
    ),
  );
  return Phone(
    children: [
      subHeader('الدعوة', sub: 'لما الرابط ما يفتح'),
      st(LucideIcons.clock, K.saffronInk, K.saffronSoft, 'الدعوة انتهت',
          'الرابط يشتغل 7 أيام. محمد يقدر يرسل لك واحد جديد.', 'اطلب دعوة جديدة من محمد'),
      st(LucideIcons.xCircle, K.coral, K.coralSoft, 'الدعوة انلغت',
          'محمد لغاها. إذا تشوفها غلط، كلّمه.', 'كلّم محمد على واتساب'),
      st(LucideIcons.phoneOff, K.sky, K.skySoft, 'الدعوة لرقم ثاني',
          'وصلت لـ ${ltr('771 554 220')} وأنت داخل بـ ${ltr('+967 777 123 456')}.', 'ادخل بالرقم المدعو'),
      st(LucideIcons.checkCircle2, K.green, K.greenSoft, 'أنت معهم من قبل',
          'قبلت هذي الدعوة 3 أكتوبر.', 'افتح عرس محمد'),
    ],
  );
}
