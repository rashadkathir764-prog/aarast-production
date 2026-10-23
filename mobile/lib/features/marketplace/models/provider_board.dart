import '../../../core/utils/arabic_count.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import 'marketplace_models.dart';
import 'provider_service_groups.dart';

export 'provider_service_groups.dart' show providerServiceGroupOf;

/// f01 «خدمات عرسك»: one row per service the wedding needs, and how far it
/// got: 0 ما بدأت, 1 طلب, 2 عرض, 3 طلب حجز, 4 محجوز.
class ProviderBoardRow {
  const ProviderBoardRow({
    required this.key,
    required this.title,
    required this.stage,
    required this.detail,
    this.budgetCategoryId,
    this.providerCategoryName,
    this.waitingOffers = 0,
    this.quotes = const [],
    this.outside = false,
  });

  final String key;
  final String title;
  final int stage;

  /// Who and where: «قاعة سبأ · أكّدت 21 يناير», «طلبت من 2 · ينتظر الرد».
  final String detail;
  final String? budgetCategoryId;

  /// The directory category to search when nothing started yet.
  final String? providerCategoryName;

  /// Offers that arrived and still wait for an answer.
  final int waitingOffers;
  final List<QuoteRequest> quotes;

  /// Booked directly with someone outside اعّرست, recorded in the money tab.
  final bool outside;

  bool get booked => stage == 4;
}

/// A money item the board reads: its id and name.
typedef BoardItem = ({String id, String name});

/// A recorded cost the board reads: its item and who it is with.
typedef BoardCost = ({
  String budgetCategoryId,
  String? providerId,
  String? partyName,
});

String? _quoteCategoryName(QuoteRequest quote) =>
    quote.service?.category?.nameAr ?? quote.costSuggestion?.category;

String _providerName(QuoteRequest quote) =>
    quote.provider?.businessName.trim().isNotEmpty == true
    ? quote.provider!.businessName.trim()
    : quote.costSuggestion?.providerName ?? 'المزود';

String _requestCount(int count) => arabicCount(
  count,
  one: 'واحد',
  two: 'اثنين',
  few: 'مزودين',
  many: 'مزود',
);

String _offerCount(int count) => switch (count) {
  1 => 'وصلك عرض',
  2 => 'عرضين وصلوا',
  _ => '$count عروض وصلت',
};

/// Builds the board from the plan's money items, its recorded costs, and its
/// quote requests. Items that are services (or already have a provider)
/// become rows; a request whose service matches no item gets its own row.
List<ProviderBoardRow> buildProviderBoard({
  required List<BoardItem> items,
  required List<BoardCost> costs,
  required List<QuoteRequest> quotes,
  required Map<String, String> costItemById,
}) {
  final quotesByKey = <String, List<QuoteRequest>>{};
  final extraTitles = <String, String>{};
  for (final quote in quotes) {
    final costId = quote.costSuggestion?.costId;
    String? key = costId == null ? null : costItemById[costId];
    if (key == null) {
      final group = providerServiceGroupOf(_quoteCategoryName(quote));
      if (group >= 0) {
        for (final item in items) {
          if (providerServiceGroupOf(item.name) == group) {
            key = item.id;
            break;
          }
        }
      }
    }
    if (key == null) {
      final name = _quoteCategoryName(quote)?.trim();
      key = 'category:${name?.isNotEmpty == true ? name : _providerName(quote)}';
      extraTitles[key] = name?.isNotEmpty == true ? name! : _providerName(quote);
    }
    (quotesByKey[key] ??= []).add(quote);
  }

  final rows = <ProviderBoardRow>[];
  for (final item in items) {
    final itemCosts = costs.where((cost) => cost.budgetCategoryId == item.id);
    final related = quotesByKey.remove(item.id) ?? const [];
    final isService =
        providerServiceGroupOf(item.name) >= 0 ||
        related.isNotEmpty ||
        itemCosts.any(
          (cost) =>
              cost.providerId != null ||
              (cost.partyName?.trim().isNotEmpty ?? false),
        );
    if (!isService) continue;
    final outside = itemCosts
        .where(
          (cost) =>
              cost.providerId == null &&
              (cost.partyName?.trim().isNotEmpty ?? false),
        )
        .firstOrNull;
    rows.add(
      _row(
        key: item.id,
        title: item.name,
        budgetCategoryId: item.id,
        quotes: related,
        outsideParty: outside?.partyName?.trim(),
      ),
    );
  }
  for (final entry in quotesByKey.entries) {
    rows.add(
      _row(
        key: entry.key,
        title: extraTitles[entry.key] ?? 'خدمة',
        quotes: entry.value,
      ),
    );
  }
  // Booked first, then whatever is moving, then what has not started; the
  // plan's own order inside each.
  final order = {for (var i = 0; i < rows.length; i++) rows[i].key: i};
  rows.sort((a, b) {
    final byStage = b.stage.compareTo(a.stage);
    return byStage != 0 ? byStage : order[a.key]!.compareTo(order[b.key]!);
  });
  return rows;
}

