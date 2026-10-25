// Real-app journey walks (docs/qa/JOURNEY_WALKS.md).
//
// Boots the actual application through `lib/main.dart` (real providers, real
// ApiClient, real local backend), signs in with a demo account the way a
// person does, and saves a PNG plus the visible text of every screen visited.
//
// Each step is a soft assertion: a failing step is recorded with its reason
// and screenshot, the walk goes on where it can, and the test fails at the end
// if any step failed. A failing step is a finding, not a harness bug.
//
// Inputs (all through --dart-define, nothing is stored in the repository):
//   AARAST_API_BASE_URL  the local API, e.g. http://127.0.0.1:3215
//   DEMO_PASSWORD        the password the demo seed was run with
//   AARAST_WALKS_DIR     where the screenshots and reports are written
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:aarast_mobile/features/notifications/notifications_api.dart'
    show NotificationsProvider, resolveNotificationRouteTarget;
import 'package:aarast_mobile/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const demoPassword = String.fromEnvironment('DEMO_PASSWORD');
const walksDirectory = String.fromEnvironment('AARAST_WALKS_DIR');
const apiBaseUrl = String.fromEnvironment('AARAST_API_BASE_URL');

/// The dev OTP code of the local API (`AUTH_OTP_MODE=dev`).
const devOtpCode = '123456';

/// The phone the designs are drawn for.
const phoneSurface = Size(390, 844);

enum StepResult { pass, fail }

class WalkStep {
  WalkStep(this.number, this.id, this.title);

  final int number;
  final String id;
  final String title;
  StepResult result = StepResult.pass;
  final List<String> problems = [];
  final List<String> notes = [];
  String? screenshot;

  Map<String, Object?> toJson() => {
    'number': number,
    'id': id,
    'title': title,
    'result': result.name,
    'problems': problems,
    'notes': notes,
    'screenshot': screenshot,
  };
}

/// One walk of one journey: its steps, screenshots and report.
class JourneyWalk {
  JourneyWalk(this.tester, this.journey);

  final WidgetTester tester;
  final String journey;
  final List<WalkStep> steps = [];
  WalkStep? _current;
  int _shot = 0;
  ErrorWidgetBuilder? _errorWidgetBuilder;
  void Function(FlutterErrorDetails)? _flutterErrorHandler;

  Directory get _dir {
    final root = walksDirectory.isEmpty
        ? '${Directory.systemTemp.path}${Platform.pathSeparator}aarast-walks'
        : walksDirectory;
    return Directory('$root${Platform.pathSeparator}$journey');
  }

  // ---------------------------------------------------------------- boot

  /// Starts the real app from a clean phone: no session, no saved plan.
  Future<void> boot() async {
    final dir = _dir;
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
    if (demoPassword.isEmpty) {
      throw StateError(
        'Pass --dart-define=DEMO_PASSWORD=<the password the demo seed used>.',
      );
    }
    if (apiBaseUrl.isEmpty) {
      throw StateError(
        'Pass --dart-define=AARAST_API_BASE_URL=http://127.0.0.1:3215.',
      );
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    try {
      await const FlutterSecureStorage().deleteAll();
    } on Object catch (error) {
      // ignore: avoid_print
      print('WALK $journey secure storage not cleared: $error');
    }
    await tester.binding.setSurfaceSize(phoneSurface);
    _errorWidgetBuilder = ErrorWidget.builder;
    _flutterErrorHandler = FlutterError.onError;
    await app.main();
    await settle(seconds: 4);
  }

  // ------------------------------------------------------------ waiting

  /// Pumps real frames for [seconds] (the network is real, so time is too).
  Future<void> settle({double seconds = 1.5}) async {
    final end = DateTime.now().add(
      Duration(milliseconds: (seconds * 1000).round()),
    );
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Pumps until [finder] shows or [seconds] pass. True when it showed.
  Future<bool> waitFor(Finder finder, {double seconds = 15}) async {
    final end = DateTime.now().add(
      Duration(milliseconds: (seconds * 1000).round()),
    );
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) {
        await settle(seconds: 0.8);
        return true;
      }
    }
    return false;
  }

  // ------------------------------------------------------------ finders

