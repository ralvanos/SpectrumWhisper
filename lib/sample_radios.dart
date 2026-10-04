import 'dart:math';

import 'models.dart';

int _wave(DateTime now, int base, int swing, double speed) {
  final t = now.millisecondsSinceEpoch / 1000.0;
  return (base + swing * sin(t / speed)).round().clamp(-96, -35);
}

int? _passing(DateTime now, int period, int start, int length) {
  final phase = now.millisecondsSinceEpoch ~/ 1000 % period;
  if (phase < start || phase > start + length) return null;
  final along = (phase - start) / length;
  return ( -75 + sin(along * pi) * 30).round().clamp(-90, -40);
}

List<Heard> sampleHeard(DateTime now) {
  final rows = <Heard>[
    Heard(ssid: 'Harbor-Office', bssid: '00:00:0C:11:22:01', dbm: _wave(now, -57, 2, 40), frequencyMhz: 5180, radio: '802.11ax', capabilities: '[WPA2-PSK-CCMP][ESS]', widthMhz: 80, centerMhz: 5210),
    Heard(ssid: 'Harbor-IoT', bssid: '00:1B:21:10:20:02', dbm: _wave(now, -65, 2, 55), frequencyMhz: 2437, radio: '802.11n', capabilities: '[WPA2-PSK-CCMP][ESS]', widthMhz: 20, centerMhz: 2437),
    Heard(ssid: 'eduroam', bssid: '18:E8:29:AA:10:03', dbm: _wave(now, -69, 1, 70), frequencyMhz: 5220, radio: '802.11ac', capabilities: '[WPA2-EAP-CCMP][ESS]', widthMhz: 80, centerMhz: 5210),
    Heard(ssid: 'xfinitywifi', bssid: '00:25:9C:31:00:04', dbm: _wave(now, -81, 2, 33), frequencyMhz: 2462, radio: '802.11n', capabilities: '[ESS]', widthMhz: 20, centerMhz: 2462),
    Heard(ssid: 'Unit-4B', bssid: 'F0:9F:C2:44:00:05', dbm: _wave(now, -61, 1, 48), frequencyMhz: 5745, radio: '802.11ax', capabilities: '[WPA3-SAE-CCMP][ESS]', widthMhz: 80, centerMhz: 5775),
    Heard(ssid: 'WL-4481', bssid: '50:C7:BF:90:00:08', dbm: _wave(now, -73, 3, 25), frequencyMhz: 2412, radio: '802.11n', capabilities: '[WPA2-PSK-CCMP][ESS]', widthMhz: 20, centerMhz: 2412),
    Heard(ssid: 'Pixel Hotspot', bssid: 'F4:F5:D8:21:00:07', dbm: _wave(now, -76, 2, 36), frequencyMhz: 2462, radio: '802.11ax', capabilities: '[WPA2-PSK-CCMP][ESS]', widthMhz: 20, centerMhz: 2462),
    const Heard(ssid: '', bssid: 'B0:95:75:12:00:09', dbm: -86, frequencyMhz: 2437, radio: '802.11n', capabilities: '[WPA2-PSK-CCMP][ESS]', hidden: true, widthMhz: 20, centerMhz: 2437),
  ];
  final tesla = _passing(now, 180, 15, 70);
  if (tesla != null) {
    rows.add(Heard(ssid: 'Tesla_ModelY', bssid: '02:11:22:33:44:10', dbm: tesla, frequencyMhz: 5805, radio: '802.11ax', capabilities: '[WPA2-PSK-CCMP][ESS]', widthMhz: 40, centerMhz: 5795));
  }
  final phone = _passing(now, 140, 80, 40);
  if (phone != null) {
    rows.add(Heard(ssid: 'Mira iPhone', bssid: '00:03:93:77:00:11', dbm: phone, frequencyMhz: 2437, radio: '802.11ax', capabilities: '[WPA2-PSK-CCMP][ESS]', widthMhz: 20, centerMhz: 2437));
  }
  final road = _passing(now, 220, 120, 35);
  if (road != null) {
    rows.add(Heard(ssid: 'Road-44', bssid: 'AC:84:C6:55:00:12', dbm: road, frequencyMhz: 5200, radio: '802.11ac', capabilities: '[WPA2-PSK-CCMP][ESS]', widthMhz: 80, centerMhz: 5210));
  }
  return rows;
}

RadioRow _row({
  required String ssid,
  required String bssid,
  required bool hidden,
  required DateTime first,
  required DateTime last,
  required DateTime? present,
  required double lastVisit,
  required int lastScan,
  required int seen,
  required int best,
  required int lastDbm,
  required String band,
  required int channel,
  required String radio,
  required String auth,
  required List<int> signals,
}) {
  return RadioRow(
    bssid: bssid,
    ssid: ssid,
    hidden: hidden,
    firstSeen: first,
    lastSeen: last,
    presentSince: present,
    lastVisitSec: lastVisit,
    lastScanId: lastScan,
    seenScans: seen,
    bestDbm: best,
    lastDbm: lastDbm,
    band: band,
    channel: channel,
    radio: radio,
    auth: auth,
    capabilities: '',
    overrideCategory: '',
    signals: signals,
  );
}

