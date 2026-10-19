// Journey prototype: the money tab.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'kit.dart';

const moneyTabs = ['الملخص', 'البنود', 'الدفعات', 'من وين'];

Widget _moneyHead(int tab) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    tabHeader(
      'المال',
      'ماشية تمام، بس ناقصك 1.3 مليون',
      actions: [LucideIcons.eyeOff, LucideIcons.plus],
    ),
    topTabs(moneyTabs, tab),
    gap(14),
  ],
);

Widget moneySummary() => Phone(
  nav: Sec.money,
  children: [
    _moneyHead(0),
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
                  text: '.\nدفعت ',
                  style: tx(17, c: K.muted),
                ),
                TextSpan(
                  text: '4.6',
                  style: tx(17, w: bold, c: K.teal),
                ),
                TextSpan(
                  text: '، وباقي ',
                  style: tx(17, c: K.muted),
                ),
                TextSpan(
                  text: '5.4',
                  style: tx(17, w: bold),
                ),
                TextSpan(
                  text: '.\nمعك ',
                  style: tx(17, c: K.muted),
                ),
                TextSpan(
                  text: '4.1',
                  style: tx(17, w: bold, c: K.teal),
                ),
                TextSpan(
                  text: '، يعني ناقصك',
                  style: tx(17, c: K.muted),
                ),
              ],
            ),
            style: tx(17, h: 1.7),
          ),
          Text(
            '1.3 مليون ر.ي',
            style: tx(34, w: bold, c: K.coral, h: 1.2),
          ),
          gap(14),
          moneyBar(0.46, 0.41, 0.13, h: 12),
          gap(10),
          Row(
            children: [
              dot(K.teal),
              Text('  دفعت', style: tx(13, c: K.muted)),
              const SizedBox(width: 14),
              dot(K.tealMid),
              Text('  معك', style: tx(13, c: K.muted)),
              const SizedBox(width: 14),
              dot(K.coral),
              Text('  ناقصك', style: tx(13, c: K.muted)),
            ],
          ),
        ],
      ),
    ),
    gap(12),
    nextCard(
      eyebrow: 'الخطوة الجاية · بعد 5 أيام',
      title: 'دفعة القاعة: 500,000 ر.ي',
      sub: 'قاعة سبأ · الدفعة الثانية من ثلاث',
      action: 'سجّل الدفعة',
      second: 'ذكّرني',
      why: 'لأن موعدها قريب، والمبلغ في مدخراتك',
    ),
    sectionTitle('كيف تقفل الناقص؟'),
    whiteList([
      listRow(
        icon: LucideIcons.scissors,
        fg: K.teal,
        soft: K.tealSoft,
        title: 'خفّف بند',
        sub: 'الكوشة والزينة 300 ألف، فيه باقات بـ 180',
        trailing: const Icon(LucideIcons.chevronLeft, color: K.faint, size: 18),
      ),
      listRow(
        icon: LucideIcons.heartHandshake,
        fg: K.lilac,
        soft: K.lilacSoft,
        title: 'سجّل مساعدة موعودة',
        sub: 'من أهلك أو أصحابك، ونحسبها لما توصل',
        trailing: const Icon(LucideIcons.chevronLeft, color: K.faint, size: 18),
      ),
      listRow(
        icon: LucideIcons.calendarClock,
        fg: K.saffronInk,
        soft: K.saffronSoft,
        title: 'سلفة بجدول سداد',
        sub: 'نذكرك بالأقساط بعد العرس',
        trailing: const Icon(LucideIcons.chevronLeft, color: K.faint, size: 18),
      ),
    ]),
    gap(10),
    Box(
      c: K.saffronSoft,
      child: Row(
        children: [
          const Icon(LucideIcons.info, color: K.saffronInk, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'الرفد المتوقع ما نحسبه لين يوصل فعلًا، عشان الأرقام تبقى صادقة.',
              style: tx(13.5, c: K.saffronInk),
            ),
          ),
        ],
      ),
    ),
  ],
);

class _Item {
  const _Item(this.name, this.icon, this.total, this.paid, {this.note});
  final String name;
  final IconData icon;
  final double total, paid;
  final String? note;
}