  Finder text(String value) => find.textContaining(value, findRichText: true);

  bool sees(String value) => text(value).evaluate().isNotEmpty;

  /// Every text on screen, top to bottom, as a person would read it.
  List<String> visibleTexts() {
    final seen = <String>[];
    for (final element in find.byType(RichText).evaluate()) {
      final widget = element.widget as RichText;
      final value = widget.text.toPlainText().trim();
      if (value.isEmpty) continue;
      // Icon glyphs are private-use characters, not words.
      if (value.runes.every((r) => r >= 0xE000 && r <= 0xF8FF)) continue;
      seen.add(value.replaceAll('\n', ' '));
    }
    for (final element in find.byType(EditableText).evaluate()) {
      final widget = element.widget as EditableText;
      final value = widget.controller.text.trim();
      if (value.isNotEmpty && !widget.obscureText) seen.add('[حقل] $value');
    }
    return seen;
  }

  // ------------------------------------------------------------- steps

  /// One step a person takes. [body] navigates and checks; a thrown error or
  /// a [expectSee] miss marks the step FAIL without stopping the walk.
  Future<void> step(
    String id,
    String title,
    Future<void> Function() body, {
    bool screenshot = true,
  }) async {
    final step = WalkStep(steps.length + 1, id, title);
    steps.add(step);
    _current = step;
    try {
      await body();
    } on Object catch (error) {
      step.result = StepResult.fail;
      step.problems.add('توقف الخطوة: ${_short(error)}');
    }
    if (screenshot) {
      try {
        step.screenshot = await capture(id);
      } on Object catch (error) {
        step.notes.add('ما انحفظت الصورة: ${_short(error)}');
      }
    }
    _current = null;
    // ignore: avoid_print
    print(
      'WALK $journey ${step.number.toString().padLeft(2, '0')} $id '
      '${step.result.name.toUpperCase()}'
      '${step.problems.isEmpty ? '' : ' :: ${step.problems.join(' | ')}'}',
    );
  }

  void fail(String problem) {
    final step = _current;
    if (step == null) throw StateError(problem);
    step.result = StepResult.fail;
    step.problems.add(problem);
  }

  void note(String value) => _current?.notes.add(value);

  /// The user must see [value] on this screen.
  bool expectSee(String value, {String? why}) {
    if (sees(value)) return true;
    fail('ما يظهر «$value»${why == null ? '' : ' ($why)'}');
    return false;
  }

  /// The user must NOT see [value] here (privacy, wrong role, stale text).
  bool expectNotSee(String value, {String? why}) {
    if (!sees(value)) return true;
    fail('يظهر «$value» وما لازم${why == null ? '' : ' ($why)'}');
    return false;
  }

  /// Taps the first visible [label] (a button, a tab, a card line).
  Future<bool> tapText(
    String label, {
    double wait = 2,
    bool last = false,
    bool required = true,
  }) async {
    var finder = text(label);
    if (finder.evaluate().isEmpty) {
      await _scrollUntilVisible(finder);
      finder = text(label);
    }
    if (finder.evaluate().isEmpty) {
      if (required) fail('ما فيه «$label» يُضغط');
      return false;
    }
    final target = last ? finder.last : finder.first;
    await tester.ensureVisible(target);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(target, warnIfMissed: false);
    await settle(seconds: wait);
    return true;
  }

  Future<bool> tapKey(String key, {double wait = 2, bool required = true}) async {
    final finder = find.byKey(ValueKey(key));
    if (finder.evaluate().isEmpty) await _scrollUntilVisible(finder);
    if (finder.evaluate().isEmpty) {
      if (required) fail('ما فيه زر ($key)');
      return false;
    }
    await tester.ensureVisible(finder.first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(finder.first, warnIfMissed: false);
    await settle(seconds: wait);
    return true;
  }

  /// Taps [label] inside the widget keyed [key] (a card, a header).
  Future<bool> tapWithin(
    String key,
    String label, {
    double wait = 2,
    bool required = true,
  }) async {
    final finder = find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: text(label),
    );
    if (finder.evaluate().isEmpty) {
      if (required) fail('ما فيه «$label» داخل ($key)');
      return false;
    }
    await tester.tap(finder.first, warnIfMissed: false);
    await settle(seconds: wait);
    return true;
  }

