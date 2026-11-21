// Drives the real app (real database, real plugins) on a device or
// simulator. CI runs this on an iPhone simulator, which is the only place
// the iOS build is actually executed; see .github/workflows/ci.yml.
//
//   flutter test integration_test -d <device id>

import 'dart:io';

import 'package:corpus/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 30),
  );
}

/// Pumps until [finder] matches; database reads and asset loading are
/// real here, so things appear a moment after the tap that caused them.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      fail('Timed out waiting for $finder');
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
  await settle(tester);
}

/// [scrollTo] scrolls the control into view first (for buttons at the
/// bottom of long forms). Off by default so that tapping a row does not
/// move the page and push other content out of view.
Future<void> tapKey(
  WidgetTester tester,
  String key, {
  bool scrollTo = false,
}) async {
  final finder = find.byKey(ValueKey(key));
  await waitFor(tester, finder);
  if (scrollTo) {
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 300));
  }
  await tester.tap(finder);
  await settle(tester);
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.tap(finder.first);
  await settle(tester);
}

/// Holds the current screen for a moment so CI's screenshots catch it.
Future<void> hold(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 5));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the app works end to end on this device',
    (tester) async {
      await app.main();
      await waitFor(tester, find.text('MY RECORD'));
      await hold(tester);

      // + sheet: log a weight, then see it on the Health tab.
      await tapKey(tester, 'capture');
      expect(find.text('Log something'), findsOneWidget);
      await hold(tester);
      await tapKey(tester, 'capture-weight');
      await tester.enterText(find.byKey(const ValueKey('vital-value')), '72.5');
      await tapKey(tester, 'vital-save', scrollTo: true);
      await waitFor(tester, find.textContaining('72.5'));

      // Health booklet: add a medication.
      await tapKey(tester, 'section-medication');
      await tester.tap(find.byTooltip('Add medication'));
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('record-title')),
        'Ramipril',
      );
      await tapKey(tester, 'record-save', scrollTo: true);
      await waitFor(tester, find.text('Ramipril'));
      await tester.pageBack();
      await settle(tester);
      await waitFor(tester, find.text('Current medications'));
      await hold(tester);

      // Fitness and Sleep tabs open.
      await tapKey(tester, 'tab-fitness');
      await waitFor(tester, find.text('THIS WEEK'));
      await hold(tester);
      await tapKey(tester, 'tab-sleep');
      await tapKey(tester, 'sleep-add');
      await tapKey(tester, 'sleep-save', scrollTo: true);
      await waitFor(tester, find.text('LAST SLEEP'));
      await hold(tester);

      // Nutrition: the bundled food list is searchable and a food can be
      // logged. This proves the asset ships and loads on this platform.
      await tapKey(tester, 'tab-nutrition');
      await tapKey(tester, 'nutrition-add');
      final query = find.byKey(const ValueKey('food-query'));
      final banana = find.text('Bananas, raw');
      for (
        var attempt = 0;
        attempt < 10 && banana.evaluate().isEmpty;
        attempt++
      ) {
        // The list loads in the background on first launch; search again
        // until it is there.
        await tester.enterText(query, '');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.enterText(query, 'banana');
        await tester.pump(const Duration(seconds: 2));
      }
      expect(banana, findsOneWidget);
      await hold(tester);
      await tester.tap(banana);
      await settle(tester);
      await tapKey(tester, 'portion-save', scrollTo: true);
      await waitFor(tester, find.textContaining('left of 2000'));
      expect(find.text('Bananas, raw'), findsOneWidget);
      await hold(tester);

      // Menu pages.
      await tapKey(tester, 'menu');
      await tapText(tester, 'Habits');
      await tapKey(tester, 'habit-add');
      await tester.enterText(
        find.byKey(const ValueKey('habit-name')),
        'Stretch',
      );
      await tapKey(tester, 'habit-save', scrollTo: true);
      await tapKey(tester, 'habit-check-Stretch');
      await waitFor(tester, find.textContaining('1 of 1'));
      await hold(tester);
      await tester.pageBack();
      await settle(tester);

      await tapKey(tester, 'menu');
      await tapText(tester, "Women's health");
      await tapKey(tester, 'cycle-log-today');
      await tapText(tester, 'Medium');
      await tapKey(tester, 'cycle-save', scrollTo: true);
      await waitFor(tester, find.textContaining('Period · day 1'));
      await hold(tester);
      await tester.pageBack();
      await settle(tester);

      // Settings: on a phone, ask the health store for access. The system's
      // permission sheet cannot be tapped from here, so this only checks
      // that the request reaches Apple Health / Health Connect without
      // crashing; CI's screenshots show the sheet.
      await tapKey(tester, 'menu');
      await tapText(tester, 'Settings');
      await waitFor(tester, find.text('DAILY TARGETS'));
      await hold(tester);
      if (Platform.isIOS || Platform.isAndroid) {
        await tester.tap(find.byKey(const ValueKey('health-sync-switch')));
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
      }
      expect(tester.takeException(), isNull);

      // Presenting the system's Apple Health sheet makes iOS switch
      // accessibility on, and the framework then holds a semantics handle the
      // end-of-test check reports as a leak. Switch it back off here.
      // ignore: avoid_print
      print(
        'Platform accessibility on at end of test: '
        '${tester.platformDispatcher.semanticsEnabled}',
      );
      tester.platformDispatcher.semanticsEnabledTestValue = false;
      await tester.pump();

      // On a phone, leave a marker in the app's own storage that CI reads to
      // know every step above passed (iOS does not route the test's printed
      // output to the console CI can see).
      if (Platform.isIOS || Platform.isAndroid) {
        final dir = await getApplicationDocumentsDirectory();
        File('${dir.path}/e2e-result.txt').writeAsStringSync('PASS');
      }
    },
    // iOS keeps an accessibility (semantics) handle open for the app's
    // lifetime, which the framework's end-of-test check would report as a
    // leak. Nothing in this test relies on semantics.
    semanticsEnabled: false,
  );
}
