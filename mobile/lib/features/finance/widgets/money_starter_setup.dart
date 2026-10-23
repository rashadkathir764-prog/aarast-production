import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_loading_state.dart';
import '../models/money_starter_catalog.dart';

typedef MoneyStarterSubmit = Future<bool> Function(List<String> categoryNames);

class MoneyStarterSetup extends StatefulWidget {
  const MoneyStarterSetup({
    required this.catalog,
    required this.loading,
    required this.onSubmit,
    required this.onManualSetup,
    required this.onRefresh,
    this.errorMessage,
    super.key,
  });

  final MoneyStarterCatalog catalog;
  final bool loading;
  final MoneyStarterSubmit onSubmit;
  final VoidCallback onManualSetup;
  final Future<void> Function() onRefresh;
  final String? errorMessage;

  @override
  State<MoneyStarterSetup> createState() => _MoneyStarterSetupState();
}

class _MoneyStarterSetupState extends State<MoneyStarterSetup> {
  final _customController = TextEditingController();
  final _customFocus = FocusNode();
  final _selected = <String>{};
  final _customCategories = <MoneyStarterCategory>[];
  bool _customFieldVisible = false;
  bool _hasInteracted = false;
  String? _customError;

  @override
  void initState() {
    super.initState();
    _resetRecommended();
  }

  @override
  void didUpdateWidget(covariant MoneyStarterSetup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalog.persona != widget.catalog.persona &&
        !_hasInteracted) {
      _customCategories.clear();
      _resetRecommended();
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    _customFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final inlineAction = textScale >= 1.6;
    final content = _content(
      context,
      includeAction: inlineAction,
      bottomPadding: inlineAction ? 36 : 176,
    );

    if (inlineAction) return content;

    // The plan shell ends the tab above its navigation bar (extendBody is
    // false), so the action bar sits on the tab's own bottom edge. Lifting
    // it for an embedded tab left it floating over the list.
    return Stack(
      key: const ValueKey('money-starter-setup'),
      children: [
        Positioned.fill(child: content),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          child: _StarterActionBar(
            selectedCount: _selected.length,
            loading: widget.loading,
            onManualSetup: widget.onManualSetup,
            onPressed: _selected.isEmpty || widget.loading ? null : _submit,
          ),
        ),
      ],
    );
  }

  Widget _content(
    BuildContext context, {
    required bool includeAction,
    required double bottomPadding,
  }) {
    final allCategories = [...widget.catalog.categories, ..._customCategories];
    final allSelected =
        allCategories.isNotEmpty &&
        allCategories.every((category) => _selected.contains(category.id));

    return RefreshIndicator(
      color: AarastV3Color.primary,
      onRefresh: widget.onRefresh,
      child: ListView(
        key: PageStorageKey(
          'money-starter-list-${widget.catalog.persona.name}',
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 14, 20, bottomPadding),
        children: [
          _StarterIntro(
            catalog: widget.catalog,
            selectedCount: _selected.length,
            totalCount: allCategories.length,
          ),
          if (widget.errorMessage != null) ...[
            const SizedBox(height: AarastV3Space.x3),
            _StarterErrorLine(message: widget.errorMessage!),
          ],
          const SizedBox(height: AarastV3Space.x5),
          if (includeAction)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('بنود ميزانيتك', style: AarastV3Type.section(context)),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _ToggleAllButton(
                    allSelected: allSelected,
                    loading: widget.loading,
                    onPressed: () => _toggleAll(
                      allSelected: allSelected,
                      allCategories: allCategories,
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    'بنود ميزانيتك',
                    style: AarastV3Type.section(context),
                  ),
                ),
                _ToggleAllButton(
                  allSelected: allSelected,
                  loading: widget.loading,
                  onPressed: () => _toggleAll(
                    allSelected: allSelected,
                    allCategories: allCategories,
                  ),
                ),
              ],
            ),
          Text(
            'اللي عليه ✓ ينضاف، وما نحط أي مبلغ من عندنا.',
            style: AarastV3Type.body(context),
          ),
          const SizedBox(height: AarastV3Space.x4),
          for (final group in widget.catalog.groups) ...[
            _StarterGroupView(
              group: group,
              selected: _selected,
              enabled: !widget.loading,
              onToggle: _toggle,
            ),
            const SizedBox(height: AarastV3Space.x5),
          ],
          if (_customCategories.isNotEmpty) ...[
            _CustomCategoryGroup(
              categories: _customCategories,
              selected: _selected,
              enabled: !widget.loading,
              onToggle: _toggle,
              onRemove: _removeCustom,
            ),
            const SizedBox(height: AarastV3Space.x5),
          ],
          _CustomCategoryComposer(
            visible: _customFieldVisible,
            controller: _customController,
            focusNode: _customFocus,
            error: _customError,
            enabled: !widget.loading,
            onShow: _showCustomField,
            onAdd: _addCustom,
          ),
          if (_selected.isEmpty) ...[
            const SizedBox(height: AarastV3Space.x3),
            const _SelectionHint(),
          ],
          if (includeAction) ...[
            const SizedBox(height: AarastV3Space.x4),
            _StarterActionBar(
              selectedCount: _selected.length,
              loading: widget.loading,
              inline: true,
              onManualSetup: widget.onManualSetup,
              onPressed: _selected.isEmpty || widget.loading ? null : _submit,
            ),
          ],
        ],
      ),
    );
  }

  void _resetRecommended() {
    _selected
      ..clear()
      ..addAll(widget.catalog.recommendedIds);
  }

  void _toggle(String id) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _hasInteracted = true;
      if (!_selected.add(id)) _selected.remove(id);
    });
  }

  void _toggleAll({
    required bool allSelected,
    required List<MoneyStarterCategory> allCategories,
  }) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _hasInteracted = true;
      _selected
        ..clear()
        ..addAll(
          allSelected
              ? widget.catalog.recommendedIds
              : allCategories.map((category) => category.id),
        );
    });
  }

  void _showCustomField() {
    setState(() {
      _customFieldVisible = true;
      _customError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _customFocus.requestFocus();
    });
  }

  void _addCustom() {
    final name = _cleanName(_customController.text);
    if (name.isEmpty) {
      setState(() => _customError = 'اكتب اسم البند.');
      return;
    }
    final normalized = _normalizeName(name);
    final existingNames = <String>{
      for (final category in widget.catalog.categories)
        _normalizeName(category.name),
      for (final category in _customCategories) _normalizeName(category.name),
    };
    if (existingNames.contains(normalized)) {
      setState(() => _customError = 'هذا البند موجود.');
      return;
    }
    final id = 'custom-${DateTime.now().microsecondsSinceEpoch}';
    setState(() {
      _hasInteracted = true;
      _customCategories.add(
        MoneyStarterCategory(
          id: id,
          name: name,
          icon: LucideIcons.tag,
          recommended: true,
        ),
      );
      _selected.add(id);
      _customController.clear();
      _customError = null;
      _customFieldVisible = false;
    });
    unawaited(HapticFeedback.selectionClick());
  }

  void _removeCustom(String id) {
    setState(() {
      _hasInteracted = true;
      _customCategories.removeWhere((category) => category.id == id);
      _selected.remove(id);
    });
  }

  Future<void> _submit() async {
    final categories = [...widget.catalog.categories, ..._customCategories];
    final selectedNames = [
      for (final category in categories)
        if (_selected.contains(category.id)) category.name,
    ];
    await widget.onSubmit(selectedNames);
  }
}

