// Journey prototype v3: the plan side of what the provider journey added.
// Picking a hall by name or a number of cars, the deposit the provider
// confirms, a night held for you, the team on its way, and the delivery.
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../c_journey/kit.dart';
import 'gaps_a.dart' show gNote;

Widget _unit(String n, String sub, Widget end, {bool on = false, bool off = false}) => Container(
  margin: const EdgeInsets.only(bottom: 8),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: off ? K.bg : Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: on ? K.sky : K.line, width: on ? 2 : 1),
  ),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(n, style: tx(15.5, w: bold, c: off ? K.faint : K.ink)), Text(sub, style: tx(12.5, c: K.muted))],
        ),
      ),
      end,
    ],
  ),
);

Widget _stepper(int n) => Container(
  padding: const EdgeInsets.all(4),
  decoration: BoxDecoration(color: K.skySoft, borderRadius: BorderRadius.circular(14)),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(LucideIcons.minus, size: 18, color: K.sky),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('$n', style: tx(16, w: bold, c: K.sky))),
      const Icon(LucideIcons.plus, size: 18, color: K.sky),
    ],
  ),
);

/// The provider has several halls or a fleet: you pick the hall or how many.
Widget vPickUnit() => Phone(
  sheet: sheet(
    title: 'قاعة سبأ: أي قاعة؟',
    sub: 'الخميس 21 يناير · الليل',
    children: [
      _unit('القاعة الكبرى', '150 ضيف · رجال', tag('فاضية', K.green, K.greenSoft), on: true),
      _unit('القاعة الصغرى', '80 ضيف · رجال', tag('محجوزة', K.muted, K.line), off: true),
      _unit('قاعة الملحق', '60 ضيف · رجال', tag('فاضية', K.green, K.greenSoft)),
      gap(8),
      Text('ومعها من نفس المزود', style: tx(14, w: bold, c: K.muted)),
      gap(8),
      _unit('سيارات الزفة · لكزس', 'باقي 4 من 6 ذاك اليوم', _stepper(3)),
      gap(6),
      btn('اطلب الحجز', wide: true, v: 16, fs: 17, bg: K.sky),
    ],
  ),
  children: [subHeader('قاعة سبأ')],
);

Widget vDepositStatus() {
  Widget row(IconData i, Color c, Color s, String t, String sub, Widget end) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    child: Row(
      children: [
        iconTile(i, c, s, s: 42),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: tx(15, w: bold)), Text(sub, style: tx(12.5, c: K.muted))])),
        end,
      ],
    ),
  );
  return Phone(
    nav: Sec.money,
    children: [
      subHeader('الدفعات المقدمة', sub: 'تدفعها برا، وتسجّلها هنا'),
      whiteList([
        row(LucideIcons.building2, K.green, K.greenSoft, 'قاعة سبأ · 500,000', 'كاش · 10 سبتمبر', tag('أكّدوا الاستلام', K.green, K.greenSoft)),
        row(LucideIcons.utensils, K.green, K.greenSoft, 'ضيافة الأصالة · 900,000', 'كاش · 8 أكتوبر', tag('أكّدوا الاستلام', K.green, K.greenSoft)),
        row(LucideIcons.utensils, K.coral, K.coralSoft, 'ضيافة الأصالة · 200,000', 'جوالي · أمس', tag('قالوا ما وصلت', K.coral, K.coralSoft)),
      ]),
      gap(12),
      Box(
        border: K.coral,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ضيافة الأصالة قالوا ما وصلتهم', style: tx(16, w: bold)),
            Text('غالبًا الحوالة باسم ثاني. شوف السند، وكلّمهم، أو بلّغنا.', style: tx(13.5, c: K.muted, h: 1.5)),
            gap(10),
            Row(children: [
              btn('أرسل السند مرة ثانية', bg: K.coralSoft, fg: K.coral, v: 10, fs: 14),
              const SizedBox(width: 8),
              btn('بلّغنا', bg: K.bg, fg: K.muted, v: 10, fs: 14),
            ]),
          ],
        ),
      ),
      gap(10),
      gNote('كل دفعة مقدمة مسجلة ومأكدة من الطرفين. اعّرست ما يستلم ولا يحوّل فلوس.', i: LucideIcons.shieldCheck),
    ],
  );
}

