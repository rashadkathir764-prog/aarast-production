import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/amount_words.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../finance/finance_api.dart'
    show FinanceProvider, FundingProvider, formatMoneyInputValue, moneyValue;

/// y08: the mahr is complete. Shown once per phone, from the home, when the
/// owner's mahr card leaves it («نخفي بطاقة المهر من الرئيسية، وتلقاها في
/// المال»). The groom reads what he handed over, the bride what she received;
/// each row is a payment (or a received part) by its note, else its day.
class MahrMomentScreen extends StatefulWidget {
  const MahrMomentScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<MahrMomentScreen> createState() => _MahrMomentScreenState();
}

class _MahrMomentScreenState extends State<MahrMomentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final finance = context.read<FinanceProvider?>();
      final cost = finance == null ? null : _mahrCostId(finance);
      if (cost != null) finance!.loadCostDetails(cost);
      final funding = context.read<FundingProvider?>();
      if (funding != null &&
          funding.loadedPlanId != widget.weddingPlanId &&
          !funding.isLoading) {
        funding.load(widget.weddingPlanId);
      }
    });
  }

  String? _mahrCostId(FinanceProvider finance) {
    if (finance.loadedPlanId != widget.weddingPlanId) return null;
    final item = finance.categories.where((item) => item.isMahr).firstOrNull;
    if (item == null) return null;
    return finance.costs
        .where((cost) => cost.budgetCategoryId == item.id && !cost.isCancelled)
        .firstOrNull
        ?.id;
  }

  @override
  Widget build(BuildContext context) {
    final finance = context.watch<FinanceProvider?>();
    final mahr = finance?.loadedPlanId == widget.weddingPlanId
        ? finance!.summary.mahr
        : null;
    // The bride receives her mahr (her plan's funding); the groom pays it.
    final receives = mahr?.side.name == 'receives';
    final total = moneyValue(mahr?.total ?? '0');
    String shown(Object? amount) {
      final text = _amount(moneyValue(amount));
      return finance?.shownAmount(text) ?? text;
    }

    final rows = <(IconData, String, String)>[];
    if (receives) {
      final funding = context.watch<FundingProvider?>();
      if (funding?.loadedPlanId == widget.weddingPlanId) {
        for (final source in funding!.sources) {
          if (!source.isMahr || source.isPledged) continue;
          rows.add((
            LucideIcons.checkCircle,
            _name(source.note, source.receivedAt),
            shown(source.amount),
          ));
        }
      }
    } else if (finance != null) {
      final costId = _mahrCostId(finance);
      if (costId != null) {
        final payments = finance
            .paymentsForCost(costId)
            .where(
              (payment) =>
                  payment.entryType == 'PAYMENT' &&
                  payment.reversedById == null,
            );
        for (final payment
            in payments.toList()
              ..sort((a, b) => a.paidAt.compareTo(b.paidAt))) {
          rows.add((
            LucideIcons.checkCircle,
            _name(payment.note, payment.paidAt),
            shown(payment.amount),
          ));
        }
      }
    }

    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: context.accent.primary,
      child: JourneyMoment(
        eyebrow: receives ? 'الاتفاق مع العريس' : 'الاتفاق مع أهل العروسة',
        title: receives ? 'استلمتِ المهر كامل' : 'سلّمت المهر كامل',
        subtitle: [
          if (total > 0 && finance?.amountsHidden != true)
            '${amountInWords(total.round())}، وصلت كلها.',
          'هذا الجزء من عرسك خلص، ألف مبروك.',
        ].join('\n'),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (rows.isNotEmpty) JourneyGlassRows(rows: rows),
            const SizedBox(height: 16),
            Text(
              context.say(
                'نخفي بطاقة المهر من الرئيسية، وتلقاها في المال.',
                'نخفي بطاقة المهر من الرئيسية، وتلقينها في المال.',
              ),
              textAlign: TextAlign.center,
              style: JourneyType.of(
                JourneyType.small,
                color: context.accent.onPrimaryMuted,
              ),
            ),
          ],
        ),
        action: 'تمام',
        onAction: () => context.popOrGo(
          AppRouter.weddingPlanDashboard(widget.weddingPlanId),
        ),
      ),
    );
  }
}

/// «يوم الخطوبة» from the payment's note, else its day «15 نوفمبر».
String _name(String? note, DateTime? day) {
  final text = note?.trim() ?? '';
  if (text.isNotEmpty) return text;
  return day == null ? 'دفعة' : formatArabicDayMonth(day);
}

/// «2,000,000»: the PNG's grouped amount, without the currency.
String _amount(num value) => formatMoneyInputValue(value.round());
