import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spectrumwhisper/logic/radio_math.dart';
import 'package:spectrumwhisper/logic/snapshot.dart';
import 'package:spectrumwhisper/models.dart';
import 'package:spectrumwhisper/radio_env.dart';
import 'package:spectrumwhisper/theme.dart';
import 'package:spectrumwhisper/widgets/snapshot_card.dart';

void main() {
  final moment = DateTime.utc(2026, 10, 3, 23, 51);

  SnapshotIdentity id({
    required String name,
    required String band,
    required int channel,
    String category = 'router',
    String auth = 'WPA2',
    bool hidden = false,
    bool watched = false,
  }) {
    return SnapshotIdentity(
      name: name,
      band: band,
      channel: channel,
      category: category,
      auth: auth,
      vendor: 'Cisco',
      hidden: hidden,
      watched: watched,
    );
  }

  AreaSnapshot shot({
    SnapshotRange range = SnapshotRange.now,
    List<ScanSlice> slices = const [],
    Map<String, SnapshotIdentity> identities = const {},
    int minDbm = -100,
    bool showHidden = true,
    List<String> bands = const ['2.4', '5', '6'],
    bool sample = false,
    String cellular = '',
  }) {
    final from = slices.isEmpty ? moment : slices.first.at;
    final to = slices.isEmpty ? moment : slices.last.at;
    return composeSnapshot(
      range: range,
      sample: sample,
      from: from,
      to: to,
      slices: slices,
      identities: identities,
      minDbm: minDbm,
      showHidden: showHidden,
      bands: bands,
      txDbm: 18,
      exponent: 3,
      distanceUnit: 'm',
      signalUnit: 'dbm',
      cellular: cellular,
    );
  }

  test('a point in time summarizes bands, signal, and the loudest network', () {
    final snapshot = shot(
      sample: true,
      cellular: 'Example LTE -91 dBm',
      identities: {
        '00:11:22:33:44:55': id(name: 'Harbor-Office', band: '5', channel: 36),
        '00:11:22:33:44:66': id(
          name: 'Cafe',
          band: '2.4',
          channel: 6,
          category: 'hotspot',
          auth: 'Open',
        ),
      },
      slices: [
        ScanSlice(
          at: moment,
          signals: const {'00:11:22:33:44:55': -42, '00:11:22:33:44:66': -68},
        ),
      ],
    );

    expect(snapshot.radios.map((radio) => radio.name), [
      'Harbor-Office',
      'Cafe',
    ]);
    expect(snapshot.band5, 1);
    expect(snapshot.band24, 1);
    expect(snapshot.strong, 1);
    expect(snapshot.fair, 1);
    expect(snapshot.channelCount, 2);
    expect(snapshot.analysis, contains('2 networks on 2 channels'));
    expect(snapshot.analysis, contains('1 on 2.4 GHz and 1 on 5 GHz'));
    expect(snapshot.analysis, contains('1 open'));
    expect(
      snapshot.analysis,
      contains('The loudest is Harbor-Office at -42 dBm'),
    );
    expect(snapshot.categoryLine, contains('Hotspot 1'));
    expect(snapshot.securityLine, contains('1 Open'));
    expect(snapshot.quietLine, contains('is 1, with no access points'));
    expect(snapshot.busyLine, contains('5 GHz channel 36'));
    expect(snapshot.windowLabel, startsWith('This scan'));

    final hidden = snapshot.shareText(redactBssid: true);
    expect(hidden, contains('00:11:22:xx:xx:xx'));
    expect(hidden.contains('00:11:22:33:44:55'), isFalse);
    expect(hidden, contains('Sample environment'));
    expect(hidden, contains('Serving cell now: Example LTE -91 dBm'));
    expect(hidden, contains('No traffic was captured'));
  });

  test('a range keeps the strongest reading and who stayed', () {
    final first = moment.subtract(const Duration(minutes: 8));
    final snapshot = shot(
      range: SnapshotRange.quarterHour,
      identities: {
        'aa': id(name: 'Steady', band: '2.4', channel: 1),
        'bb': id(name: 'Brief', band: '2.4', channel: 11),
      },
      slices: [
        ScanSlice(at: first, signals: const {'aa': -70, 'bb': -50}),
        ScanSlice(at: moment, signals: const {'aa': -40}),
      ],
    );

    final steady = snapshot.radios.firstWhere(
      (radio) => radio.name == 'Steady',
    );
    final brief = snapshot.radios.firstWhere((radio) => radio.name == 'Brief');
    expect(steady.bestDbm, -40);
    expect(steady.lastDbm, -40);
    expect(steady.hits, 2);
    expect(brief.hits, 1);
    expect(brief.lastDbm, -50);
    expect(snapshot.scans, 2);
    expect(
      snapshot.activityLine,
      contains('1 network was heard on every scan'),
    );
    expect(snapshot.activityLine, contains('1 only some of the time'));
    expect(
      snapshot.shareText(redactBssid: false),
      contains('heard 2 of 2 scans'),
    );
  });

  test(
    'four scans describe channels that stayed and the quietest 2.4 channel',
    () {
      final slices = [
        for (var i = 0; i < 4; i++)
          ScanSlice(
            at: moment.subtract(Duration(minutes: 12 - (i * 3))),
            signals: const {'aa': -48},
          ),
      ];
      final snapshot = shot(
        range: SnapshotRange.hour,
        identities: {'aa': id(name: 'Lobby', band: '2.4', channel: 1)},
        slices: slices,
      );

      expect(
        snapshot.activityLine,
        contains('Every network was heard on all 4 scans'),
      );
      expect(snapshot.activityLine, contains('1 channel stayed present'));
      expect(snapshot.quietLine, contains('is 6, with no access points'));
      expect(snapshot.busyLine, contains('2.4 GHz channel 1'));
    },
  );

  test('hidden radios and weak readings stay out of the snapshot', () {
    final hidden = shot(
      showHidden: false,
      identities: {
        'aa': id(name: 'Secret', band: '5', channel: 40, hidden: true),
      },
      slices: [
        ScanSlice(at: moment, signals: const {'aa': -40}),
      ],
    );
    expect(hidden.radios, isEmpty);
    expect(hidden.analysis, contains('Nothing in this window matched'));

    final weak = shot(
      minDbm: -60,
      identities: {'aa': id(name: 'Faint', band: '5', channel: 40)},
      slices: [
        ScanSlice(at: moment, signals: const {'aa': -80}),
      ],
    );
    expect(weak.radios, isEmpty);

    final droppedBand = shot(
      bands: const ['2.4'],
      identities: {'aa': id(name: 'Upstairs', band: '6', channel: 5)},
      slices: [
        ScanSlice(at: moment, signals: const {'aa': -40}),
      ],
    );
    expect(droppedBand.radios, isEmpty);

    expect(shot().analysis, 'No scans in this window.');
  });

  test('hour uses the log, and session stays with this visit', () {
    final env = RadioEnv();
    env.scanId = 4;
    env.rows['00:00:0C:11:22:01'] = _row(
      bssid: '00:00:0C:11:22:01',
      ssid: 'Harbor-Office',
      dbm: -44,
      band: '5',
      channel: 36,
      scan: 4,
      seen: moment.subtract(const Duration(minutes: 10)),
    );
    env.rows['00:11:22:33:44:70'] = _row(
      bssid: '00:11:22:33:44:70',
      ssid: 'OldNet',
      dbm: -60,
      band: '2.4',
      channel: 1,
      scan: 1,
      seen: moment.subtract(const Duration(hours: 3)),
    );
    env.frames.add(
      Frame(
        at: moment.subtract(const Duration(hours: 3)),
        channels: const {'2.4:1': -60},
        counts: const {'2.4:1': 1},
        signals: const {'00:11:22:33:44:70': -60},
      ),
    );
    env.observations.add(
      Obs(
        at: moment.subtract(const Duration(minutes: 20)),
        bssid: '02:11:22:33:44:80',
        ssid: 'LoggedNet',
        dbm: -51,
        band: '5',
        channel: 44,
      ),
    );
    env.cell = const {
      'available': true,
      'operator': 'Example',
      'kind': 'LTE',
      'dbm': -90,
    };

    final point = env.areaSnapshot(SnapshotRange.now, now: moment);
    expect(point.radios.map((radio) => radio.name), ['Harbor-Office']);
    expect(point.to, moment.subtract(const Duration(minutes: 10)));
    expect(point.cellular, contains('Example'));
    expect(point.categoryLine, contains('Router'));

    final hour = env.areaSnapshot(SnapshotRange.hour, now: moment);
    expect(hour.radios.map((radio) => radio.name).toSet(), {
      'Harbor-Office',
      'LoggedNet',
    });
    expect(hour.radios.map((radio) => radio.name), isNot(contains('OldNet')));

    final session = env.areaSnapshot(SnapshotRange.session, now: moment);
    expect(session.radios.map((radio) => radio.name), ['OldNet']);
  });

  testWidgets(
    'the snapshot card shows the loudest radios and counts the rest',
    (tester) async {
      final identities = <String, SnapshotIdentity>{};
      final signals = <String, int>{};
      for (var i = 0; i < 9; i++) {
        final key = 'radio-$i';
        identities[key] = id(name: 'Net $i', band: '5', channel: 36 + i);
        signals[key] = -30 - i;
      }
      final snapshot = shot(
        identities: identities,
        slices: [ScanSlice(at: moment, signals: signals)],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: swTheme(),
          home: Scaffold(
            body: ListView(children: [SnapshotCard(snapshot: snapshot)]),
          ),
        ),
      );

      expect(find.text('Net 0'), findsOneWidget);
      expect(find.text('Net 8'), findsNothing);
      expect(find.text('1 more network is in the text share.'), findsOneWidget);
      expect(find.text('9'), findsWidgets);
    },
  );
}

RadioRow _row({
  required String bssid,
  required String ssid,
  required int dbm,
  required String band,
  required int channel,
  required int scan,
  required DateTime seen,
}) {
  return RadioRow(
    bssid: bssid,
    ssid: ssid,
    hidden: false,
    firstSeen: seen,
    lastSeen: seen,
    presentSince: seen,
    lastVisitSec: 0,
    lastScanId: scan,
    seenScans: 1,
    bestDbm: dbm,
    lastDbm: dbm,
    band: band,
    channel: channel,
    radio: '',
    auth: authFromCapabilities('[WPA2-PSK-CCMP]'),
    capabilities: '[WPA2-PSK-CCMP]',
    overrideCategory: '',
    signals: [dbm],
  );
}
