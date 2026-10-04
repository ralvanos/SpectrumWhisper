import 'dart:math';

import '../constants.dart';
import '../device_catalog.dart';
import '../oui_table.dart';

class BandChannel {
  const BandChannel(this.band, this.channel);
  final String band;
  final int channel;
}

BandChannel bandOf(int frequencyMhz) {
  if (frequencyMhz >= 5925) {
    return BandChannel('6', ((frequencyMhz - 5950) / 5).round());
  }
  if (frequencyMhz >= 4900) {
    return BandChannel('5', ((frequencyMhz - 5000) / 5).round());
  }
  if (frequencyMhz >= 2400) {
    final channel = frequencyMhz >= 2484 ? 14 : ((frequencyMhz - 2407) / 5).round();
    return BandChannel('2.4', channel);
  }
  return const BandChannel('', 0);
}

int frequencyMhz(String band, int channel) {
  if (band == '2.4') {
    if (channel == 14) return 2484;
    return 2407 + 5 * channel;
  }
  if (band == '5') return 5000 + 5 * channel;
  if (band == '6') return 5950 + 5 * channel;
  return 2437;
}

int dbmToQuality(int dbm) => ((dbm + 100) * 2).clamp(0, 100);

/// True when [stamp] belongs to the same scan as [newest].
/// Both values are microseconds since boot. A missing stamp is kept.
bool stampIsCurrent(int? stamp, int? newest) {
  if (stamp == null || newest == null) return true;
  final age = newest - stamp;
  return age >= 0 && age <= 20000000;
}

/// Channel 1–13 with the fewest access points in [counts]. Ties prefer 1, then 6, then 11.
int quietest24Channel(Map<String, int> counts) {
  var best = 1 << 30;
  final lows = <int>[];
  for (var channel = 1; channel <= 13; channel++) {
    final aps = counts['2.4:$channel'] ?? 0;
    if (aps < best) {
      best = aps;
      lows
        ..clear()
        ..add(channel);
    } else if (aps == best) {
      lows.add(channel);
    }
  }
  for (final prefer in const [1, 6, 11]) {
    if (lows.contains(prefer)) return prefer;
  }
  return lows.first;
}

bool privateAddress(String bssid) {
  final compact = bssid.replaceAll(':', '').toUpperCase();
  if (compact.length < 2) return false;
  final first = int.tryParse(compact.substring(0, 2), radix: 16);
  return first != null && (first & 0x02) != 0;
}

const _makers = {
  '00000C': 'Cisco',
  '000393': 'Apple',
  '000B86': 'Aruba',
  '00146C': 'Netgear',
  '001A11': 'Google',
  '001A1E': 'Aruba',
  '001B21': 'Intel',
  '001DD0': 'ARRIS',
  '001DD1': 'ARRIS',
  '00259C': 'Linksys',
  '0418D6': 'Ubiquiti',
  '14CC20': 'TP-Link',
  '18E829': 'Ubiquiti',
  '244BFE': 'ASUS',
  '24A43C': 'Ubiquiti',
  '240AC4': 'Espressif',
  '30AEA4': 'Espressif',
  '44D9E7': 'Ubiquiti',
  '50C7BF': 'TP-Link',
  '7483C2': 'Ubiquiti',
  '788A20': 'Ubiquiti',
  '802AA8': 'Ubiquiti',
  'A4CF12': 'Espressif',
  'AC84C6': 'TP-Link',
  'B09575': 'TP-Link',
  'B827EB': 'Raspberry Pi',
  'DCA632': 'Raspberry Pi',
  'E45F01': 'Raspberry Pi',
  'F09FC2': 'Ubiquiti',
  'F4F5D8': 'Google',
  'FCECDA': 'Ubiquiti',
};

String makerOf(String bssid) {
  if (privateAddress(bssid)) return 'Private address';
  final compact = bssid.replaceAll(':', '').toUpperCase();
  if (compact.length < 6) return 'Unknown maker';
  return vendorFor(compact) ?? _makers[compact.substring(0, 6)] ?? 'Unknown maker';
}

