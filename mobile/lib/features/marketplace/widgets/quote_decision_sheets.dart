import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/hijri_date.dart';
import '../../../core/utils/money_formatters.dart';
import '../models/marketplace_models.dart';

/// «550 ألف ر.ي» for an offer, or null when it has no amount.
String? offerAmountLabel(QuoteOffer? offer) {
  final amount = num.tryParse(offer?.amount ?? '');
  if (amount == null) return null;
  return formatCompactMoney(amount, currencyCode: offer?.currency ?? 'YER');
}

String quoteProviderName(QuoteRequest quote) =>
    quote.provider?.businessName.trim().isNotEmpty == true
    ? quote.provider!.businessName.trim()
    : 'المزود';

/// «الخميس 21 يناير · 13 شعبان»; the Hijri part only while g02 shows it.
String bookingDayLabel(DateTime day, {bool showHijri = true}) {
  final hijri = showHijri ? HijriDate.fromGregorian(day) : null;
  final gregorian = formatArabicWeekdayDayMonth(day);
  return hijri == null ? gregorian : '$gregorian · ${hijri.dayAndMonth}';
}

/// f05 «نطلب الحجز؟»: the day, the place, the three steps, and that no
/// money moves through اعّرست. Returns the day to request, or null.
class BookingRequestSheet extends StatefulWidget {
  const BookingRequestSheet({
    required this.quote,
    required this.day,
    this.place,
    this.pickDay,
    super.key,
  });

  final QuoteRequest quote;

  /// The wedding day from the request or the plan; null asks for one.
  final DateTime? day;
  final String? place;

  /// Picks another day; tests replace the platform picker.
  final Future<DateTime?> Function(BuildContext context, DateTime? initial)?
  pickDay;

  @override
  State<BookingRequestSheet> createState() => _BookingRequestSheetState();
}

class _BookingRequestSheetState extends State<BookingRequestSheet> {
  late DateTime? _day = widget.day;

  Future<void> _changeDay() async {
    final picker = widget.pickDay ?? _platformPicker;
    final picked = await picker(context, _day);
    if (picked != null && mounted) setState(() => _day = picked);
  }

  static Future<DateTime?> _platformPicker(
    BuildContext context,
    DateTime? initial,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return showDatePicker(
      context: context,
      initialDate: initial != null && !initial.isBefore(today)
          ? initial
          : today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 1095)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.quote;
    final offer = quote.acceptedOffer ?? quote.pendingOffer;
    final day = _day;
    final place = widget.place?.trim() ?? '';
    final subtitle = [
      quoteProviderName(quote),
      ?quote.service?.title,
      ?offerAmountLabel(offer),
    ].join(' · ');
    Widget fact(IconData icon, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.accent.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: JourneyType.of(
                JourneyType.bodyLarge,
                weight: JourneyType.bold,
              ),
            ),
          ),
        ],
      ),
    );
    Widget step(String number, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.accent.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: context.accent.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: JourneyType.of(JourneyType.body))),
        ],
      ),
    );
    return JourneySheetBody(
      title: 'نطلب الحجز؟',
      subtitle: subtitle,
      children: [
        JourneyBox(
          color: AarastV3Color.canvas,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              fact(
                LucideIcons.calendarDays,
                day == null
                    ? context.say('اختر يوم الحجز', 'اختاري يوم الحجز')
                    : bookingDayLabel(
                        day,
                        showHijri:
                            context.watch<DevicePreferences?>()?.showHijri ??
                            true,
                      ),
              ),
              if (place.isNotEmpty) fact(LucideIcons.mapPin, place),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: JourneyTextAction(
                  key: const ValueKey('booking-other-day'),
                  label: day == null
                      ? context.say('اختر اليوم', 'اختاري اليوم')
                      : 'يوم ثاني',
                  icon: LucideIcons.calendarPlus,
                  color: context.accent.primary,
                  onPressed: _changeDay,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        step('1', 'يوصلهم طلب الحجز الآن'),
        step('2', 'يأكدون إن اليوم فاضي، وتوصلك رسالة'),
        step('3', 'يصير «محجوز»، ونذكّركم قبل بأسبوع وبيوم'),
        const SizedBox(height: 4),
        JourneyNote(
          key: const ValueKey('booking-no-payment'),
          text: context.say(
            'ما فيه دفع داخل اعّرست. الدفعة المقدمة تتفق عليها معهم مباشرة وتسجلها في المال.',
            'ما فيه دفع داخل اعّرست. الدفعة المقدمة تتفقين عليها معهم مباشرة وتسجلينها في المال.',
          ),
          icon: LucideIcons.info,
          color: AarastV3Color.brandAccentStrong,
          soft: AarastV3Color.brandAccentSoft,
        ),
        const SizedBox(height: 16),
        JourneyButton(
          key: const ValueKey('booking-request'),
          label: context.say('اطلب الحجز', 'اطلبي الحجز'),
          icon: LucideIcons.calendarCheck,
          background: context.accent.primary,
          expand: true,
          large: true,
          onPressed: day == null ? null : () => Navigator.of(context).pop(day),
        ),
      ],
    );
  }
}