const _items = [
  _Item('المهر', LucideIcons.heart, 2.0, 2.0),
  _Item('الذهب والشبكة', LucideIcons.gem, 1.8, 1.2),
  _Item('القاعة', LucideIcons.building2, 2.0, 0.5, note: 'دفعة بعد 5 أيام'),
  _Item('الضيافة والعشاء', LucideIcons.utensils, 1.2, 0.3),
  _Item('الكسوة والملابس', LucideIcons.shirt, 0.8, 0.4),
  _Item('التصوير', LucideIcons.camera, 0.6, 0, note: 'عرضين وصلوا'),
  _Item('القات', LucideIcons.leaf, 0.5, 0),
  _Item('الفرقة', LucideIcons.music, 0.4, 0, note: 'ما انحجزت'),
  _Item('الغداء', LucideIcons.soup, 0.4, 0.2),
  _Item('الكوشة والزينة', LucideIcons.sparkles, 0.3, 0),
];

String _m(double v) {
  if (v == 0) return '0';
  if (v < 1) return '${(v * 1000).round()} ألف';
  return '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)} مليون';
}

Widget moneyItems() => Phone(
  nav: Sec.money,
  children: [
    _moneyHead(1),
    Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
      child: Row(
        children: [
          Text('10 بنود · 10 مليون', style: tx(15, w: bold)),
          const Spacer(),
          Text('اضغط المبلغ تعدّله', style: tx(13, c: K.muted)),
        ],
      ),
    ),
    Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: card(),
      child: Column(
        children: [
          for (final (i, it) in _items.indexed) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 70,
                endIndent: 14,
                color: K.line,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  iconTile(it.icon, K.teal, K.tealSoft, s: 42),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(it.name, style: tx(15.5, w: bold)),
                            ),
                            Text(_m(it.total), style: tx(15.5, w: bold)),
                          ],
                        ),
                        gap(6),
                        bar(
                          it.paid / it.total,
                          it.paid == it.total ? K.green : K.teal,
                          h: 5,
                        ),
                        gap(5),
                        Row(
                          children: [
                            Text(
                              it.paid == it.total
                                  ? 'خالص'
                                  : it.paid == 0
                                  ? 'ما دفعت شيء'
                                  : 'دفعت ${_m(it.paid)}',
                              style: tx(
                                12.5,
                                w: it.paid == it.total ? bold : FontWeight.w400,
                                c: it.paid == it.total ? K.green : K.muted,
                              ),
                            ),
                            const Spacer(),
                            if (it.note != null)
                              Text(
                                it.note!,
                                style: tx(12.5, w: bold, c: K.saffronInk),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
    gap(12),
    btn(
      'أضف بند',
      bg: K.tealSoft,
      fg: K.teal,
      wide: true,
      icon: LucideIcons.plus,
    ),
  ],
);

Widget moneyPayments() {
  Widget upRow(
    String when,
    String name,
    String amount,
    String sub, {
    bool soon = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: soon ? K.saffronSoft : K.bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                when.split(' ').first,
                style: tx(19, w: bold, c: soon ? K.saffronInk : K.ink),
              ),
              Text(when.split(' ').last, style: tx(11.5, c: K.muted)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: tx(15.5, w: bold)),
              Text(sub, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(amount, style: tx(15, w: bold)),
            gap(4),
            softAction('دفعتها'),
          ],
        ),
      ],
    ),
  );
  Widget paidRow(String date, String name, String amount) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    child: Row(
      children: [
        iconTile(LucideIcons.check, K.green, K.greenSoft, s: 36, r: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: tx(15, w: bold)),
              Text(date, style: tx(12.5, c: K.muted)),
            ],
          ),
        ),
        Text(
          amount,
          style: tx(14.5, w: bold, c: K.muted),
        ),
        const SizedBox(width: 6),
        const Icon(LucideIcons.receipt, size: 16, color: K.faint),
      ],
    ),
  );
  return Phone(
    nav: Sec.money,
    children: [
      _moneyHead(2),
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
                    '1.1 مليون ر.ي',
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
      sectionTitle('قادمة'),
      whiteList([
        upRow(
          '22 أكتوبر',
          'قاعة سبأ',
          '500 ألف',
          'الثانية من ثلاث',
          soon: true,
        ),
        upRow('15 نوفمبر', 'الذهب والشبكة', '600 ألف', 'الباقي كامل'),
        upRow('1 ديسمبر', 'الكسوة', '400 ألف', 'عند الاستلام'),
        upRow('20 ديسمبر', 'ضيافة الأصالة', '400 ألف', 'العربون الثاني'),
      ], dividers: false),
      sectionTitle('مدفوعة', action: 'الكل (9)'),
      whiteList([
        paidRow('12 أكتوبر · نقدًا', 'الغداء · أبو علي', '200 ألف'),
        paidRow('28 سبتمبر · تحويل', 'الذهب والشبكة', '1.2 مليون'),
        paidRow('10 سبتمبر · نقدًا', 'قاعة سبأ · العربون', '500 ألف'),
      ], dividers: false),
    ],
  );
}