String kindLabel(String category) {
  switch (category) {
    case 'vehicle':
      return 'Vehicle';
    case 'printer':
      return 'Printer';
    case 'hotspot':
      return 'Hotspot';
    case 'phone':
      return 'Mobile';
    case 'router':
      return 'Router';
    case 'tv':
      return 'TV';
    case 'camera':
      return 'Camera';
    case 'speaker':
      return 'Speaker';
    case 'appliance':
      return 'Appliance';
    case 'other':
      return 'Other';
    default:
      return 'Unknown';
  }
}

String identityLine({required String vendor, required String category, required String tag}) {
  final who = tag.isEmpty ? vendor : tag;
  return '$who · ${kindLabel(category)}';
}

String deviceLine(String ssid, String bssid) {
  final guess = classify(
    ssid: ssid,
    bssid: bssid,
    hidden: ssid.trim().isEmpty,
    overrideCategory: '',
    autoClassify: true,
    vehiclePatterns: kVehiclePatterns,
    printerPatterns: kPrinterPatterns,
    hotspotPatterns: kHotspotPatterns,
    routerPatterns: kRouterPatterns,
  );
  return identityLine(vendor: makerOf(bssid), category: guess.category, tag: guess.tag);
}

double pathLossN(String environment, double custom) {
  switch (environment) {
    case 'mixed':
      return 2.4;
    case 'outdoor':
      return 2.0;
    case 'custom':
      return custom.clamp(1.6, 6.0);
    default:
      return 3.0;
  }
}

double estimateMeters({
  required int dbm,
  required double freqMhz,
  required double txDbm,
  required double exponent,
}) {
  final n = exponent.clamp(1.6, 6.0);
  final freq = max(400.0, freqMhz);
  final constant = 20 * (log(freq) / ln10) - 27.55;
  final exponentPart = ((txDbm - dbm) - constant) / (10 * n);
  final meters = pow(10, exponentPart).toDouble();
  if (meters.isNaN) return 0.3;
  return meters.clamp(0.3, 500.0);
}

/// 0 sits at the center (−30 dBm or stronger). 1 sits on the outer ring (−90 dBm or weaker).
double signalReach(int dbm) {
  const strong = -30.0;
  const weak = -90.0;
  final level = dbm.toDouble().clamp(weak, strong);
  return (strong - level) / (strong - weak);
}

const signalRingDbm = [-40, -55, -70, -85];

String ruleOfThumbLine(String distanceLabel) {
  return 'A standard formula puts this around $distanceLabel. Walls, floors, weather, and how hard the radio transmits can move that.';
}

/// Indexes to draw, strongest first. The first [limit] always stay.
/// Watched radios past that limit are added as well.
List<int> shownFieldIndexes(int length, bool Function(int index) watched, {int limit = 8}) {
  if (length <= 0) return const [];
  final head = length < limit ? length : limit;
  final shown = [for (var i = 0; i < head; i++) i];
  for (var i = head; i < length; i++) {
    if (watched(i)) shown.add(i);
  }
  return shown;
}

int sharedNameCount(Iterable<String> names, String ssid) {
  final folded = ssid.trim().toLowerCase();
  if (folded.isEmpty) return 0;
  var count = 0;
  for (final name in names) {
    if (name.trim().toLowerCase() == folded) count++;
  }
  return count;
}

String sharedNameLine(int count) => count < 2 ? '' : '$count radios use this name.';

String watchAddressKey(String bssid) => 'mac:${bssid.trim().toUpperCase()}';

String watchNameKey(String ssid) => 'name:${ssid.trim().toLowerCase()}';

String cleanWatchNote(String raw) {
  final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.length <= 80) return trimmed;
  return trimmed.substring(0, 80);
}

String watchNoteFor({
  required String bssid,
  required String ssid,
  required Map<String, String> notes,
}) {
  final address = notes[watchAddressKey(bssid)] ?? '';
  final named = ssid.trim().isEmpty ? '' : (notes[watchNameKey(ssid)] ?? '');
  if (address.isEmpty) return named;
  if (named.isEmpty || named == address) return address;
  return '$address · $named';
}

