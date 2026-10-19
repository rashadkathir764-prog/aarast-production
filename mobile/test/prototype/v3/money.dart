// Journey prototype v3: money, with the men's and women's sides and
// "in hand" kept apart from "promised".
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';

const _tabs = ['الملخص', 'البنود', 'الدفعات', 'من وين'];

Widget _head(int tab) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    tabHeader(
      'المال',
      'ماشية، بس ناقصك 2.5 مليون',
      actions: [LucideIcons.share2, LucideIcons.eyeOff],
    ),
    topTabs(_tabs, tab),
    gap(14),
  ],
);

Widget vMoneySummary() => Phone(
  nav: Sec.money,
  children: [
    _head(0),
    Box(
      pad: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'العرس بيكلفك ',
                  style: tx(17, c: K.muted),
                ),
                TextSpan(
                  text: '10 مليون',
                  style: tx(17, w: bold),
                ),
                TextSpan(
                  text: '، دفعت منها ',
                  style: tx(17, c: K.muted),
                ),
                TextSpan(
                  text: '4.6',
                  style: tx(17, w: bold, c: K.teal),
                ),
                TextSpan(
                  text: '.\nباقي ',
                  style: tx(17, c: K.muted),
                ),
                TextSpan(
                  text: '5.4',
                  style: tx(17, w: bold),
                ),
                TextSpan(
                  text: '. معك ',
                  style: tx(17, c: K.muted),
                ),
                TextSpan(
                  text: '2.9',
                  style: tx(17, w: bold, c: K.teal),
                ),
                TextSpan(
                  text: '، وموعود لك ',
                  style: tx(17, c: K.muted),
                ),
                TextSpan(
                  text: '1.2',
                  style: tx(17, w: bold, c: K.lilac),
                ),
                TextSpan(
                  text: '. ناقصك',
                  style: tx(17, c: K.muted),
                ),
              ],
            ),
            style: tx(17, h: 1.7),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '2.5 مليون',
                style: tx(34, w: bold, c: K.coral, h: 1.2),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'ومع الموعود 1.3',
                  style: tx(14, w: bold, c: K.muted),
                ),
              ),
            ],
          ),
          gap(14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(flex: 46, child: Container(color: K.teal)),
                  const SizedBox(width: 3),
                  Expanded(flex: 29, child: Container(color: K.tealMid)),
                  const SizedBox(width: 3),
                  Expanded(
                    flex: 12,
                    child: Container(color: const Color(0xFFB9A8DA)),
                  ),
                  const SizedBox(width: 3),
                  Expanded(flex: 13, child: Container(color: K.coral)),
                ],
              ),
            ),
          ),
          gap(10),
          Wrap(
            spacing: 14,
            children: [
              for (final l in const [
                (K.teal, 'دفعت'),
                (K.tealMid, 'معك'),
                (Color(0xFFB9A8DA), 'موعود'),
                (K.coral, 'ناقصك'),
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    dot(l.$1),
                    Text('  ${l.$2}', style: tx(13, c: K.muted)),
                  ],
                ),
            ],
          ),
        ],
      ),
    ),
    sectionTitle('وين تروح الفلوس'),
    Row(
      children: [
        for (final s in const [
          (
            'الاتفاق مع أهل العروسة',
            '3 مليون',
            'سلّمت 2',
            0.67,
            LucideIcons.heartHandshake,
          ),
          ('عرسك', '7 مليون', 'دفعت 2.6', 0.37, LucideIcons.building2),
        ]) ...[
          Expanded(
            child: Box(
              pad: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(s.$5, size: 16, color: K.teal),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          s.$1,
                          style: tx(12.5, w: bold, c: K.teal),
                        ),
                      ),
                    ],
                  ),
                  gap(8),
                  Text(s.$2, style: tx(19, w: bold)),
                  Text(s.$3, style: tx(12.5, c: K.muted)),
                  gap(8),
                  bar(s.$4, K.teal, h: 5),
                ],
              ),
            ),
          ),
          if (s.$2 == '3 مليون') const SizedBox(width: 10),
        ],
      ],
    ),
    sectionTitle('كيف تقفل الناقص؟', action: 'جرّب "لو"'),
    whiteList([
      listRow(
        icon: LucideIcons.target,
        fg: K.teal,
        soft: K.tealSoft,
        title: 'حط 450 ألف كل شهر',
        sub: 'ثلاثة أشهر لين العرس، ومع الموعود تقفله',
        trailing: const Icon(LucideIcons.chevronLeft, color: K.faint, size: 18),
      ),
      listRow(
        icon: LucideIcons.scissors,
        fg: K.saffronInk,
        soft: K.saffronSoft,
        title: 'خفّف بند',
        sub: 'الفنان 500 ألف، وفيه فرق بـ 350',
        trailing: const Icon(LucideIcons.chevronLeft, color: K.faint, size: 18),
      ),
      listRow(
        icon: LucideIcons.calendarClock,
        fg: K.lilac,
        soft: K.lilacSoft,
        title: 'سلفة بجدول سداد',
        sub: 'نذكرك بالأقساط بعد العرس',
        trailing: const Icon(LucideIcons.chevronLeft, color: K.faint, size: 18),
      ),
    ]),
  ],
);