  /// Taps the button whose tooltip starts with [prefix] (icon buttons).
  Future<bool> tapTooltip(
    String prefix, {
    double wait = 2,
    bool required = true,
  }) async {
    final finder = find.byWidgetPredicate(
      (widget) =>
          widget is Tooltip && (widget.message ?? '').startsWith(prefix),
    );
    if (finder.evaluate().isEmpty) {
      if (required) fail('ما فيه زر «$prefix»');
      return false;
    }
    await tester.tap(finder.first, warnIfMissed: false);
    await settle(seconds: wait);
    return true;
  }

  /// Taps a tab of the bottom bar (the plan's five, or the provider's).
  Future<bool> tab(String label, {double wait = 3}) async {
    final bars = find.byWidgetPredicate((widget) {
      final name = widget.runtimeType.toString();
      return name == 'AarastPlanNavigationBar' ||
          name == 'ProviderPortalBottomNav';
    });
    final finder = find.descendant(of: bars, matching: text(label));
    if (finder.evaluate().isEmpty) {
      fail('ما فيه تبويب «$label» في الشريط السفلي');
      return false;
    }
    await tester.tap(finder.first, warnIfMissed: false);
    await settle(seconds: wait);
    return true;
  }

  Future<bool> tapIcon(IconData icon, {double wait = 2, bool required = true}) async {
    final finder = find.byIcon(icon);
    if (finder.evaluate().isEmpty) {
      if (required) fail('ما فيه الأيقونة المطلوبة');
      return false;
    }
    await tester.tap(finder.first, warnIfMissed: false);
    await settle(seconds: wait);
    return true;
  }

  /// The way back a person has: the app bar's back arrow, else the system
  /// back (Escape on desktop does nothing, so the router pop is used).
  Future<void> back({double wait = 1.5}) async {
    final backButton = find.byTooltip('رجوع');
    if (backButton.evaluate().isNotEmpty) {
      await tester.tap(backButton.first, warnIfMissed: false);
    } else {
      final nav = find.byType(BackButton);
      if (nav.evaluate().isNotEmpty) {
        await tester.tap(nav.first, warnIfMissed: false);
      } else {
        await tester.binding.handlePopRoute();
      }
    }
    await settle(seconds: wait);
  }

  /// Scrolls the main list down by [pixels], like a thumb.
  Future<void> scroll({double pixels = 500}) async {
    final scrollables = find.byType(Scrollable).hitTestable();
    if (scrollables.evaluate().isEmpty) return;
    await tester.drag(
      scrollables.first,
      Offset(0, -pixels),
      warnIfMissed: false,
    );
    await settle(seconds: 0.8);
  }

  /// Looks up the page first (a header scrolled away), then down.
  Future<void> _scrollUntilVisible(Finder finder) async {
    for (final dy in [450.0, -350.0]) {
      for (var i = 0; i < 7 && finder.evaluate().isEmpty; i++) {
        final scrollables = find.byType(Scrollable).hitTestable();
        if (scrollables.evaluate().isEmpty) return;
        await tester.drag(
          scrollables.first,
          Offset(0, dy),
          warnIfMissed: false,
        );
        await settle(seconds: 0.4);
      }
    }
  }