String formatDistance(double meters, String unit) {
  if (unit == 'ft') {
    final feet = meters * 3.28084;
    if (feet < 10) return '${feet.toStringAsFixed(1)} ft';
    return '${feet.round()} ft';
  }
  if (meters < 10) return '${meters.toStringAsFixed(1)} m';
  return '${meters.round()} m';
}

String formatSignal(int dbm, String unit) {
  if (unit == 'dbm') return '$dbm dBm';
  final quality = dbmToQuality(dbm);
  return '$dbm dBm · $quality%';
}

class ChannelStay {
  const ChannelStay({
    required this.band,
    required this.channel,
    required this.hits,
    required this.scans,
    required this.aps,
    required this.dbm,
  });

  final String band;
  final int channel;
  final int hits;
  final int scans;
  final int aps;
  final int dbm;

  double get presence => scans == 0 ? 0 : hits / scans;

  String get pattern {
    if (scans < 4) return 'Too few scans';
    if (presence >= 0.85) return 'Steady';
    if (presence <= 0.4) return 'Intermittent';
    return 'Often present';
  }

  String get presenceLabel {
    if (scans == 0) return 'No scans yet';
    final percent = (100 * presence).round();
    return 'Present in $hits of $scans scans ($percent%)';
  }
}

List<ChannelStay> channelStays({
  required List<Set<String>> scans,
  required Map<String, int> latestDbm,
  required Map<String, int> latestCounts,
}) {
  final hits = <String, int>{};
  for (final scan in scans) {
    for (final key in scan) {
      hits[key] = (hits[key] ?? 0) + 1;
    }
  }
  final stays = <ChannelStay>[];
  for (final entry in hits.entries) {
    final parts = entry.key.split(':');
    if (parts.length != 2) continue;
    final channel = int.tryParse(parts[1]);
    if (channel == null) continue;
    stays.add(ChannelStay(
      band: parts[0],
      channel: channel,
      hits: entry.value,
      scans: scans.length,
      aps: latestCounts[entry.key] ?? 0,
      dbm: latestDbm[entry.key] ?? -100,
    ));
  }
  stays.sort((a, b) {
    final byPresence = b.presence.compareTo(a.presence);
    if (byPresence != 0) return byPresence;
    return b.dbm.compareTo(a.dbm);
  });
  return stays;
}

String widthLabel(int mhz) => mhz <= 0 ? 'Not reported' : '$mhz MHz';

String formatSpan(Duration span) {
  final seconds = span.inSeconds.abs();
  final days = seconds ~/ 86400;
  final hours = (seconds % 86400) ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  if (days > 0) return '${days}d ${hours}h';
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m ${secs}s';
  return '${secs}s';
}

String authFromCapabilities(String capabilities) {
  final text = capabilities.toUpperCase();
  if (text.contains('WPA3')) return 'WPA3';
  if (text.contains('WPA2')) return 'WPA2';
  if (text.contains('WPA')) return 'WPA';
  if (text.contains('WEP')) return 'WEP';
  if (text.contains('ESS') || capabilities.trim().isEmpty) return 'Open';
  return 'Open';
}

class CategoryGuess {
  const CategoryGuess(this.category, this.confidence, this.reason, {this.tag = ''});
  final String category;
  final String confidence;
  final String reason;
  final String tag;
}

String _hit(String ssid, List<String> patterns) {
  final folded = ssid.toLowerCase();
  for (final pattern in patterns) {
    final text = pattern.trim().toLowerCase();
    if (text.isEmpty) continue;
    var start = 0;
    while (start < folded.length) {
      final at = folded.indexOf(text, start);
      if (at < 0) break;
      final before = at == 0 || !_letter(folded.codeUnitAt(at - 1));
      final afterAt = at + text.length;
      final after = afterAt >= folded.length || !_letter(folded.codeUnitAt(afterAt));
      final strict = text.length <= 4 || _carefulVehicle.contains(text);
      if (before && (!strict || after)) return text;
      start = at + 1;
    }
  }
  return '';
}