Widget vHeldForYou() => Phone(
  nav: Sec.providers,
  children: [
    tabHeader('المزودين', 'محجوز 3 من 6', sec: Sec.providers),
    Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: K.lilacSoft, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.lock, color: K.lilac, size: 20),
            const SizedBox(width: 8),
            Text('ماسكين لك الليلة', style: tx(14, w: bold, c: K.lilac)),
          ]),
          gap(6),
          Text('استوديو ضوء صنعاء مسك ليلة 21 لك', style: tx(19, w: bold)),
          Text('لين السبت 10 الليل. بعدها تنفك لحالها.', style: tx(13.5, c: K.muted)),
          gap(14),
          Row(children: [
            btn('أكّد الحجز', bg: K.lilac, v: 11, fs: 15),
            const SizedBox(width: 8),
            btn('ما أشتيه', bg: Colors.white, fg: K.muted, v: 11, fs: 15),
          ]),
        ],
      ),
    ),
    gap(10),
    Text('لو ما تشتيه، قل لهم عشان يعطونها غيرك.', style: tx(13, c: K.muted)),
  ],
);

/// On the night: the provider tapped «وصلنا».
Widget vTeamArrived() => Phone(
  nav: Sec.home,
  children: [
    Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      child: Row(children: [Expanded(child: Text('اليوم عرسك', style: tx(24, w: bold))), avatar('م', K.saffron, s: 44)]),
    ),
    Text('المزودين الليلة', style: tx(17, w: bold)),
    gap(10),
    whiteList([
      listRow(icon: LucideIcons.building2, fg: K.green, soft: K.greenSoft, title: 'قاعة سبأ', sub: 'جاهزة من العصر', trailing: tag('جاهز', K.green, K.greenSoft)),
      listRow(icon: LucideIcons.camera, fg: K.green, soft: K.greenSoft, title: 'استوديو ضوء صنعاء · فريق 2', sub: 'وصلوا 7:40 · المسؤول ياسر', trailing: tag('وصلوا', K.green, K.greenSoft)),
      listRow(icon: LucideIcons.music, fg: K.saffronInk, soft: K.saffronSoft, title: 'فرقة الأفراح', sub: 'في الطريق · يوصلون 8:15', trailing: tag('في الطريق', K.saffronInk, K.saffronSoft)),
      listRow(icon: LucideIcons.car, fg: K.muted, soft: K.line, title: 'سيارات الزفة', sub: 'موعدهم 7:30 عند الباب'),
    ]),
    gap(12),
    gNote('ما تحتاج تتصل تسأل «وينكم». كل مزود يضغط «في الطريق» و«وصلنا»، وتوصلك.', i: LucideIcons.mapPin),
  ],
);

Widget vDelivery() => Phone(
  nav: Sec.providers,
  bottom: Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
    child: Row(children: [
      Expanded(child: btn('استلمتها', bg: K.sky, v: 15)),
      const SizedBox(width: 10),
      btn('فيها نقص', bg: Colors.white, fg: K.coral, v: 15),
    ]),
  ),
  children: [
    subHeader('استوديو ضوء صنعاء', sub: 'سلّموا الصور'),
    Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(LucideIcons.packageCheck, color: K.green),
            const SizedBox(width: 8),
            Text('سلّموا بعد 24 يوم', style: tx(16, w: bold, c: K.green)),
          ]),
          Text('الوعد كان خلال 30 يوم', style: tx(13, c: K.muted)),
          gap(12),
          for (final r in const [('300 صورة معدّلة', true), ('فيلم 10 دقايق', true), ('الألبوم المطبوع', false)])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Icon(r.$2 ? LucideIcons.checkCircle2 : LucideIcons.clock, size: 18, color: r.$2 ? K.green : K.saffronInk),
                const SizedBox(width: 10),
                Text(r.$1, style: tx(14.5)),
                if (!r.$2) Text(' · بعد أسبوع', style: tx(13.5, c: K.muted)),
              ]),
            ),
        ],
      ),
    ),
    gap(10),
    Box(
      pad: const EdgeInsets.all(14),
      child: Row(children: [
        iconTile(LucideIcons.link, K.sky, K.skySoft, s: 40),
        const SizedBox(width: 10),
        Expanded(child: Text('رابط التحميل · يشتغل 60 يوم', style: tx(14.5, w: bold))),
        softAction('افتح', fg: K.sky, bg: K.skySoft),
      ]),
    ),
    gap(10),
    Text('بعد ما تستلم نذكّرك تقيّمهم.', style: tx(13, c: K.muted)),
  ],
);
