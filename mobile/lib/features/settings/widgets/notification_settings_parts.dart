import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/l10n/aarast_text.dart';
import '../../../core/push/push_notifications_controller.dart';
import '../../../core/push/push_system_notifications.dart' show pushChannelIds;
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/user_settings.dart';
import '../providers/settings_provider.dart';
import '../utils/reminder_timing_lines.dart';

// The notification settings of the couple's page and the provider's page
// are one design (REFINEMENT_SPEC 2.5): «هذا الجوال» first, what this
// phone does with notifications, apart from «ما يصلك منّا», the account's
// switches. The phone's state never changes a switch, and a switch never
// claims to fix the phone.

/// «هذا الجوال»: one quiet row (a small icon, the state, one text button
/// when something can be done), read from the phone when the page opens,
/// each time the app comes back in front and each time push says it
/// changed. It never waits for the server's settings. Under it, while
/// phone notifications work, the night line from the server's table.
class PhoneNotificationsSection extends StatefulWidget {
  const PhoneNotificationsSection({required this.weddingNews, super.key});

  /// The night line says what comes through in the wedding's last week:
  /// true for the couple's page, false for a provider's.
  final bool weddingNews;

  @override
  State<PhoneNotificationsSection> createState() =>
      _PhoneNotificationsSectionState();
}

class _PhoneNotificationsSectionState extends State<PhoneNotificationsSection>
    with WidgetsBindingObserver {
  PushPhoneState _state = PushPhoneState.unknown;
  List<String> _blocked = const [];
  bool _busy = false;

  /// The phone's settings were opened from here: the state is read again
  /// on the way back, and a toast says it when they came back on.
  bool _sentToSettings = false;

  /// The phone would not open its settings: the path is said by hand.
  bool _openFailed = false;

  /// Only the last read is shown; an earlier one that ends later is dropped.
  int _reads = 0;
  PushNotificationsController? _listened;

  PushNotificationsController? get _push {
    try {
      return context.read<PushNotificationsController>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _listened = _push?..addListener(_onPushChanged);
      unawaited(_read());
    });
  }

  @override
  void dispose() {
    _listened?.removeListener(_onPushChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_read());
  }

  void _onPushChanged() {
    if (!_busy) unawaited(_read());
  }

  Future<void> _read() async {
    final read = ++_reads;
    final push = _push;
    var state = push == null
        ? PushPhoneState.unavailable
        : await push.phoneState();
    if (!mounted || read != _reads) return;
    // Back from the phone's settings with them allowed: this phone is
    // linked now, then read again.
    if (_sentToSettings && push != null && state == PushPhoneState.notLinked) {
      await push.turnedOnInPhoneSettings();
      state = await push.phoneState();
      if (!mounted || read != _reads) return;
    }
    if (_sentToSettings &&
        state != PushPhoneState.off &&
        state != PushPhoneState.channelsOff) {
      _sentToSettings = false;
      if (state == PushPhoneState.on) {
        AarastToast.showSuccess(context, context.text.phoneTurnedOn);
      }
    }
    final blocked = [
      for (final id in pushChannelIds)
        if (push?.blockedChannels.contains(id) ?? false) id,
    ];
    setState(() {
      if (state != _state) _openFailed = false;
      _state = state;
      _blocked = blocked;
    });
  }

  Future<void> _allow() async {
    final push = _push;
    if (push == null || _busy) return;
    setState(() => _busy = true);
    final state = await push.askFromSettings();
    if (!mounted) return;
    final blocked = [
      for (final id in pushChannelIds)
        if (push.blockedChannels.contains(id)) id,
    ];
    // No toast here: the row under the finger turns to «تعمل» itself, and
    // a screen reader hears it (liveRegion). The toast is for the way back
    // from the phone's settings, where the change happened elsewhere.
    setState(() {
      _busy = false;
      _state = state;
      _blocked = blocked;
    });
  }

  Future<void> _open(
    Future<bool> Function(PushNotificationsController) open,
  ) async {
    final push = _push;
    if (push == null || _busy) return;
    final opened = await open(push);
    if (!mounted) return;
    _sentToSettings = opened;
    setState(() => _openFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final words = context.text;
    final gender = context.gender;
    final reminders = context.watch<SettingsProvider?>()?.schedule;
    final works =
        _state == PushPhoneState.on || _state == PushPhoneState.channelsOff;
    return Column(
      key: const Key('settings-phone-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneySectionTitle(words.phoneSectionTitle),
        _PhoneRow(
          state: _state,
          line: _line(words),
          action: _action(words, gender),
          byHand: _openFailed ? words.phoneSettingsByHand(gender) : null,
        ),
        // The quiet hours are the phone's: said only while it gets them.
        if (works && reminders != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AarastV3Space.x1,
              AarastV3Space.x2,
              AarastV3Space.x1,
              0,
            ),
            child: Text(
              nightLine(reminders, weddingNews: widget.weddingNews),
              key: const Key('settings-night-line'),
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textFaint,
                height: AarastV3Line.reading,
              ),
            ),
          ),
      ],
    );
  }

  String? _line(AppText words) => switch (_state) {
    PushPhoneState.on => words.phoneStateOn,
    PushPhoneState.notAsked => words.phoneStateNotAsked,
    PushPhoneState.off => words.phoneStateOff,
    // A channel this app does not name is still the phone's settings.
    PushPhoneState.channelsOff when _blocked.isEmpty => words.phoneStateOff,
    PushPhoneState.channelsOff => words.phoneStateChannelsOff(
      _blocked
          .map((id) => _channelName(words, id))
          .reduce(words.phoneChannelPair),
    ),
    PushPhoneState.notLinked => words.phoneStateNotLinked,
    PushPhoneState.unavailable => words.phoneStateUnavailable,
    PushPhoneState.unknown => null,
  };

  _PhoneAction? _action(AppText words, String gender) => switch (_state) {
    PushPhoneState.notAsked => _PhoneAction(
      const Key('settings-phone-allow'),
      words.pushPermissionAllow(gender),
      _busy ? null : _allow,
    ),
    PushPhoneState.off || PushPhoneState.channelsOff
        when _state == PushPhoneState.off || _blocked.isEmpty =>
      _PhoneAction(
        const Key('settings-phone-open-settings'),
        words.phoneOpenSettings(gender),
        () => _open((push) => push.openPhoneSettings()),
      ),
    PushPhoneState.channelsOff => _PhoneAction(
      const Key('settings-phone-open-channel'),
      words.phoneOpenChannel(gender),
      () => _open((push) => push.openChannelSettings(_blocked.first)),
    ),
    _ => null,
  };
}