class _It {
  const _It(this.n, this.i, this.t, this.p, {this.note});
  final String n;
  final IconData i;
  final double t, p;
  final String? note;
}

String _m(double v) {
  if (v == 0) return '0';
  if (v < 1) return '${(v * 1000).round()} ألف';
  return '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)} مليون';
}

Widget _itemRow(_It it) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  child: Row(
    children: [
      iconTile(it.i, K.teal, K.tealSoft, s: 40),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(it.n, style: tx(15, w: bold)),
                ),
                Text(_m(it.t), style: tx(15, w: bold)),
              ],
            ),
            gap(5),
            bar(it.p / it.t, it.p == it.t ? K.green : K.teal, h: 5),
            gap(4),
            Row(
              children: [
                Text(
                  it.p == it.t
                      ? 'خالص'
                      : it.p == 0
                      ? 'ما دفعت شيء'
                      : 'دفعت ${_m(it.p)}',
                  style: tx(
                    12,
                    w: it.p == it.t ? bold : FontWeight.w400,
                    c: it.p == it.t ? K.green : K.muted,
                  ),
                ),
                const Spacer(),
                if (it.note != null)
                  Text(
                    it.note!,
                    style: tx(12, w: bold, c: K.saffronInk),
                  ),
              ],
            ),
          ],
        ),
      ),
    ],
  ),
);

Widget _group(String title, String total, List<_It> items, {Widget? footer}) =>
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(title, style: tx(16, w: bold)),
              ),
              Text(
                total,
                style: tx(14, w: bold, c: K.muted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: card(),
          child: Column(
            children: [
              for (final (i, it) in items.indexed) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    indent: 66,
                    endIndent: 14,
                    color: K.line,
                  ),
                _itemRow(it),
              ],
              ?footer,
            ],
          ),
        ),
      ],
    );

Widget vMoneyItems() => Phone(
  nav: Sec.money,
  children: [
    _head(1),
    _group('الاتفاق مع أهل العروسة', '3 مليون', const [
      _It('المهر', LucideIcons.heart, 1.5, 1.5),
      _It(
        'الشرط',
        LucideIcons.heartHandshake,
        1.5,
        0.5,
        note: 'الباقي 15 نوفمبر',
      ),
    ]),
    _group('عرسك', '7 مليون', const [
      _It('القاعة', LucideIcons.building2, 2.0, 0.5, note: 'دفعة بعد 5 أيام'),
      _It('الضيافة والعشاء', LucideIcons.utensils, 1.6, 0.3),
      _It('القات', LucideIcons.leaf, 1.0, 0.8),
      _It('الذبائح', LucideIcons.beef, 1.0, 0.8),
      _It('التصوير', LucideIcons.camera, 0.6, 0, note: 'عرضين وصلوا'),
      _It('الفنان والفرقة', LucideIcons.music, 0.5, 0, note: 'ما انحجز'),
      _It('بدلة العريس', LucideIcons.shirt, 0.3, 0.2),
    ]),
    gap(12),
    Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('أضف بند', style: tx(15, w: bold)),
          gap(8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              chip('الذهب، إذا كان عليك', icon: LucideIcons.gem),
              chip('السيارات', icon: LucideIcons.car),
              chip('بند ثاني', icon: LucideIcons.plus),
            ],
          ),
        ],
      ),
    ),
  ],
);