/// x10 «ما يناسبك العرض؟»: a reason only picks the wording; the message goes
/// to the provider and the budget is never mentioned. Returns the message.
/// What [DeclineOfferSheet] returns: the words that go to the provider and
/// the reason the server keeps (B-11: `PRICE`, `CHOSE_OTHER`, `DATE`, `NONE`).
typedef DeclineOfferChoice = ({String message, String reason});

class DeclineOfferSheet extends StatefulWidget {
  const DeclineOfferSheet({required this.quote, this.onSend, super.key});

  final QuoteRequest quote;

  /// Sends the choice: null once done, or why not. The sheet closes only
  /// once done, so a failure keeps the reason and the words as edited, and
  /// it takes no second tap while sending. Without it the sheet only
  /// returns the choice.
  final Future<String?> Function(DeclineOfferChoice choice)? onSend;

  @override
  State<DeclineOfferSheet> createState() => _DeclineOfferSheetState();
}

class _DeclineOfferSheetState extends State<DeclineOfferSheet> {
  /// Each reason in the groom's and the bride's words.
  static const _reasons = [
    ('السعر فوق بندي', 'السعر فوق بندي'),
    ('اخترت غيرهم', 'اخترتِ غيرهم'),
    ('الموعد ما يناسب', 'الموعد ما يناسب'),
    ('بدون سبب', 'بدون سبب'),
  ];

  /// B-11: the server's code for each reason, in the same order.
  static const _reasonCodes = ['PRICE', 'CHOSE_OTHER', 'DATE', 'NONE'];
  int _reason = 0;
  bool _editing = false;
  bool _sending = false;
  String? _failure;
  final _message = TextEditingController();

  @override
  void initState() {
    super.initState();
    _message.text = _template(_reason);
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  String _template(int reason) => switch (reason) {
    0 =>
      'الله يعطيكم العافية. شكرًا على العرض، السعر هذي المرة فوق اللي أقدر عليه. إذا عندكم باقة أخف نتشرف.',
    1 => 'الله يعطيكم العافية. شكرًا على العرض، اخترنا مزود ثاني هذي المرة.',
    2 => 'الله يعطيكم العافية. شكرًا على العرض، الموعد ما يناسبنا هذي المرة.',
    _ => 'الله يعطيكم العافية. شكرًا على العرض، ما نقدر نكمل معكم هذي المرة.',
  };

  Future<void> _send() async {
    if (_sending) return;
    final text = _message.text.trim();
    final DeclineOfferChoice choice = (
      message: text.isEmpty ? _template(_reason) : text,
      reason: _reasonCodes[_reason],
    );
    final send = widget.onSend;
    if (send == null) {
      Navigator.of(context).pop<DeclineOfferChoice>(choice);
      return;
    }
    setState(() {
      _sending = true;
      _failure = null;
    });
    final failure = await send(choice);
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop<DeclineOfferChoice>(choice);
      return;
    }
    setState(() {
      _sending = false;
      _failure = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.quote.pendingOffer;
    return JourneySheetBody(
      title: 'ما يناسبك العرض؟',
      children: [
        Text(
          [
            quoteProviderName(widget.quote),
            ?offerAmountLabel(offer),
          ].join(' · '),
          style: JourneyType.of(
            JourneyType.body,
            color: AarastV3Color.textMuted,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'ليش؟',
          style: JourneyType.of(
            JourneyType.body,
            weight: JourneyType.bold,
            color: AarastV3Color.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _reasons.length; i++)
              JourneyChip(
                key: ValueKey('decline-reason-$i'),
                label: context.say(_reasons[i].$1, _reasons[i].$2),
                selected: _reason == i,
                selectedColor: context.accent.primary,
                onTap: () => setState(() {
                  _reason = i;
                  if (!_editing) _message.text = _template(i);
                }),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'يوصلهم كذا:',
          style: JourneyType.of(
            JourneyType.body,
            weight: JourneyType.bold,
            color: AarastV3Color.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        if (_editing)
          JourneyTextField(
            key: const ValueKey('decline-message'),
            label: 'رسالتك',
            controller: _message,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            autofocus: true,
          )
        else
          JourneyBox(
            key: const ValueKey('decline-preview'),
            padding: const EdgeInsets.all(14),
            child: Text(_message.text, style: JourneyType.of(JourneyType.body)),
          ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (!_editing)
              JourneyTextAction(
                key: const ValueKey('decline-edit'),
                label: context.say('عدّل الرسالة', 'عدّلي الرسالة'),
                icon: LucideIcons.pencil,
                color: context.accent.primary,
                onPressed: () => setState(() => _editing = true),
              ),
            const Spacer(),
            Text(
              'بندك ما ينذكر',
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          ],
        ),
        if (_failure != null) ...[
          const SizedBox(height: AarastV3Space.x3),
          JourneyNote(
            key: const ValueKey('decline-failure'),
            text: _failure!,
            icon: LucideIcons.alertCircle,
            color: AarastV3Color.danger,
            soft: AarastV3Color.dangerSoft,
          ),
        ],
        const SizedBox(height: 16),
        JourneyButton(
          key: const ValueKey('decline-send'),
          label: context.say('أرسل واعتذر', 'أرسلي واعتذري'),
          background: context.accent.primary,
          expand: true,
          large: true,
          loading: _sending,
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}
