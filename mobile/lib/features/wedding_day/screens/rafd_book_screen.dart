import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/whatsapp_share.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthController;
import '../models/rafd.dart';
import '../providers/rafd_provider.dart';
import '../widgets/rafd_sheet.dart';
import '../widgets/rafd_thanks_sheet.dart';

/// e09 «دفتر الرفد» (the bride's «دفتر الهدايا»): what arrived, from how
/// many, how many were thanked, and every gift by name (D66). The owner's
/// only; tracking, no money moves.
class RafdBookScreen extends StatefulWidget {
  const RafdBookScreen({
    required this.weddingPlanId,
    this.share = shareOnWhatsApp,
    super.key,
  });

  final String weddingPlanId;

  /// Opens WhatsApp with a thanks message (e10).
  final Future<bool> Function(String text) share;

  @override
  State<RafdBookScreen> createState() => _RafdBookScreenState();
}

class _RafdBookScreenState extends State<RafdBookScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<RafdProvider>().load(widget.weddingPlanId);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _entryOptions(RafdProvider provider, RafdEntry entry) async {
    final remove = await showJourneySheet<bool>(
      context: context,
      builder: (sheet) => JourneySheetBody(
        title: entry.giverName,
        subtitle: '${groupedAmount(entry.amount)} ر.ي',
        children: [
          JourneyOption(
            key: const ValueKey('rafd-entry-remove'),
            title: context.say('احذفه من الدفتر', 'احذفيه من الدفتر'),
            subtitle: context.say(
              'لو سجّلته غلط. تقدر تسجّله من جديد.',
              'لو سجّلتيه غلط. تقدرين تسجّلينه من جديد.',
            ),
            color: AarastV3Color.danger,
            onTap: () => Navigator.of(sheet).pop(true),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    try {
      await provider.remove(widget.weddingPlanId, entry);
    } on ApiException catch (error) {
      if (mounted) AarastToast.showError(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RafdProvider>();
    final book = provider.bookOf(widget.weddingPlanId);
    final bride = context.journeyProfile.isBride;
    final query = _search.text.trim();
    final items = [
      for (final entry in book?.items ?? const <RafdEntry>[])
        if (query.isEmpty ||
            entry.giverName.contains(query) ||
            entry.amount.round().toString().contains(
              query.replaceAll(',', ''),
            ))
          entry,
    ];
    final signature = context.watch<AuthController?>()?.user?.name ?? '';

    return AarastScreenFrame(
      maxWidth: 560,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              key: const ValueKey('rafd-book'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                JourneySubHeader(
                  title: bride ? 'دفتر الهدايا' : 'دفتر الرفد',
                  subtitle: bride
                      ? 'كل هدية باسم اللي جابتها'
                      : 'كل رفد باسم اللي جابه',
                  onBack: () => context.popOrGo(
                    AppRouter.weddingPlanDashboard(widget.weddingPlanId),
                  ),
                  trailing: JourneyRoundButton(
                    icon: LucideIcons.plus,
                    tooltip: '${context.say('سجّل', 'سجّلي')} ${bride ? 'هدية' : 'رفد'}',
                    onPressed: () => showRafdSheet(
                      context,
                      weddingPlanId: widget.weddingPlanId,
                      provider: provider,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (provider.errorMessage case final error?) ...[
                  JourneyNote(
                    key: const ValueKey('rafd-book-error'),
                    text: error,
                    icon: LucideIcons.cloudOff,
                    color: AarastV3Color.danger,
                    soft: AarastV3Color.dangerSoft,
                  ),
                  const SizedBox(height: 12),
                ],
                if (book == null)
                  JourneyListState(
                    phase: provider.isLoading
                        ? JourneyListPhase.loading
                        : JourneyListPhase.error,
                    section: JourneySection.home,
                    onRetry: () => provider.load(widget.weddingPlanId),
                  )
                else if (book.items.isEmpty)
                  JourneyListState(
                    phase: JourneyListPhase.empty,
                    section: JourneySection.home,
                    emptyIcon: LucideIcons.gem,
                    emptyTitle: bride
                        ? 'ما سجّلتِ هدية بعد'
                        : 'ما سجّلت رفد بعد',
                    emptyMessage:
                        'يشتغل بدون نت، وينحفظ في جوالك لين يرجع النت.',
                    emptyAction:
                        '${context.say('سجّل', 'سجّلي')} ${bride ? 'هدية' : 'رفد'}',
                    onEmptyAction: () => showRafdSheet(
                      context,
                      weddingPlanId: widget.weddingPlanId,
                      provider: provider,
                    ),
                  )
                else ...[
                  _Summary(book: book, bride: bride),
                  const SizedBox(height: 12),
                  JourneyTextField(
                    key: const ValueKey('rafd-search'),
                    label: 'ابحث',
                    controller: _search,
                    icon: LucideIcons.search,
                    hint: 'اسم أو مبلغ',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  JourneyList(
                    dividers: false,
                    children: [
                      for (final entry in items)
                        _EntryRow(
                          entry: entry,
                          onTap: () => _entryOptions(provider, entry),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (book != null && book.toThank.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: JourneyButton(
                key: const ValueKey('rafd-thank-all'),
                label: context.say(
                  'اشكرهم كلهم على واتساب',
                  'اشكريهم كلهم على واتساب',
                ),
                icon: LucideIcons.heartHandshake,
                background: AarastV3Color.brandAccentStrong,
                expand: true,
                large: true,
                onPressed: () => showRafdThanksSheet(
                  context,
                  weddingPlanId: widget.weddingPlanId,
                  provider: provider,
                  signature: signature,
                  share: widget.share,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// «وصلك 1,800,000 ر.ي · 112 شخص · شكرت 40».
class _Summary extends StatelessWidget {
  const _Summary({required this.book, required this.bride});

  final RafdBook book;
  final bool bride;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      key: const ValueKey('rafd-summary'),
      color: AarastV3Color.saffron,
      radius: 28,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'وصلك',
                  style: JourneyType.of(
                    JourneyType.bodySmall,
                    color: AarastV3Color.inkSoft,
                  ),
                ),
                Text(
                  '${groupedAmount(book.total)} ر.ي',
                  style: JourneyType.of(
                    JourneyType.display,
                    weight: JourneyType.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${book.givers} ${bride ? 'ضيفة' : 'شخص'}',
                style: JourneyType.of(
                  JourneyType.lead,
                  weight: JourneyType.bold,
                ),
              ),
              Text(
                '${context.say('شكرت', 'شكرتِ')} ${book.thanked}',
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.inkSoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.onTap});

  final RafdEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = entry.giverName.trim();
    return AarastPressable(
      key: ValueKey('rafd-entry-${entry.clientId}'),
      onTap: onTap,
      semanticLabel: '$name، ${groupedAmount(entry.amount)}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            JourneyAvatar(
              letter: name.isEmpty ? '؟' : name.characters.first,
              color: AarastV3Color.brandAccentStrong,
              size: 46,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: JourneyType.of(
                      JourneyType.bodyLarge,
                      weight: JourneyType.bold,
                    ),
                  ),
                  if (entry.pending)
                    Text(
                      'ينتظر النت',
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.brandAccentStrong,
                      ),
                    )
                  else if (entry.thanked)
                    Text(
                      context.say('شكرته', 'شكرتيها'),
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.mint,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              groupedAmount(entry.amount),
              style: JourneyType.of(
                JourneyType.body,
                weight: JourneyType.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