Widget moneyFunding() {
  Widget src(
    IconData i,
    Color fg,
    Color soft,
    String name,
    String state,
    String amount, {
    String? note,
  }) => listRow(
    icon: i,
    fg: fg,
    soft: soft,
    title: name,
    sub: note ?? state,
    trailing: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(amount, style: tx(15, w: bold)),
        Text(state, style: tx(12, c: K.muted)),
      ],
    ),
  );
  return Phone(
    nav: Sec.money,
    children: [
      _moneyHead(3),
      Box(
        pad: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('فلوس العرس كلها', style: tx(14, c: K.muted)),
            Text('8.7 مليون ر.ي', style: tx(28, w: bold)),
            gap(12),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    Expanded(flex: 45, child: Container(color: K.teal)),
                    const SizedBox(width: 3),
                    Expanded(flex: 24, child: Container(color: K.lilac)),
                    const SizedBox(width: 3),
                    Expanded(flex: 6, child: Container(color: K.saffron)),
                    const SizedBox(width: 3),
                    Expanded(flex: 12, child: Container(color: K.sky)),
                  ],
                ),
              ),
            ),
            gap(10),
            Text('صرفت منها 4.6، ومعك 4.1 للباقي', style: tx(14, c: K.muted)),
          ],
        ),
      ),
      sectionTitle('المصادر'),
      whiteList([
        src(
          LucideIcons.piggyBank,
          K.teal,
          K.tealSoft,
          'مدخراتي',
          'وصل',
          '4.5 مليون',
        ),
        src(
          LucideIcons.heartHandshake,
          K.lilac,
          K.lilacSoft,
          'دعم الوالد',
          'وصل',
          '2.4 مليون',
        ),
        src(
          LucideIcons.user,
          K.saffronInk,
          K.saffronSoft,
          'سلفة خالي أحمد',
          'وصل',
          '600 ألف',
          note: 'أرده 4 أقساط بعد العرس',
        ),
        src(
          LucideIcons.user,
          K.sky,
          K.skySoft,
          'صاحبي عادل',
          'موعود',
          '1.2 مليون',
          note: 'وعد قبل العرس · دين بدون موعد',
        ),
      ]),
      gap(12),
      btn(
        'أضف مصدر',
        bg: K.tealSoft,
        fg: K.teal,
        wide: true,
        icon: LucideIcons.plus,
      ),
    ],
  );
}

Widget paySheet() => Phone(
  nav: Sec.money,
  sheet: sheet(
    title: 'دفعة القاعة',
    sub: 'قاعة سبأ · باقي عليك 1.5 مليون',
    children: [
      field('المبلغ', '500,000', big: true, focused: true, suffix: 'ر.ي'),
      gap(10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('500,000 · المتفق', on: true),
          chip('الباقي كامل'),
          chip('مبلغ ثاني'),
        ],
      ),
      gap(16),
      Text(
        'متى؟',
        style: tx(14, w: bold, c: K.muted),
      ),
      gap(8),
      Wrap(
        spacing: 8,
        children: [
          chip('اليوم', on: true),
          chip('أمس'),
          chip('تاريخ', icon: LucideIcons.calendarDays),
        ],
      ),
      gap(16),
      Text(
        'من وين؟',
        style: tx(14, w: bold, c: K.muted),
      ),
      gap(8),
      Wrap(
        spacing: 8,
        children: [
          chip('مدخراتي', on: true),
          chip('دعم الوالد'),
          chip('سلفة خالي'),
        ],
      ),
      gap(16),
      Row(
        children: [
          const Icon(LucideIcons.camera, size: 18, color: K.teal),
          const SizedBox(width: 8),
          Text(
            'صوّر الإيصال (اختياري)',
            style: tx(15, w: bold, c: K.teal),
          ),
        ],
      ),
      gap(18),
      btn('حفظ الدفعة', wide: true, v: 16, fs: 17),
    ],
  ),
  children: [_moneyHead(0)],
);
