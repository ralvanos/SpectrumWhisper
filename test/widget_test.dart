import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spectrumwhisper/app.dart';
import 'package:spectrumwhisper/models.dart';
import 'package:spectrumwhisper/radio_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('opens on the live tab', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final env = RadioEnv();
    await tester.runAsync(() => env.load());
    env.settings.monitoring = false;
    await tester.pumpWidget(SpectrumApp(env: env));
    await tester.pump();
    expect(find.text('SpectrumWhisper'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Passive monitoring'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Feedback'), 400);
    expect(find.text('Send'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Monero'), 200);
    expect(find.text('Bitcoin'), findsOneWidget);
    expect(find.text('Monero'), findsOneWidget);
  });

  testWidgets('snapshot sheet shares this scan or a time range', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final env = RadioEnv();
    await tester.runAsync(() => env.load());
    env.settings.monitoring = false;
    final seen = DateTime.now();
    env.scanId = 1;
    env.lastScan = seen;
    env.rows['00:11:22:33:44:55'] = RadioRow(
      bssid: '00:11:22:33:44:55',
      ssid: 'Harbor-Office',
      hidden: false,
      firstSeen: seen,
      lastSeen: seen,
      presentSince: seen,
      lastVisitSec: 0,
      lastScanId: 1,
      seenScans: 1,
      bestDbm: -42,
      lastDbm: -42,
      band: '5',
      channel: 36,
      radio: '',
      auth: 'WPA2',
      capabilities: '[WPA2]',
      overrideCategory: '',
      signals: const [-42],
    );
    env.frames.add(
      Frame(
        at: seen,
        channels: const {'5:36': -42},
        counts: const {'5:36': 1},
        signals: const {'00:11:22:33:44:55': -42},
      ),
    );
    env.cell = const {
      'available': true,
      'operator': 'Example',
      'kind': 'LTE',
      'dbm': -91,
    };

    await tester.pumpWidget(SpectrumApp(env: env));
    await tester.pump();
    await tester.tap(find.text('Share snapshot'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Share image'), findsOneWidget);
    expect(find.text('Share text'), findsOneWidget);
    expect(find.text('Harbor-Office'), findsOneWidget);
    expect(find.textContaining('33:44:55'), findsNothing);
    expect(find.textContaining('Serving cell now'), findsOneWidget);

    await tester.tap(find.text('15 min'));
    await tester.pump();
    expect(find.text('Harbor-Office'), findsOneWidget);
    expect(find.textContaining('1 scan'), findsWidgets);

    Navigator.of(tester.element(find.text('Share image'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Share image'), findsNothing);
    expect(find.text('Share snapshot'), findsOneWidget);

    await tester.tap(find.text('Log'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Snapshot'), findsOneWidget);
  });
}