String _channelName(AppText words, String id) => switch (id) {
  'aarast_messages' => words.phoneChannelMessages,
  'aarast_tasks' => words.phoneChannelTasks,
  _ => words.phoneChannelMoney,
};

class _PhoneAction {
  const _PhoneAction(this.key, this.label, this.onPressed);

  final Key key;
  final String label;
  final VoidCallback? onPressed;
}

/// The phone's state: the page's one strong line (REFINEMENT_SPEC 2.6),
/// on the paper, with no coloured edge and no warning colour. Unknown is
/// the same room, empty, so nothing jumps when the phone answers.
class _PhoneRow extends StatelessWidget {
  const _PhoneRow({
    required this.state,
    required this.line,
    required this.action,
    required this.byHand,
  });

  final PushPhoneState state;
  final String? line;
  final _PhoneAction? action;
  final String? byHand;

  @override
  Widget build(BuildContext context) {
    final line = this.line;
    final action = this.action;
    final byHand = this.byHand;
    final on = state == PushPhoneState.on;
    return JourneyBox(
      key: Key('settings-phone-${state.name}'),
      padding: AarastV3Density.rowInsets,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AarastV3Size.markSmall),
        child: line == null
            ? const SizedBox(width: double.infinity)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: AarastV3Space.half),
                    child: Icon(
                      on ? LucideIcons.bellRing : _icon(state),
                      size: AarastV3Icon.md,
                      color: on
                          ? context.accent.primary
                          : AarastV3Color.textMuted,
                    ),
                  ),
                  const SizedBox(width: AarastV3Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            line,
                            style: JourneyType.of(
                              JourneyType.lead,
                              weight: JourneyType.bold,
                            ),
                          ),
                        ),
                        if (action != null)
                          JourneyTextAction(
                            key: action.key,
                            label: action.label,
                            color: context.accent.primary,
                            onPressed: action.onPressed,
                          ),
                        if (byHand != null)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AarastV3Space.x1,
                            ),
                            child: Text(
                              byHand,
                              key: const Key('settings-phone-by-hand'),
                              style: JourneyType.of(
                                JourneyType.small,
                                color: AarastV3Color.textMuted,
                                height: AarastV3Line.reading,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  static IconData _icon(PushPhoneState state) => switch (state) {
    PushPhoneState.notAsked => LucideIcons.bell,
    PushPhoneState.notLinked => LucideIcons.refreshCw,
    PushPhoneState.unavailable => LucideIcons.smartphone,
    _ => LucideIcons.bellOff,
  };
}

/// «ما يصلك منّا · داخل التطبيق وعلى الجوال»: the account's switches as
/// one card of rows. While the switches are not on the phone yet, fixed
/// rows stand in their place; when they could not be read, one line and a
/// retry; when they are the phone's copy, one faint line says so above
/// them. Under the card, the notices no switch governs.
class NotificationPreferencesSection extends StatelessWidget {
  const NotificationPreferencesSection({
    required this.rows,
    required this.loadingRows,
    this.alwaysLine,
    super.key,
  });

  /// The switch rows, or null while the switches are not loaded.
  final List<Widget>? rows;

  /// How many rows stand in while loading: as many as the page shows.
  final int loadingRows;
  final String? alwaysLine;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final words = context.text;
    final rows = this.rows;
    final alwaysLine = this.alwaysLine;
    final Widget body;
    if (rows != null) {
      body = JourneyBox(
        key: const Key('settings-switches'),
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: AarastV3Space.hair,
                  thickness: AarastV3Space.hair,
                  indent: AarastV3Space.x4,
                  endIndent: AarastV3Space.x4,
                  color: AarastV3Color.line,
                ),
              rows[i],
            ],
          ],
        ),
      );
    } else if (settings.loadFailed) {
      body = JourneyBox(
        key: const Key('settings-switches-failed'),
        padding: AarastV3Density.rowInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              words.settingsLoadFailed,
              style: JourneyType.of(JourneyType.body),
            ),
            JourneyTextAction(
              label: words.settingsRetry(context.gender),
              color: context.accent.primary,
              onPressed: settings.loadSettings,
            ),
          ],
        ),
      );
    } else {
      body = _SwitchesLoading(count: loadingRows);
    }
    return Column(
      key: const Key('settings-preferences-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneySectionTitle(words.preferencesTitle),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AarastV3Space.x1,
            0,
            AarastV3Space.x1,
            AarastV3Space.x2,
          ),
          child: Text(
            words.preferencesWhere,
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
        ),
        if (settings.isStale && rows != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AarastV3Space.x2),
            child: JourneyNote(
              key: const Key('settings-offline-line'),
              tone: JourneyNoteTone.bare,
              icon: LucideIcons.wifiOff,
              color: AarastV3Color.textMuted,
              text: words.settingsOfflineLine,
            ),
          ),
        body,
        if (rows != null && alwaysLine != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AarastV3Space.x1,
              AarastV3Space.x2,
              AarastV3Space.x1,
              0,
            ),
            child: Text(
              alwaysLine,
              key: const Key('settings-always-line'),
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textFaint,
                height: AarastV3Line.reading,
              ),
            ),
          ),
      ],
    );
  }
}