  /// Taps the control a screen reader names [label] (an avatar button).
  Future<bool> tapSemantics(
    String label, {
    double wait = 2,
    bool required = true,
  }) async {
    final finder = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    );
    if (finder.evaluate().isEmpty) {
      if (required) fail('ما فيه زر «$label»');
      return false;
    }
    await tester.tap(finder.first, warnIfMissed: false);
    await settle(seconds: wait);
    return true;
  }

  Future<void> enterField(String label, String value) async {
    final field = find.ancestor(
      of: text(label),
      matching: find.byType(TextFormField),
    );
    final target = field.evaluate().isNotEmpty
        ? field.first
        : find.byType(EditableText).first;
    await tester.tap(target, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(target, value);
    await tester.pump(const Duration(milliseconds: 150));
  }

  /// Direct navigation, only where a person has no button to the screen.
  /// Every use is written in the step's notes as a finding.
  Future<void> goTo(String location, {double wait = 3}) async {
    final element = find.byType(Navigator).evaluate().first;
    note('وصلنا للشاشة برابط مباشر $location (ما لقينا زر)');
    GoRouter.of(element).go(location);
    await settle(seconds: wait);
  }

  String? currentLocation() {
    final navigators = find.byType(Navigator).evaluate();
    if (navigators.isEmpty) return null;
    try {
      final router = GoRouter.of(navigators.first);
      return router.routeInformationProvider.value.uri.toString();
    } on Object {
      return null;
    }
  }

  /// B-19: taps every notice on the list (rows keyed `<keyPrefix><id>`),
  /// checks the app lands on the screen the notice names, not on the error
  /// page, and comes back to [home] for the next one. Opening a notice reads
  /// it (the only thing the walk changes). Each landing is written in the
  /// step's notes.
  Future<void> openEachNotice({
    required String keyPrefix,
    required String home,
    int limit = 12,
  }) async {
    final element = find.byType(Navigator).evaluate().first;
    final notices = [
      ...Provider.of<NotificationsProvider>(
        element,
        listen: false,
      ).notifications,
    ];
    var opened = 0;
    for (final notice in notices) {
      if (opened >= limit) break;
      final row = find.byKey(ValueKey('$keyPrefix${notice.id}'));
      if (row.evaluate().isEmpty) await _scrollUntilVisible(row);
      if (row.evaluate().isEmpty) continue;
      final expected = resolveNotificationRouteTarget(notice);
      await tester.ensureVisible(row.first);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(row.first, warnIfMissed: false);
      await settle(seconds: 3);
      opened += 1;
      final landed = currentLocation();
      final errorPage = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == 'RouterErrorScreen',
      );
      if (expected == null) {
        fail('تنبيه «${notice.title}» ما له شاشة');
      } else if (errorPage.evaluate().isNotEmpty) {
        fail('تنبيه «${notice.title}» فتح صفحة الخطأ ($expected)');
      } else if (landed == null ||
          !_sameScreen(Uri.parse(landed), Uri.parse(expected))) {
        fail('تنبيه «${notice.title}» فتح $landed بدل $expected');
      } else {
        note('${notice.type} «${notice.title}» → $landed');
      }
      GoRouter.of(find.byType(Navigator).evaluate().first).go(home);
      await settle(seconds: 3);
    }
    if (opened == 0) fail('ما فيه تنبيه يُفتح في القائمة');
  }

  /// The same screen: the same path, or the requests page a quote link of
  /// the providers' list opens (`/providers?quoteId=` passes the plan's).
  static bool _sameScreen(Uri landed, Uri expected) {
    if (landed.path == expected.path) {
      return expected.queryParameters.entries.every(
        (entry) => landed.queryParameters[entry.key] == entry.value,
      );
    }
    final quoteId = expected.queryParameters['quoteId'];
    return expected.path == '/providers' &&
        quoteId != null &&
        landed.path.endsWith('/providers/requests') &&
        landed.queryParameters['quote'] == quoteId;
  }

  // ------------------------------------------------------------ sign in

  /// Signs in by phone and password as a person does, then picks [context]
  /// (a visible text on the «خطة مين؟» card) when the account holds several.
  /// The sign-in itself (inside the current step): welcome → «عندي حساب» →
  /// phone and password → the dev OTP when asked.
  Future<void> signInOnly(String phone) async {
    if (!await waitFor(find.byKey(const ValueKey('login-submit')), seconds: 4)) {
      // The welcome gateway: its «عندي حساب» way in.
      for (final label in ['عندي حساب', 'تسجيل الدخول', 'دخول']) {
        if (await tapText(label, required: false, wait: 2.5)) break;
      }
    }
    if (!await waitFor(find.byKey(const ValueKey('login-submit')), seconds: 8)) {
      fail('ما وصلنا لشاشة الدخول من الترحيب');
      return;
    }
    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), phone);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(fields.at(1), demoPassword);
    await tester.pump(const Duration(milliseconds: 150));
    await tapKey('login-submit', wait: 4);
    // A second factor when the API asks for it.
    if (sees('رمز') && find.byType(EditableText).evaluate().isNotEmpty &&
        find.byKey(const ValueKey('login-submit')).evaluate().isEmpty) {
      await tester.enterText(find.byType(EditableText).first, devOtpCode);
      await settle(seconds: 4);
    }
    await settle(seconds: 2);
    if (find.byKey(const ValueKey('login-submit')).evaluate().isNotEmpty) {
      fail('بقينا في شاشة الدخول بعد الضغط');
    }
  }

  Future<void> signIn(String phone, {String? pickContext}) async {
    await step('auth-login', 'الدخول برقم $phone', () async {
      await signInOnly(phone);
      if (pickContext != null) {
        if (await waitFor(text(pickContext), seconds: 8)) {
          if (sees('اختر المسار') || sees('خطة مين')) {
            await tapText(pickContext, wait: 4);
          }
        }
      }
      await settle(seconds: 3);
      if (find.byKey(const ValueKey('login-submit')).evaluate().isNotEmpty) {
        fail('بقينا في شاشة الدخول بعد الضغط');
      }
    });
  }

  /// After a sign-out: the welcome or the login screen, nothing else.
  Future<bool> waitSignedOut() async {
    final end = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      if (sees('عندي حساب') ||
          find.byKey(const ValueKey('login-submit')).evaluate().isNotEmpty) {
        await settle(seconds: 0.8);
        return true;
      }
    }
    fail('بعد الخروج ما رجعنا لشاشة الترحيب أو الدخول');
    return false;
  }

  // --------------------------------------------------------- screenshot

  /// Saves what the phone shows now as `<nn>_<name>.png` (and `.txt`, the
  /// visible text), cropped to the 390x844 phone surface.
  Future<String> capture(String name) async {
    await settle(seconds: 0.6);
    _shot++;
    final base =
        '${_dir.path}${Platform.pathSeparator}'
        '${_shot.toString().padLeft(2, '0')}_${_safe(name)}';
    final renderView = tester.binding.renderViews.first;
    final layer = renderView.debugLayer! as OffsetLayer;
    final logical = renderView.size;
    final bounds = MatrixUtils.transformRect(
      renderView.configuration.toMatrix(),
      Offset.zero & logical,
    );
    final ratio = (logical.width * 2) / bounds.width;
    final image = await layer.toImage(bounds, pixelRatio: ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await File('$base.png').writeAsBytes(bytes!.buffer.asUint8List());
    final where = currentLocation();
    await File('$base.txt').writeAsString(
      [if (where != null) '# $where', ...visibleTexts()].join('\n'),
    );
    return '$base.png';
  }

  // ------------------------------------------------------------- report

  /// Writes report.json and fails the test when any step failed.
  Future<void> finish() async {
    final failed = steps.where((s) => s.result == StepResult.fail).toList();
    final report = {
      'journey': journey,
      'api': apiBaseUrl,
      'finishedAt': DateTime.now().toIso8601String(),
      'passed': steps.length - failed.length,
      'failed': failed.length,
      'steps': steps.map((s) => s.toJson()).toList(),
    };
    await File(
      '${_dir.path}${Platform.pathSeparator}report.json',
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    // The app installs its own error screen and handler
    // (AarastBuildErrorBoundary, lib/app.dart). Its dispose restores the
    // builder it saw at initState, which after a sign-in is the previous
    // boundary's (finding in JOURNEY_WALKS.md), so the tree is unmounted
    // first and the test binding's own builder put back after.
    await tester.pumpWidget(const SizedBox.shrink());
    if (_errorWidgetBuilder != null) ErrorWidget.builder = _errorWidgetBuilder!;
    FlutterError.onError = _flutterErrorHandler;
    // ignore: avoid_print
    print(
      'WALK $journey DONE ${steps.length - failed.length}/${steps.length} '
      'steps passed',
    );
    expect(
      failed.map((s) => '${s.number} ${s.id}: ${s.problems.join(' | ')}'),
      isEmpty,
      reason: 'Journey "$journey" has failing steps (see report.json).',
    );
  }

  static String _safe(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');

  static String _short(Object error) {
    final text = error.toString().replaceAll('\n', ' ');
    return text.length > 300 ? '${text.substring(0, 300)}…' : text;
  }
}