ProviderBoardRow _row({
  required String key,
  required String title,
  required List<QuoteRequest> quotes,
  String? budgetCategoryId,
  String? outsideParty,
}) {
  final live = quotes
      .where(
        (quote) =>
            quote.lifecycleStatus != 'REJECTED' &&
            quote.lifecycleStatus != 'CANCELLED',
      )
      .toList();
  final confirmed = live
      .where((quote) => quote.booking?.isConfirmed == true)
      .firstOrNull;
  final requested = live
      .where((quote) => quote.booking?.isRequested == true)
      .firstOrNull;
  final accepted = live
      .where((quote) => quote.lifecycleStatus == 'ACCEPTED')
      .firstOrNull;
  final waiting = live.where((quote) => quote.canAcceptOrReject).length;
  final asked = live
      .where(
        (quote) =>
            quote.lifecycleStatus == 'PENDING_PROVIDER' ||
            quote.lifecycleStatus == 'READY_TO_SEND',
      )
      .length;

  ProviderBoardRow make(int stage, String detail, {bool outside = false}) =>
      ProviderBoardRow(
        key: key,
        title: title,
        stage: stage,
        detail: detail,
        budgetCategoryId: budgetCategoryId,
        providerCategoryName: _searchCategory(title, quotes),
        waitingOffers: waiting,
        quotes: quotes,
        outside: outside,
      );

  if (confirmed != null) {
    final day = confirmed.booking!.eventDate;
    return make(4, '${_providerName(confirmed)} · أكّد ${formatArabicDayMonth(day)}');
  }
  if (outsideParty != null) {
    return make(4, '$outsideParty · خارج اعّرست', outside: true);
  }
  if (requested != null) {
    return make(3, '${_providerName(requested)} · ينتظر تأكيده');
  }
  if (accepted != null) {
    return make(2, 'اخترت ${_providerName(accepted)} · اطلب الحجز');
  }
  if (waiting > 0) return make(2, _offerCount(waiting));
  if (asked > 0) return make(1, 'طلبت من ${_requestCount(asked)} · ينتظر الرد');
  return make(0, 'ما بدأت');
}

String? _searchCategory(String title, List<QuoteRequest> quotes) {
  for (final quote in quotes) {
    final name = _quoteCategoryName(quote);
    if (name != null && name.trim().isNotEmpty) return name;
  }
  return title;
}

/// The tab's status line: «محجوز 3 · عرضين ينتظرونك».
String providerBoardStatus(List<ProviderBoardRow> rows) {
  final booked = rows.where((row) => row.booked).length;
  final waiting = rows.fold<int>(0, (sum, row) => sum + row.waitingOffers);
  final parts = <String>[
    if (booked > 0) 'محجوز $booked',
    if (waiting > 0)
      arabicCount(
        waiting,
        one: 'عرض ينتظرك',
        two: 'عرضين ينتظرونك',
        few: 'عروض تنتظرك',
        many: 'عرض ينتظرك',
      ),
  ];
  if (parts.isEmpty) {
    return rows.isEmpty ? 'اختر مزوديك' : 'ما حجزت شيء بعد';
  }
  return parts.join(' · ');
}