class _ToggleAllButton extends StatelessWidget {
  const _ToggleAllButton({
    required this.allSelected,
    required this.loading,
    required this.onPressed,
  });

  final bool allSelected;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      key: const ValueKey('money-starter-toggle-all'),
      onPressed: loading ? null : onPressed,
      icon: Icon(
        allSelected ? LucideIcons.rotateCcw : LucideIcons.listChecks,
        size: 16,
      ),
      label: Text(allSelected ? 'الأساسيات' : 'تحديد الكل'),
    );
  }
}

class _StarterIntro extends StatelessWidget {
  const _StarterIntro({
    required this.catalog,
    required this.selectedCount,
    required this.totalCount,
  });

  final MoneyStarterCatalog catalog;
  final int selectedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final tone = catalog.persona == MoneyStarterPersona.bride
        ? AarastV3Color.rose
        : AarastV3Color.primary;
    final softTone = catalog.persona == MoneyStarterPersona.bride
        ? AarastV3Color.roseSoft
        : AarastV3Color.primarySoft;
    final progress = totalCount == 0 ? 0.0 : selectedCount / totalCount;

    return Container(
      key: const ValueKey('money-starter-intro'),
      padding: const EdgeInsets.all(AarastV3Space.x5),
      decoration: BoxDecoration(
        color: softTone,
        borderRadius: BorderRadius.circular(AarastV3Radius.surface),
        border: Border.all(color: tone.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AarastV3Color.paper,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(LucideIcons.walletCards, color: tone, size: 21),
              ),
              const SizedBox(width: AarastV3Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      catalog.eyebrow,
                      style: AarastV3Type.label(context).copyWith(color: tone),
                    ),
                    const SizedBox(height: AarastV3Space.x1),
                    Text(catalog.title, style: AarastV3Type.title(context)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AarastV3Space.x3),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedSwitcher(
              duration: AarastV3Motion.quick,
              child: Container(
                key: ValueKey(selectedCount),
                padding: const EdgeInsets.symmetric(
                  horizontal: AarastV3Space.x3,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AarastV3Color.paper,
                  borderRadius: BorderRadius.circular(AarastV3Radius.pill),
                ),
                child: Text(
                  '$selectedCount مختارة',
                  style: AarastV3Type.label(context).copyWith(color: tone),
                ),
              ),
            ),
          ),
          const SizedBox(height: AarastV3Space.x3),
          Text(catalog.subtitle, style: AarastV3Type.body(context)),
          const SizedBox(height: AarastV3Space.x4),
          AarastV3PlanPath(
            value: progress,
            color: tone,
            semanticsLabel: 'نسبة البنود المختارة',
            nodes: 4,
          ),
        ],
      ),
    );
  }
}

