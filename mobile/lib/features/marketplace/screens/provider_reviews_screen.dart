import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthController;
import '../../finance/finance_api.dart' show FinanceProvider;
import '../data/marketplace_api.dart';
import '../models/marketplace_models.dart';
import '../providers/marketplace_provider.dart';
import '../widgets/provider_board_view.dart' show providerServiceIcon;
import '../widgets/provider_details_view.dart' show providerMoneyLabel;

/// «قيّم مزودينك»: g04 rates the providers whose booked day has passed, one
/// after another; x12 thanks for each review; w35 says why a provider whose
/// day is still ahead cannot be rated yet. One review per provider (the
/// server's rule); the quick tags are left out (no field keeps them).
class ProviderReviewsScreen extends StatefulWidget {
  const ProviderReviewsScreen({
    required this.weddingPlanId,
    this.providerId,
    super.key,
  });

  final String weddingPlanId;

  /// The provider to rate first, when opened from its booking.
  final String? providerId;

  @override
  State<ProviderReviewsScreen> createState() => _ProviderReviewsScreenState();
}

typedef _Booked = ({String providerId, String name, String service});

class _ProviderReviewsScreenState extends State<ProviderReviewsScreen> {
  final _comment = TextEditingController();

  /// This account's rating per provider, read from each provider's reviews.
  final Map<String, int> _mine = {};
  bool _loading = true;
  bool _failed = false;
  bool _sending = false;
  int _rating = 0;
  String? _currentId;

  /// x12: the provider just rated, while the thanks are on screen.
  _Booked? _sent;

  @override
  void initState() {
    super.initState();
    _currentId = widget.providerId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  List<QuoteRequest> get _quotes => context
      .read<ProviderMarketplaceProvider>()
      .quotesForPlan(widget.weddingPlanId)
      .where((quote) => quote.booking != null)
      .toList();

  /// Each provider once, from its bookings in [status].
  List<_Booked> _providers(List<QuoteRequest> quotes, String status) {
    final seen = <String>{};
    return [
      for (final quote in quotes)
        if (quote.booking!.lifecycleStatus == status &&
            seen.add(quote.providerId))
          (
            providerId: quote.providerId,
            name: quote.provider?.businessName ?? '',
            service:
                quote.service?.category?.nameAr ?? quote.service?.title ?? '',
          ),
    ];
  }

  Future<void> _load() async {
    final marketplace = context.read<ProviderMarketplaceProvider>();
    final api = context.read<MarketplaceApi>();
    final userId = context.read<AuthController?>()?.user?.id;
    final finance = context.read<FinanceProvider?>();
    if (finance != null &&
        finance.loadedPlanId != widget.weddingPlanId &&
        !finance.isLoading) {
      finance.loadMoney(widget.weddingPlanId);
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      if (_quotes.isEmpty) await marketplace.loadScopedQuoteRequests();
      if (!mounted) return;
      for (final booked in _providers(_quotes, 'COMPLETED')) {
        if (userId == null) break;
        final reviews = await api.getProviderReviews(booked.providerId);
        final own = reviews.where((review) => review.userId == userId);
        if (own.isNotEmpty) _mine[booked.providerId] = own.first.rating;
      }
    } on Object {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ProviderMarketplaceProvider>();
    final quotes = _quotes;
    final done = _providers(quotes, 'COMPLETED');
    final left = done.where((item) => !_mine.containsKey(item.providerId));
    final current =
        left.where((item) => item.providerId == _currentId).firstOrNull ??
        left.firstOrNull;
    final name = context.watch<AuthController?>()?.user?.name ?? '';

    final Widget body;
    final Widget? footer;
    if (_loading) {
      body = const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.providers,
      );
      footer = null;
    } else if (_failed) {
      body = JourneyListState(
        phase: JourneyListPhase.error,
        section: JourneySection.providers,
        onRetry: _load,
      );
      footer = null;
    } else if (_sent != null) {
      final next = left.firstOrNull;
      body = _Sent(sent: _sent!, left: left.toList(), name: name);
      footer = JourneyButton(
        key: const ValueKey('reviews-next'),
        label: next == null ? 'تمام' : 'قيّم ${next.name}',
        background: AarastV3Color.brandAccentStrong,
        expand: true,
        large: true,
        onPressed: () => next == null
            ? _close()
            : setState(() {
                _sent = null;
                _currentId = next.providerId;
              }),
      );
    } else if (current == null) {
      final ahead = _providers(quotes, 'CONFIRMED');
      final locked =
          ahead
              .where((item) => item.providerId == widget.providerId)
              .firstOrNull ??
          (done.isEmpty ? ahead.firstOrNull : null);
      body = locked != null
          ? _Locked(provider: locked, name: name)
          : done.isEmpty
          ? const JourneyListState(
              phase: JourneyListPhase.empty,
              section: JourneySection.providers,
              emptyIcon: LucideIcons.star,
              emptyTitle: 'ما في مزودين تقيّمهم بعد',
            )
          : _RatedList(done: done, mine: _mine);
      footer = null;
    } else {
      body = _Rate(
        provider: current,
        paid: _paid(current.providerId),
        rating: _rating,
        comment: _comment,
        name: name,
        done: done.where((item) => _mine.containsKey(item.providerId)),
        mine: _mine,
        onRate: (value) => setState(() => _rating = value),
      );
      footer = JourneyButton(
        key: const ValueKey('reviews-send'),
        label: left.length > 1 ? 'أرسل التقييم والتالي' : 'أرسل التقييم',
        background: AarastV3Color.brandAccentStrong,
        expand: true,
        large: true,
        loading: _sending,
        onPressed: _rating == 0 || _sending ? null : () => _send(current),
      );
    }

    final locked = body is _Locked;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                JourneySubHeader(
                  title: _sent != null
                      ? 'تقييمك'
                      : locked
                      ? body.provider.name
                      : 'قيّم مزودينك',
                  subtitle: _sent != null || locked || done.isEmpty
                      ? null
                      : '${_mine.length} من ${done.length} · تقييمك يساعد العرسان الجايين',
                  onBack: _close,
                ),
                body,
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: footer,
            ),
        ],
      ),
    );
  }

  /// What the plan paid this provider, from the money section.
  String? _paid(String providerId) {
    final finance = context.watch<FinanceProvider?>();
    if (finance?.loadedPlanId != widget.weddingPlanId) return null;
    num total = 0;
    for (final cost in finance!.costs) {
      if (cost.providerId != providerId) continue;
      total += num.tryParse(cost.paidAmount) ?? 0;
    }
    return total > 0 ? providerMoneyLabel('$total', null) : null;
  }

  Future<void> _send(_Booked provider) async {
    setState(() => _sending = true);
    final error = await context
        .read<ProviderMarketplaceProvider>()
        .reviewProvider(
          providerId: provider.providerId,
          rating: _rating,
          comment: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (error == null) {
        _mine[provider.providerId] = _rating;
        _sent = provider;
        _rating = 0;
        _comment.clear();
      }
    });
    if (error != null) AarastToast.showError(context, error);
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.planProviders(widget.weddingPlanId));
    }
  }
}