/// A switch's next settings from its new value.
typedef UserSettingsChange = UserSettings Function(bool value);

/// Saves one switch at once. A failed save puts the switch back and says
/// so; without a network the change is kept on the phone and sent later
/// (D85), which is a save.
Future<void> saveNotificationSwitch(
  BuildContext context,
  UserSettings next,
) async {
  final settings = context.read<SettingsProvider>();
  final before = settings.settings;
  settings.updateDraft(next);
  final ok = await settings.saveSettings();
  if (ok) return;
  if (before != null) settings.updateDraft(before);
  if (!context.mounted) return;
  AarastToast.showError(
    context,
    context.text.settingsSaveFailed(context.gender),
  );
}

/// One switch: its title, what it covers, and when it comes, or, turned
/// off, that nothing of it comes. The whole row flips it and reads as one
/// element to a screen reader; it rests while any switch is saved.
class NotificationSwitchRow extends StatelessWidget {
  const NotificationSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.includes,
    this.timing,
    super.key,
  });

  final String title;

  /// «يشمل …» from the server's coverage; null while it is not known.
  final String? includes;

  /// When it comes, from the server's table; null when the table is not
  /// known or the switch has no schedule.
  final String? timing;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final includes = this.includes;
    final timing = value ? this.timing : context.text.switchOffLine;
    final onChanged = this.onChanged;
    return MergeSemantics(
      child: AarastPressable(
        onTap: onChanged == null ? null : () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AarastV3Size.row),
          child: Padding(
            padding: AarastV3Density.rowInsets,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: JourneyType.of(
                          JourneyType.body,
                          weight: JourneyType.bold,
                        ),
                      ),
                      if (includes != null)
                        Padding(
                          padding: const EdgeInsets.only(
                            top: AarastV3Space.half,
                          ),
                          child: Text(
                            includes,
                            style: JourneyType.of(
                              JourneyType.small,
                              color: AarastV3Color.textMuted,
                              height: AarastV3Line.normal,
                            ),
                          ),
                        ),
                      if (timing != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AarastV3Space.x1),
                          child: Text(
                            timing,
                            style: JourneyType.of(
                              JourneyType.small,
                              color: AarastV3Color.textFaint,
                              height: AarastV3Line.normal,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AarastV3Space.x3),
                JourneyToggle(
                  value: value,
                  onChanged: onChanged,
                  semanticLabel: title,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The switches' room while they load: rows of the same height, so the
/// page does not move when they arrive, and nothing reads as a switch.
class _SwitchesLoading extends StatelessWidget {
  const _SwitchesLoading({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AarastV3Color.line,
          borderRadius: BorderRadius.circular(AarastV3Radius.xs),
        ),
      ),
    );
    return ExcludeSemantics(
      child: JourneyBox(
        key: const Key('settings-switches-loading'),
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < count; i++)
              Padding(
                padding: AarastV3Density.rowInsets,
                child: SizedBox(
                  height: AarastV3Size.markLarge,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(.3, AarastV3Space.x3),
                      const SizedBox(height: AarastV3Space.x3),
                      bar(.8, AarastV3Space.x2),
                      const SizedBox(height: AarastV3Space.x2),
                      bar(.55, AarastV3Space.x2),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