Widget vMoneyPayments({bool offline = false}) {
  Widget upRow(
    String d,
    String m,
    String name,
    String amount,
    String sub, {
    bool soon = false,
    bool pending = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Container(
          width: 54,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: soon ? K.saffronSoft : K.bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                d,
                style: tx(19, w: bold, c: soon ? K.saffronInk : K.ink),
              ),
              Text(m, style: tx(11.5, c: K.muted)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: tx(15, w: bold)),
              Text(sub, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(amount, style: tx(15, w: bold)),
            if (pending)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.clock, size: 13, color: K.saffronInk),
                  Text(
                    ' ينتظر الإرسال',
                    style: tx(11.5, w: bold, c: K.saffronInk),
                  ),
                ],
              ),
          ],
        ),
      ],
    ),
  );
  final swiped = SizedBox(
    height: 80,
    child: Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: K.green,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'دفعتها',
                  style: tx(15, w: bold, c: Colors.white),
                ),
                const SizedBox(width: 6),
                const Icon(LucideIcons.check, color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          left: 96,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: K.ink.withValues(alpha: 0.08), blurRadius: 10),
              ],
            ),
            child: upRow('1', 'ديسمبر', 'بدلة العريس', '100 ألف', 'الباقي'),
          ),
        ),
      ],
    ),
  );
  return Phone(
    nav: Sec.money,
    bottom: offline ? undoBar('انحفظت دفعة القاعة · 500,000') : null,
    children: [
      if (offline) offlineBar(),
      _head(2),
      Box(
        c: K.tealSoft,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('خلال 30 يوم', style: tx(14, c: K.muted)),
                  Text(
                    '1.5 مليون ر.ي',
                    style: tx(24, w: bold, c: K.teal),
                  ),
                ],
              ),
            ),
            Text(
              'دفعتين',
              style: tx(15, w: bold, c: K.teal),
            ),
          ],
        ),
      ),
      sectionTitle('قادمة', action: 'اسحب الدفعة لما تدفعها'),
      whiteList([
        upRow(
          '22',
          'أكتوبر',
          'قاعة سبأ',
          '500 ألف',
          offline ? 'سجلتها الحين' : 'الثانية من ثلاث',
          soon: true,
          pending: offline,
        ),
        upRow('15', 'نوفمبر', 'باقي الشرط', 'مليون', 'لأهل العروسة'),
        upRow('20', 'ديسمبر', 'ضيافة الأصالة', '400 ألف', 'العربون الثاني'),
      ], dividers: false),
      gap(10),
      swiped,
    ],
  );
}