const _ratingWords = ['ما كان زين', 'مقبول', 'زين', 'ممتاز', 'ممتاز جدًا'];

class _Stars extends StatelessWidget {
  const _Stars({required this.rating, this.size = 40, this.onRate});

  final int rating;
  final double size;
  final ValueChanged<int>? onRate;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var star = 1; star <= 5; star++)
          AarastPressable(
            onTap: onRate == null ? null : () => onRate!(star),
            semanticLabel: onRate == null
                ? null
                : '$star من 5 · ${_ratingWords[star - 1]}',
            borderRadius: BorderRadius.circular(size),
            child: Padding(
              padding: EdgeInsets.all(size / 8),
              child: SizedBox.square(
                key: ValueKey('reviews-star-$star'),
                dimension: size,
                child: CustomPaint(
                  painter: _StarPainter(
                    star <= rating ? AarastV3Color.saffron : AarastV3Color.line,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A filled five-point star; Lucide draws only the outline.
class _StarPainter extends CustomPainter {
  const _StarPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final inner = outer * 0.48;
    final path = Path();
    for (var point = 0; point < 10; point++) {
      final radius = point.isEven ? outer : inner;
      final angle = -math.pi / 2 + point * math.pi / 5;
      final at = centre + Offset(math.cos(angle), math.sin(angle)) * radius;
      point == 0 ? path.moveTo(at.dx, at.dy) : path.lineTo(at.dx, at.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = outer * 0.12
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.color != color;
}

/// g04: the provider being rated, then the ones already rated.
class _Rate extends StatelessWidget {
  const _Rate({
    required this.provider,
    required this.paid,
    required this.rating,
    required this.comment,
    required this.name,
    required this.done,
    required this.mine,
    required this.onRate,
  });

  final _Booked provider;
  final String? paid;
  final int rating;
  final TextEditingController comment;
  final String name;
  final Iterable<_Booked> done;
  final Map<String, int> mine;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneyBox(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  JourneyIconTile(
                    icon: providerServiceIcon(provider.service),
                    color: AarastV3Color.cobalt,
                    soft: AarastV3Color.cobaltSoft,
                    size: 52,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.name,
                          style: JourneyType.of(
                            JourneyType.title,
                            weight: JourneyType.bold,
                          ),
                        ),
                        Text(
                          [
                            if (provider.service.isNotEmpty) provider.service,
                            if (paid != null) 'دفعت $paid',
                          ].join(' · '),
                          style: JourneyType.of(
                            JourneyType.small,
                            color: AarastV3Color.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Center(
                child: _Stars(rating: rating, onRate: onRate),
              ),
              if (rating > 0) ...[
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    _ratingWords[rating - 1],
                    style: JourneyType.of(
                      JourneyType.bodyLarge,
                      weight: JourneyType.bold,
                      color: AarastV3Color.brandAccentStrong,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              JourneyTextField(
                key: const ValueKey('reviews-comment'),
                label: 'كلمة للعرسان الجايين (اختياري)',
                controller: comment,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
              ),
              if (name.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.lock,
                      size: 16,
                      color: AarastV3Color.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'يطلع باسمك: $name',
                        style: JourneyType.of(
                          JourneyType.small,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (done.isNotEmpty) ...[
          const SizedBox(height: 18),
          _RatedList(done: done.toList(), mine: mine),
        ],
      ],
    );
  }
}

/// «قيّمتهم»: the providers rated, with this account's stars.
class _RatedList extends StatelessWidget {
  const _RatedList({required this.done, required this.mine});

  final List<_Booked> done;
  final Map<String, int> mine;

  @override
  Widget build(BuildContext context) {
    final rated = done.where((item) => mine.containsKey(item.providerId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            'قيّمتهم',
            style: JourneyType.of(JourneyType.title, weight: JourneyType.bold),
          ),
        ),
        JourneyList(
          children: [
            for (final item in rated)
              JourneyListRow(
                icon: LucideIcons.checkCircle2,
                color: AarastV3Color.mint,
                soft: AarastV3Color.mintSoft,
                title: item.name,
                subtitle: item.service,
                trailing: _Stars(rating: mine[item.providerId]!, size: 16),
              ),
          ],
        ),
      ],
    );
  }
}

/// x12: the review is out.
class _Sent extends StatelessWidget {
  const _Sent({required this.sent, required this.left, required this.name});

  final _Booked sent;
  final List<_Booked> left;
  final String name;

  @override
  Widget build(BuildContext context) {
    Widget step(String label, {String? when}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Icon(
            LucideIcons.checkCircle2,
            size: 20,
            color: AarastV3Color.mint,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: JourneyType.of(JourneyType.body))),
          if (when != null)
            Text(
              when,
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: AarastV3Color.mint,
              ),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Center(
          child: JourneyIconTile(
            icon: LucideIcons.star,
            color: AarastV3Color.brandAccentStrong,
            soft: AarastV3Color.brandAccentSoft,
            size: 76,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'وصل تقييمك عن ${sent.name}',
          textAlign: TextAlign.center,
          style: JourneyType.of(JourneyType.title, weight: JourneyType.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'شكرًا، العرسان الجايين بيستفيدون منه',
          textAlign: TextAlign.center,
          style: JourneyType.of(
            JourneyType.body,
            color: AarastV3Color.textMuted,
          ),
        ),
        const SizedBox(height: 18),
        JourneyBox(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              step('انرسل', when: 'الآن'),
              step('انشر الآن'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        JourneyNote(
          icon: LucideIcons.shieldCheck,
          color: AarastV3Color.brandAccentStrong,
          soft: AarastV3Color.brandAccentSoft,
          text: name.isEmpty
              ? 'لو فيه كلام جارح أو أرقام جوال نخفيه.'
              : 'ينشر باسمك: $name. لو فيه كلام جارح أو أرقام جوال نخفيه.',
        ),
        if (left.isNotEmpty) ...[
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              'باقي تقيّم',
              style: JourneyType.of(
                JourneyType.title,
                weight: JourneyType.bold,
              ),
            ),
          ),
          JourneyList(
            children: [
              for (final item in left)
                JourneyListRow(
                  icon: providerServiceIcon(item.service),
                  color: AarastV3Color.cobalt,
                  soft: AarastV3Color.cobaltSoft,
                  title: item.name,
                  subtitle: item.service,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// w35: the day has not come yet.
class _Locked extends StatelessWidget {
  const _Locked({required this.provider, required this.name});

  final _Booked provider;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const Center(
          child: JourneyIconTile(
            icon: LucideIcons.star,
            color: AarastV3Color.brandAccentStrong,
            soft: AarastV3Color.brandAccentSoft,
            size: 76,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'التقييم بعد العرس',
          textAlign: TextAlign.center,
          style: JourneyType.of(JourneyType.display, weight: JourneyType.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'تقيّم المزود بعد يوم الحجز بس، عشان كل تقييم يكون من تجربة حقيقية.',
          textAlign: TextAlign.center,
          style: JourneyType.of(
            JourneyType.body,
            color: AarastV3Color.textMuted,
          ),
        ),
        if (name.isNotEmpty) ...[
          const SizedBox(height: 18),
          JourneyNote(text: 'التقييم يطلع باسمك: $name.'),
        ],
      ],
    );
  }
}
