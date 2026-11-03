import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/config/api_config.dart';
import '../../../core/config/build_info.dart';
import '../../../core/diagnostics/app_logger.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/server_reachability.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';

/// D84 «فحص الاتصال»: what this build is, which server it talks to, what
/// the app measured when it last failed to reach it, and one fresh probe
/// on demand. The report is copied as text, so nobody guesses again.
class ConnectionCheckScreen extends StatefulWidget {
  const ConnectionCheckScreen({super.key});

  @override
  State<ConnectionCheckScreen> createState() => _ConnectionCheckScreenState();
}

class _ConnectionCheckScreenState extends State<ConnectionCheckScreen> {
  bool _probing = false;
  bool _probed = false;
  ReachabilityFailure? _probeFailure;
  DateTime? _probedAt;

  Future<void> _probe() async {
    final api = context.read<ApiClient>();
    setState(() => _probing = true);
    final failure = await api.probeLive();
    if (!mounted) return;
    setState(() {
      _probing = false;
      _probed = true;
      _probeFailure = failure;
      _probedAt = appNow();
    });
  }

  List<AppLogEvent> _recentFailures(BuildContext context) {
    final sink = Provider.of<MemoryRingBufferSink?>(context, listen: false);
    if (sink == null) return const [];
    final events = sink.events
        .where((event) => event.name == 'api_final_failure')
        .toList()
        .reversed
        .take(8)
        .toList();
    return events;
  }

  String _report(BuildContext context, ServerReachability? reachability) {
    final lines = <String>[
      'تقرير فحص الاتصال · ${_time(appNow())}',
      BuildInfo.label,
      'البيئة: ${BuildInfo.environment}',
      'الخادم: ${_serverHost()}',
    ];
    if (_probed) {
      final failure = _probeFailure;
      lines.add(
        failure == null
            ? 'الفحص: الخادم رد ✓'
            : 'الفحص: ${reachabilityCauseLabel(failure.cause)} (${failure.cause.name}) ${failure.detail ?? ''}'
                  .trim(),
      );
    }
    final last = reachability?.lastFailure;
    if (last != null) {
      lines.add(
        'آخر فشل: ${_time(last.at)} · ${last.path ?? ''} · ${reachabilityCauseLabel(last.cause)} (${last.cause.name}) ${last.detail ?? ''}'
            .trim(),
      );
    }
    final reached = reachability?.lastReachedAt;
    if (reached != null) lines.add('آخر رد من الخادم: ${_time(reached)}');
    for (final event in _recentFailures(context)) {
      final a = event.attributes;
      lines.add(
        '${_time(event.timestamp)} · ${a['method'] ?? ''} ${a['routeTemplate'] ?? ''} · ${a['errorType'] ?? ''} · ${a['statusCode'] ?? ''} · ${a['durationMs'] ?? ''}ms',
      );
    }
    return lines.join('\n');
  }

  Future<void> _copy(ServerReachability? reachability) async {
    await Clipboard.setData(
      ClipboardData(text: _report(context, reachability)),
    );
    if (!mounted) return;
    AarastToast.showSuccess(context, 'انسخ التقرير وأرسله لنا');
  }