Widget vMoneyFunding() {
  Widget src(
    IconData i,
    Color fg,
    Color soft,
    String name,
    String note,
    String amount,
    bool got,
  ) => listRow(
    icon: i,
    fg: fg,
    soft: soft,
    title: name,
    sub: note,
    trailing: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(amount, style: tx(15, w: bold)),
        got
            ? tag('وصل', K.green, K.greenSoft)
            : tag('موعود', K.lilac, K.lilacSoft),
      ],
    ),
  );
  return Phone(
    nav: Sec.money,
    children: [
      _head(3),
      Row(
        children: [
          Expanded(
            child: Box(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('وصلك', style: tx(14, c: K.muted)),
                  Text(
                    '7.5 مليون',
                    style: tx(24, w: bold, c: K.teal),
                  ),
                  Text('صرفت 4.6 · معك 2.9', style: tx(12.5, c: K.muted)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Box(
              c: K.lilacSoft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('موعود لك', style: tx(14, c: K.muted)),
                  Text(
                    '1.2 مليون',
                    style: tx(24, w: bold, c: K.lilac),
                  ),
                  Text('ما نحسبه لين يوصل', style: tx(12.5, c: K.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
      sectionTitle('المصادر'),
      whiteList([
        src(
          LucideIcons.piggyBank,
          K.teal,
          K.tealSoft,
          'مدخراتي',
          'من راتبي',
          '4.5 مليون',
          true,
        ),
        src(
          LucideIcons.heartHandshake,
          K.teal,
          K.tealSoft,
          'دعم الوالد',
          'هدية',
          '2.4 مليون',
          true,
        ),
        src(
          LucideIcons.user,
          K.saffronInk,
          K.saffronSoft,
          'سلفة خالي أحمد',
          'أرده 4 أقساط بعد العرس',
          '600 ألف',
          true,
        ),
        src(
          LucideIcons.user,
          K.lilac,
          K.lilacSoft,
          'صاحبي عادل',
          'وعد قبل العرس · دين',
          '1.2 مليون',
          false,
        ),
      ]),
      gap(12),
      Box(
        c: K.saffronSoft,
        child: Row(
          children: [
            const Icon(LucideIcons.info, color: K.saffronInk, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'الرفد بعد العرس ينسجل في دفتر الرفد، وما نحسبه قبل ما يوصل.',
                style: tx(13.5, c: K.saffronInk),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget vPaySheet() => Phone(
  nav: Sec.money,
  sheet: sheet(
    title: 'دفعة القاعة',
    sub: 'قاعة سبأ · باقي عليك 1.5 مليون',
    children: [
      amountField('المبلغ', '500,000', 'خمسمية ألف ريال'),
      gap(10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('المتفق 500 ألف', on: true),
          chip('الباقي كامل'),
          chip('ر.ي', icon: LucideIcons.coins),
          chip('\$'),
          chip('ر.س'),
        ],
      ),
      gap(14),
      Row(
        children: [
          Expanded(
            child: field('متى', 'اليوم', icon: LucideIcons.calendarDays),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: field('من وين', 'مدخراتي', icon: LucideIcons.piggyBank),
          ),
        ],
      ),
      gap(14),
      Row(
        children: [
          const Icon(LucideIcons.camera, size: 18, color: K.teal),
          const SizedBox(width: 8),
          Text(
            'صوّر الإيصال',
            style: tx(15, w: bold, c: K.teal),
          ),
          const Spacer(),
          const Icon(LucideIcons.lock, size: 16, color: K.muted),
          const SizedBox(width: 6),
          Text('خاصة بي', style: tx(14, c: K.muted)),
          const SizedBox(width: 8),
          Container(
            width: 42,
            height: 26,
            padding: const EdgeInsets.all(3),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: K.line,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
      gap(16),
      btn('حفظ الدفعة', wide: true, v: 16, fs: 17),
    ],
  ),
  children: [_head(0)],
);

Widget vItemDetail() {
  Widget step(String d, String what, String amount, int state) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state == 2 ? K.green : (state == 1 ? K.saffronSoft : K.bg),
            border: state == 1 ? Border.all(color: K.saffron, width: 2) : null,
          ),
          child: state == 2
              ? const Icon(LucideIcons.check, size: 15, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                what,
                style: tx(15, w: bold, c: state == 2 ? K.muted : K.ink),
              ),
              Text(d, style: tx(12.5, c: state == 1 ? K.saffronInk : K.muted)),
            ],
          ),
        ),
        Text(
          amount,
          style: tx(15, w: bold, c: state == 2 ? K.muted : K.ink),
        ),
      ],
    ),
  );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: btn('سجّل الدفعة الثانية', wide: true, v: 16, fs: 17),
    ),
    children: [
      subHeader(
        'القاعة',
        sub: 'قاعة سبأ',
        trailing: const Icon(LucideIcons.moreHorizontal, color: K.muted),
      ),
      Box(
        pad: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الاتفاق', style: tx(13.5, c: K.muted)),
                      Text('2,000,000 ر.ي', style: tx(26, w: bold)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('باقي', style: tx(13.5, c: K.muted)),
                    Text(
                      '1.5 مليون',
                      style: tx(20, w: bold, c: K.coral),
                    ),
                  ],
                ),
              ],
            ),
            gap(12),
            bar(0.25, K.teal, h: 8),
            gap(10),
            Text(
              'الخميس 21 يناير · 150 مقعد · من عرض مقبول في اعّرست',
              style: tx(13, c: K.muted),
            ),
          ],
        ),
      ),
      sectionTitle('جدول الدفعات'),
      Box(
        pad: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            step('10 سبتمبر · نقدًا', 'العربون', '500 ألف', 2),
            step('بعد 5 أيام · 22 أكتوبر', 'الدفعة الثانية', '500 ألف', 1),
            step('يوم العرس', 'الباقي', '1 مليون', 0),
          ],
        ),
      ),
      sectionTitle('الإيصالات', action: 'أضف'),
      Row(
        children: [
          for (final c in const [Color(0xFFE6ECEB), Color(0xFFEDE7DF)]) ...[
            Container(
              width: 92,
              height: 112,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(LucideIcons.receipt, color: K.faint, size: 30),
            ),
            const SizedBox(width: 10),
          ],
          Container(
            width: 92,
            height: 112,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: K.line, width: 2),
            ),
            child: const Icon(LucideIcons.camera, color: K.teal, size: 26),
          ),
        ],
      ),
      gap(12),
      whiteList([
        listRow(
          icon: LucideIcons.messageCircle,
          fg: K.sky,
          soft: K.skySoft,
          title: 'محادثة قاعة سبأ',
          sub: 'آخر رسالة: نأكد عدد المقاعد قبل شهر',
          trailing: const Icon(
            LucideIcons.chevronLeft,
            color: K.faint,
            size: 18,
          ),
        ),
      ]),
    ],
  );
}