bool _letter(int code) => (code >= 65 && code <= 90) || (code >= 97 && code <= 122);

const _carefulVehicle = {
  'smart',
  'seat',
  'eagle',
  'proton',
  'mini',
  'ram',
  'geo',
  'mg',
  'fiat',
  'alpine',
  'billion',
  'netis',
  'extreme',
  'intel',
  'digi',
  'honor',
  'vigor',
  'zte',
  'h3c',
  'avm',
  'jcg',
  'smc',
  'truck',
  'pickup',
  'visible',
  'cricket',
  'frontier',
  'starlink',
};

CategoryGuess classify({
  required String ssid,
  required String bssid,
  required bool hidden,
  required String overrideCategory,
  required bool autoClassify,
  required List<String> vehiclePatterns,
  required List<String> printerPatterns,
  required List<String> hotspotPatterns,
  required List<String> routerPatterns,
}) {
  final chosen = overrideCategory == 'building' ? 'other' : overrideCategory;
  const allowed = {
    'vehicle',
    'printer',
    'hotspot',
    'phone',
    'router',
    'tv',
    'camera',
    'speaker',
    'appliance',
    'other',
    'unknown',
  };
  if (allowed.contains(chosen)) {
    return CategoryGuess(chosen, 'high', 'You set this category.');
  }
  if (!autoClassify) {
    return const CategoryGuess('unknown', 'low', 'Automatic categories are off.');
  }
  final name = hidden ? '' : ssid;
  final named = matchDeviceName(name);
  if (named != null) {
    return CategoryGuess(named.category, 'medium', 'The broadcast name matches ${named.tag}.', tag: named.tag);
  }
  final hotspot = _hit(name, hotspotPatterns.isEmpty ? kHotspotPatterns : hotspotPatterns);
  final printer = _hit(name, printerPatterns.isEmpty ? kPrinterPatterns : printerPatterns);
  final vehicle = _hit(name, vehiclePatterns.isEmpty ? kVehiclePatterns : vehiclePatterns);
  const genericHotspot = {'hotspot', 'mobile hotspot', 'android hotspot', 'androidap'};
  if (vehicle.isNotEmpty && genericHotspot.contains(hotspot)) {
    return CategoryGuess('vehicle', 'medium', 'The broadcast name matches a vehicle pattern ($vehicle).');
  }
  if (hotspot.isNotEmpty) {
    return CategoryGuess('hotspot', 'medium', 'The broadcast name matches a hotspot pattern ($hotspot).');
  }
  if (printer.isNotEmpty) {
    return CategoryGuess('printer', 'medium', 'The broadcast name matches a printer pattern ($printer).');
  }
  if (vehicle.isNotEmpty) {
    return CategoryGuess('vehicle', 'medium', 'The broadcast name matches a vehicle pattern ($vehicle).');
  }
  final router = _hit(name, routerPatterns.isEmpty ? kRouterPatterns : routerPatterns);
  if (router.isNotEmpty) {
    return CategoryGuess('router', 'medium', 'The broadcast name matches a router pattern ($router).');
  }
  final maker = makerOf(bssid);
  final fromVendor = matchDeviceVendor(maker);
  if (fromVendor != null) {
    return CategoryGuess(
      fromVendor.category,
      'medium',
      'The hardware vendor matches ${fromVendor.tag}.',
      tag: fromVendor.tag,
    );
  }
  if (maker == 'Private address') {
    return const CategoryGuess(
      'unknown',
      'low',
      'The hardware address is locally assigned, which often means it is randomized. The name does not say what it is.',
    );
  }
  if (maker == 'Unknown maker') {
    return const CategoryGuess(
      'unknown',
      'low',
      'The vendor is not in the on-phone list, and the name does not say what it is.',
    );
  }
  return CategoryGuess('other', 'medium', 'The vendor is $maker. The name is not in the device catalog.');
}