class _StarterGroupView extends StatelessWidget {
  const _StarterGroupView({
    required this.group,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final MoneyStarterGroup group;
  final Set<String> selected;
  final bool enabled;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(group.title, style: AarastV3Type.section(context)),
        const SizedBox(height: AarastV3Space.x1),
        Text(group.subtitle, style: AarastV3Type.body(context)),
        const SizedBox(height: AarastV3Space.x3),
        AarastV3ContinuousSurface(
          children: [
            for (final category in group.categories)
              _StarterCategoryRow(
                category: category,
                selected: selected.contains(category.id),
                enabled: enabled,
                onTap: () => onToggle(category.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _CustomCategoryGroup extends StatelessWidget {
  const _CustomCategoryGroup({
    required this.categories,
    required this.selected,
    required this.enabled,
    required this.onToggle,
    required this.onRemove,
  });

  final List<MoneyStarterCategory> categories;
  final Set<String> selected;
  final bool enabled;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('بنودك الخاصة', style: AarastV3Type.section(context)),
        const SizedBox(height: AarastV3Space.x3),
        AarastV3ContinuousSurface(
          children: [
            for (final category in categories)
              _StarterCategoryRow(
                category: category,
                selected: selected.contains(category.id),
                enabled: enabled,
                onTap: () => onToggle(category.id),
                onRemove: () => onRemove(category.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _StarterCategoryRow extends StatelessWidget {
  const _StarterCategoryRow({
    required this.category,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.onRemove,
  });

  final MoneyStarterCategory category;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: selected,
      enabled: enabled,
      label: category.name,
      child: AnimatedContainer(
        duration: AarastV3Motion.quick,
        color: selected
            ? AarastV3Color.primarySoft.withValues(alpha: .52)
            : AarastV3Color.paper,
        child: InkWell(
          key: ValueKey('money-starter-category-${category.id}'),
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 62),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AarastV3Space.x3,
                vertical: AarastV3Space.x2,
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: AarastV3Motion.quick,
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: selected
                          ? AarastV3Color.paper
                          : AarastV3Color.paperQuiet,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      category.icon,
                      size: 18,
                      color: selected
                          ? AarastV3Color.primary
                          : AarastV3Color.textMuted,
                    ),
                  ),
                  const SizedBox(width: AarastV3Space.x3),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            category.name,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AarastV3Color.ink,
                                  fontWeight: FontWeight.w800,
                                  height: 1.3,
                                ),
                          ),
                        ),
                        if (category.recommended && onRemove == null) ...[
                          const SizedBox(width: AarastV3Space.x2),
                          Text(
                            'مقترح',
                            style: AarastV3Type.label(context).copyWith(
                              color: AarastV3Color.primary,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onRemove != null)
                    IconButton(
                      tooltip: 'شيل ${category.name}',
                      onPressed: enabled ? onRemove : null,
                      icon: const Icon(LucideIcons.x, size: 18),
                      visualDensity: VisualDensity.compact,
                    )
                  else ...[
                    const SizedBox(width: AarastV3Space.x2),
                    AnimatedContainer(
                      duration: AarastV3Motion.quick,
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: selected
                            ? AarastV3Color.primary
                            : AarastV3Color.paper,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AarastV3Color.primary
                              : AarastV3Color.lineStrong,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: selected
                          ? const Icon(
                              LucideIcons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomCategoryComposer extends StatelessWidget {
  const _CustomCategoryComposer({
    required this.visible,
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.enabled,
    required this.onShow,
    required this.onAdd,
  });

  final bool visible;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final bool enabled;
  final VoidCallback onShow;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AarastV3Motion.standard,
      curve: AarastV3Motion.curve,
      child: visible
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('بند خاص', style: AarastV3Type.section(context)),
                const SizedBox(height: AarastV3Space.x2),
                TextField(
                  key: const ValueKey('money-starter-custom-field'),
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  maxLength: 120,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onAdd(),
                  decoration: InputDecoration(
                    labelText: 'اسم البند',
                    hintText: 'مثل: تجهيز استراحة العائلة',
                    errorText: error,
                    prefixIcon: const Icon(LucideIcons.tag),
                    suffixIcon: IconButton(
                      tooltip: 'أضف البند',
                      onPressed: enabled ? onAdd : null,
                      icon: const Icon(LucideIcons.check),
                    ),
                  ),
                ),
              ],
            )
          : OutlinedButton.icon(
              key: const ValueKey('money-starter-add-custom'),
              onPressed: enabled ? onShow : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                side: const BorderSide(color: AarastV3Color.lineStrong),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AarastV3Radius.control),
                ),
              ),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('أضف بند خاص'),
            ),
    );
  }
}

class _StarterActionBar extends StatelessWidget {
  const _StarterActionBar({
    required this.selectedCount,
    required this.loading,
    required this.onPressed,
    required this.onManualSetup,
    this.inline = false,
  });

  final int selectedCount;
  final bool loading;
  final VoidCallback? onPressed;
  final VoidCallback onManualSetup;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.fromLTRB(20, inline ? 0 : 12, 20, inline ? 0 : 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            key: const ValueKey('money-starter-submit'),
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AarastV3Radius.control),
              ),
            ),
            icon: loading
                ? const AarastInlineSpinner(dimension: 18, color: Colors.white)
                : const Icon(LucideIcons.arrowLeft, size: 19),
            label: Text(
              loading
                  ? 'نجهّز ميزانيتك…'
                  : selectedCount == 0
                  ? 'اختر بند واحد على الأقل'
                  : 'تجهيز الميزانية · $selectedCount',
            ),
          ),
          const SizedBox(height: AarastV3Space.x1),
          Text(
            'نضيف البنود مرة وحدة، وتقدر تعدّلها متى ما تشتي.',
            textAlign: TextAlign.center,
            style: AarastV3Type.label(
              context,
            ).copyWith(color: AarastV3Color.textFaint, fontSize: 11),
          ),
          TextButton(
            key: const ValueKey('money-starter-manual'),
            onPressed: loading ? null : onManualSetup,
            child: const Text('أفضل ترتيبها بنفسي'),
          ),
        ],
      ),
    );

    if (inline) return content;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AarastV3Color.paper,
        border: Border(top: BorderSide(color: AarastV3Color.line)),
      ),
      child: SafeArea(top: false, child: content),
    );
  }
}