Widget vWhatIf() {
  Widget slider(String name, String from, String to, double v, String save) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name, style: tx(15.5, w: bold)),
                ),
                Text(
                  from,
                  style: tx(
                    13,
                    c: K.faint,
                  ).copyWith(decoration: TextDecoration.lineThrough),
                ),
                const SizedBox(width: 8),
                Text(
                  to,
                  style: tx(15, w: bold, c: K.teal),
                ),
              ],
            ),
            gap(10),
            Stack(
              alignment: Alignment.centerRight,
              children: [
                bar(v, K.teal, h: 6),
                FractionallySizedBox(
                  widthFactor: v,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: K.teal, width: 3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            gap(6),
            Text(
              save,
              style: tx(12.5, w: bold, c: K.green),
            ),
          ],
        ),
      );
  return Phone(
    bottom: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
      child: btn('طبّق التغييرات على البنود', wide: true, v: 16, fs: 17),
    ),
    children: [
      subHeader('لو خففت…', sub: 'حرّك وشوف الناقص كيف يتغير'),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(colors: [K.teal, K.tealDark]),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ناقصك يصير', style: tx(14, c: Colors.white70)),
                  Text(
                    '1.9 مليون',
                    style: tx(32, w: bold, c: Colors.white),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('كان 2.5', style: tx(14, c: Colors.white70)),
                tag('وفرت 570 ألف', K.ink, K.saffron),
              ],
            ),
          ],
        ),
      ),
      gap(14),
      Container(
        decoration: card(),
        child: Column(
          children: [
            slider('عدد الضيوف', '124', '100', 0.8, 'الضيافة تقل 240 ألف'),
            const Divider(height: 1, color: K.line),
            slider('الفنان والفرقة', '500 ألف', '350 ألف', 0.7, 'وفرت 150 ألف'),
            const Divider(height: 1, color: K.line),
            slider('القات', '1 مليون', '820 ألف', 0.82, 'وفرت 180 ألف'),
          ],
        ),
      ),
      gap(12),
      Box(
        c: K.tealSoft,
        child: Row(
          children: [
            const Icon(LucideIcons.info, color: K.teal, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'ما يتغير شيء لين تضغط "طبّق". جرّب براحتك.',
                style: tx(13.5, w: bold, c: K.tealDark),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