Map<String, RadioRow> seedSample(DateTime now) {
  return {
    '00:00:0C:11:22:01': _row(ssid: 'Harbor-Office', bssid: '00:00:0C:11:22:01', hidden: false, first: now.subtract(const Duration(hours: 6)), last: now, present: now.subtract(const Duration(hours: 6)), lastVisit: 0, lastScan: 99, seen: 800, best: -52, lastDbm: -57, band: '5', channel: 36, radio: '802.11ax', auth: 'WPA2', signals: [-58, -57, -56, -57, -58]),
    '00:1B:21:10:20:02': _row(ssid: 'Harbor-IoT', bssid: '00:1B:21:10:20:02', hidden: false, first: now.subtract(const Duration(hours: 5)), last: now, present: now.subtract(const Duration(hours: 5)), lastVisit: 0, lastScan: 99, seen: 600, best: -60, lastDbm: -65, band: '2.4', channel: 6, radio: '802.11n', auth: 'WPA2', signals: [-66, -65, -64, -65]),
    '18:E8:29:AA:10:03': _row(ssid: 'eduroam', bssid: '18:E8:29:AA:10:03', hidden: false, first: now.subtract(const Duration(hours: 8)), last: now, present: now.subtract(const Duration(hours: 8)), lastVisit: 0, lastScan: 99, seen: 900, best: -64, lastDbm: -69, band: '5', channel: 44, radio: '802.11ac', auth: 'WPA2', signals: [-70, -69, -68, -69]),
    '00:25:9C:31:00:04': _row(ssid: 'xfinitywifi', bssid: '00:25:9C:31:00:04', hidden: false, first: now.subtract(const Duration(hours: 2)), last: now, present: now.subtract(const Duration(hours: 2)), lastVisit: 0, lastScan: 99, seen: 200, best: -74, lastDbm: -81, band: '2.4', channel: 11, radio: '802.11n', auth: 'Open', signals: [-82, -81, -80, -81]),
    'F0:9F:C2:44:00:05': _row(ssid: 'Unit-4B', bssid: 'F0:9F:C2:44:00:05', hidden: false, first: now.subtract(const Duration(hours: 3)), last: now, present: now.subtract(const Duration(hours: 3)), lastVisit: 0, lastScan: 99, seen: 400, best: -55, lastDbm: -61, band: '5', channel: 149, radio: '802.11ax', auth: 'WPA3', signals: [-62, -61, -60, -61]),
    '50:C7:BF:90:00:08': _row(ssid: 'WL-4481', bssid: '50:C7:BF:90:00:08', hidden: false, first: now.subtract(const Duration(seconds: 90)), last: now, present: now.subtract(const Duration(seconds: 90)), lastVisit: 0, lastScan: 99, seen: 3, best: -70, lastDbm: -73, band: '2.4', channel: 1, radio: '802.11n', auth: 'WPA2', signals: [-74, -73, -72]),
    'F4:F5:D8:21:00:07': _row(ssid: 'Pixel Hotspot', bssid: 'F4:F5:D8:21:00:07', hidden: false, first: now.subtract(const Duration(days: 3)), last: now, present: now.subtract(const Duration(minutes: 20)), lastVisit: 0, lastScan: 99, seen: 30, best: -70, lastDbm: -76, band: '2.4', channel: 11, radio: '802.11ax', auth: 'WPA2', signals: [-78, -76, -75, -77]),
    'B0:95:75:12:00:09': _row(ssid: '', bssid: 'B0:95:75:12:00:09', hidden: true, first: now.subtract(const Duration(seconds: 40)), last: now, present: now.subtract(const Duration(seconds: 40)), lastVisit: 0, lastScan: 99, seen: 2, best: -84, lastDbm: -86, band: '2.4', channel: 6, radio: '802.11n', auth: 'WPA2', signals: [-86, -85]),
    '02:11:22:33:44:10': _row(ssid: 'Tesla_ModelY', bssid: '02:11:22:33:44:10', hidden: false, first: now.subtract(const Duration(days: 2)), last: now.subtract(const Duration(seconds: 50)), present: null, lastVisit: 48, lastScan: 80, seen: 36, best: -50, lastDbm: -70, band: '5', channel: 161, radio: '802.11ax', auth: 'WPA2', signals: [-60, -70, -82]),
    'AC:84:C6:55:00:12': _row(ssid: 'Road-44', bssid: 'AC:84:C6:55:00:12', hidden: false, first: now.subtract(const Duration(days: 1)), last: now.subtract(const Duration(seconds: 80)), present: null, lastVisit: 35, lastScan: 70, seen: 14, best: -55, lastDbm: -80, band: '5', channel: 40, radio: '802.11ac', auth: 'WPA2', signals: [-60, -75, -84, -88]),
  };
}