class _SelectionHint extends StatelessWidget {
  const _SelectionHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AarastV3Space.x3),
      decoration: BoxDecoration(
        color: AarastV3Color.amberSoft,
        borderRadius: BorderRadius.circular(AarastV3Radius.control),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.info, size: 18, color: AarastV3Color.amber),
          const SizedBox(width: AarastV3Space.x2),
          Expanded(
            child: Text(
              'اختر بند واحد على الأقل، أو رتّبها بنفسك.',
              style: AarastV3Type.body(
                context,
              ).copyWith(color: AarastV3Color.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _StarterErrorLine extends StatelessWidget {
  const _StarterErrorLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('money-starter-error'),
      padding: const EdgeInsets.all(AarastV3Space.x3),
      decoration: BoxDecoration(
        color: AarastV3Color.dangerSoft,
        borderRadius: BorderRadius.circular(AarastV3Radius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.alertCircle,
            size: 18,
            color: AarastV3Color.danger,
          ),
          const SizedBox(width: AarastV3Space.x2),
          Expanded(
            child: Text(
              message,
              style: AarastV3Type.body(
                context,
              ).copyWith(color: AarastV3Color.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

String _cleanName(String value) => value.trim().replaceAll(RegExp(r'\s+'), ' ');

String _normalizeName(String value) => _cleanName(value).toLowerCase();