  @override
  Widget build(BuildContext context) {
    final reachability = Provider.of<ServerReachability?>(context);
    final last = reachability?.lastFailure;
    final reached = reachability?.lastReachedAt;
    final failures = _recentFailures(context);
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: AarastV3Density.pageInsets,
        children: [
          JourneySubHeader(
            title: 'فحص الاتصال',
            subtitle: 'اللي قسناه، مو اللي خمّناه',
            onBack: () => context.popOrGo(AppRouter.more),
          ),
          JourneyBox(
            key: const ValueKey('connection-build'),
            padding: const EdgeInsets.all(AarastV3Space.x3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(LucideIcons.package, BuildInfo.label),
                const SizedBox(height: AarastV3Space.x1),
                _line(LucideIcons.server, 'الخادم: ${_serverHost()}'),
                if (reached != null) ...[
                  const SizedBox(height: AarastV3Space.x1),
                  _line(
                    LucideIcons.checkCircle2,
                    'آخر رد من الخادم: ${_time(reached)}',
                    color: AarastV3Color.mint,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AarastV3Space.x3),
          if (last != null) ...[
            JourneyNote(
              key: const ValueKey('connection-last-failure'),
              text:
                  'آخر مرة ما وصلنا (${_time(last.at)}): ${reachabilityCauseLabel(last.cause)}. ${reachabilityCauseAdvice(last.cause)}',
              icon: LucideIcons.alertTriangle,
              color: AarastV3Color.brandAccentStrong,
              soft: AarastV3Color.brandAccentSoft,
            ),
            const SizedBox(height: AarastV3Space.x3),
          ],
          JourneyButton(
            key: const ValueKey('connection-probe'),
            label: _probing ? 'نفحص…' : 'افحص الحين',
            icon: LucideIcons.activity,
            background: context.accent.primary,
            expand: true,
            large: true,
            loading: _probing,
            onPressed: _probing ? null : _probe,
          ),
          if (_probed) ...[
            const SizedBox(height: AarastV3Space.x2),
            JourneyNote(
              key: const ValueKey('connection-probe-result'),
              text: _probeFailure == null
                  ? 'الخادم رد الحين (${_time(_probedAt!)}). لو لافتة «بدون نت» باقية، أغلق التطبيق وافتحه.'
                  : '${reachabilityCauseLabel(_probeFailure!.cause)}. ${reachabilityCauseAdvice(_probeFailure!.cause)}',
              icon: _probeFailure == null
                  ? LucideIcons.checkCircle2
                  : LucideIcons.wifiOff,
              color: _probeFailure == null
                  ? AarastV3Color.mint
                  : AarastV3Color.danger,
              soft: _probeFailure == null
                  ? AarastV3Color.mintSoft
                  : AarastV3Color.dangerSoft,
            ),
          ],
          if (failures.isNotEmpty) ...[
            const SizedBox(height: AarastV3Space.x4),
            const JourneySectionTitle('آخر الطلبات اللي فشلت'),
            JourneyBox(
              key: const ValueKey('connection-failures'),
              padding: const EdgeInsets.all(AarastV3Space.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final event in failures)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: AarastV3Space.x1,
                      ),
                      child: Text(
                        '${_time(event.timestamp)} · ${event.attributes['method'] ?? ''} ${event.attributes['routeTemplate'] ?? ''} · ${_errorWord(event.attributes)}',
                        style: JourneyType.of(
                          JourneyType.small,
                          color: AarastV3Color.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AarastV3Space.x4),
          JourneyButton(
            key: const ValueKey('connection-copy'),
            label: 'انسخ التقرير',
            icon: LucideIcons.copy,
            background: context.accent.primarySoft,
            foreground: context.accent.primary,
            expand: true,
            large: true,
            onPressed: () => _copy(reachability),
          ),
          const SizedBox(height: AarastV3Space.x2),
          Text(
            'التقرير فيه النسخة والخادم وأسباب الفشل بس، بدون أرقام أو أسماء.',
            textAlign: TextAlign.center,
            style: JourneyType.of(
              JourneyType.small,
              color: AarastV3Color.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text, {Color? color}) => Row(
    children: [
      Icon(icon, size: 18, color: color ?? AarastV3Color.textMuted),
      const SizedBox(width: AarastV3Space.x2),
      Expanded(
        child: Text(
          text,
          style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
        ),
      ),
    ],
  );

  static String _serverHost() {
    final uri = Uri.tryParse(ApiConfig.baseUrl);
    return uri == null ? ApiConfig.baseUrl : uri.host;
  }

  static String _time(DateTime at) {
    final local = at.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }

  /// «مهلة» / «HTTP 500» / the dio type when nothing better is known.
  static String _errorWord(Map<String, Object?> attributes) {
    final status = attributes['statusCode'];
    if (status is int && status > 0) return 'HTTP $status';
    return switch (attributes['errorType']) {
      'connectionTimeout' ||
      'receiveTimeout' ||
      'sendTimeout' => 'الخادم تأخر',
      'connectionError' => 'ما وصلنا',
      'badCertificate' => 'الاتصال الآمن',
      final other => other?.toString() ?? '',
    };
  }
}
