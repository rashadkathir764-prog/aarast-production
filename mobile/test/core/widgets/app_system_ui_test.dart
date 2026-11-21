import 'package:aarast_mobile/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('light routes restore dark system icons after a dark route', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    final renderView = tester.binding.renderViews.first;
    final oldAdjustment = renderView.automaticSystemUiAdjustment;
    renderView.automaticSystemUiAdjustment = true;
    final darkRoute = ValueNotifier(true);
    addTearDown(() {
      darkRoute.dispose();
      tester.view.resetPadding();
      renderView.automaticSystemUiAdjustment = oldAdjustment;
    });
    await tester.pumpWidget(
      AarastSystemUiScope(
        child: ValueListenableBuilder<bool>(
          valueListenable: darkRoute,
          builder: (_, dark, _) => SizedBox.expand(
            child: dark
                ? const AnnotatedRegion<SystemUiOverlayStyle>(
                    value: SystemUiOverlayStyle.light,
                    child: ColoredBox(color: Colors.black),
                  )
                : const ColoredBox(color: Colors.white),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
    darkRoute.value = false;
    await tester.pump();
    await tester.pump();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
    expect(
      SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
      Brightness.dark,
    );
  });
}
