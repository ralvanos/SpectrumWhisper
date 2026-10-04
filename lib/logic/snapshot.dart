import 'radio_math.dart';

/// How much of the visit a snapshot covers.
enum SnapshotRange { now, quarterHour, hour, session }

const snapshotCardLimit = 8;

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _kindOrder = [
  'vehicle',
  'hotspot',
  'printer',
  'router',
  'phone',
  'tv',
  'camera',
  'speaker',
  'appliance',
  'other',
  'unknown',
];

const _authOrder = ['WPA3', 'WPA2', 'WPA', 'WEP', 'Open'];

String snapshotRangeChip(SnapshotRange range) {
  switch (range) {
    case SnapshotRange.now:
      return 'This scan';
    case SnapshotRange.quarterHour:
      return '15 min';
    case SnapshotRange.hour:
      return '1 hour';
    case SnapshotRange.session:
      return 'Session';
  }
}

String snapshotRangeTitle(SnapshotRange range) {
  switch (range) {
    case SnapshotRange.now:
      return 'This scan';
    case SnapshotRange.quarterHour:
      return 'Last 15 minutes';
    case SnapshotRange.hour:
      return 'Last hour';
    case SnapshotRange.session:
      return 'This session';
  }
}

/// One pass of radios the phone heard, keyed by hardware address.
class ScanSlice {
  const ScanSlice({required this.at, required this.signals});

  final DateTime at;
  final Map<String, int> signals;
}

/// What the snapshot needs to know about a radio besides its readings.
class SnapshotIdentity {
  const SnapshotIdentity({
    required this.name,
    required this.band,
    required this.channel,
    required this.category,
    required this.auth,
    required this.vendor,
    required this.hidden,
    required this.watched,
  });

  final String name;
  final String band;
  final int channel;
  final String category;
  final String auth;
  final String vendor;
  final bool hidden;
  final bool watched;
}

class SnapshotRadio {
  const SnapshotRadio({
    required this.name,
    required this.bssid,
    required this.band,
    required this.channel,
    required this.bestDbm,
    required this.lastDbm,
    required this.hits,
    required this.category,
    required this.auth,
    required this.vendor,
    required this.distanceLabel,
    required this.signalLabel,
    required this.watched,
  });

  final String name;
  final String bssid;
  final String band;
  final int channel;
  final int bestDbm;
  final int lastDbm;
  final int hits;
  final String category;
  final String auth;
  final String vendor;
  final String distanceLabel;
  final String signalLabel;
  final bool watched;

  bool get open => auth == 'Open';

  String caption(int scans) {
    final kind = kindLabel(category);
    final named =
        vendor.isNotEmpty &&
        vendor != 'Unknown maker' &&
        vendor != 'Private address';
    final who = named ? '$vendor · $kind' : kind;
    final place = band.isEmpty ? who : '$who · $band GHz ch $channel';
    final heard = scans < 2 ? '' : ' · $hits/$scans scans';
    final faded = lastDbm == bestDbm ? '' : ' · last $lastDbm dBm';
    final watch = watched ? 'Watched · ' : '';
    return '$watch$place · about $distanceLabel$heard$faded';
  }
}

class CategoryCount {
  const CategoryCount(this.label, this.count);

  final String label;
  final int count;
}

class AreaSnapshot {
  const AreaSnapshot({
    required this.range,
    required this.sample,
    required this.from,
    required this.to,
    required this.scans,
    required this.radios,
    required this.windowLabel,
    required this.analysis,
    required this.signalLine,
    required this.securityLine,
    required this.categoryLine,
    required this.activityLine,
    required this.quietLine,
    required this.busyLine,
    required this.cellular,
    required this.band24,
    required this.band5,
    required this.band6,
    required this.strong,
    required this.fair,
    required this.faint,
    required this.channelCount,
    required this.categories,
  });

  final SnapshotRange range;
  final bool sample;
  final DateTime from;
  final DateTime to;
  final int scans;
  final List<SnapshotRadio> radios;
  final String windowLabel;
  final String analysis;
  final String signalLine;
  final String securityLine;
  final String categoryLine;
  final String activityLine;
  final String quietLine;
  final String busyLine;
  final String cellular;
  final int band24;
  final int band5;
  final int band6;
  final int strong;
  final int fair;
  final int faint;
  final int channelCount;
  final List<CategoryCount> categories;

  String shareText({required bool redactBssid}) {
    final lines = <String>[
      'SpectrumWhisper snapshot',
      windowLabel,
      if (sample) 'Sample environment. These radios are simulated.',
      analysis,
      if (signalLine.isNotEmpty) signalLine,
      if (securityLine.isNotEmpty) securityLine,
      if (categoryLine.isNotEmpty) categoryLine,
      if (activityLine.isNotEmpty) activityLine,
      if (quietLine.isNotEmpty) quietLine,
      if (busyLine.isNotEmpty) busyLine,
      if (cellular.isNotEmpty) 'Serving cell now: $cellular',
      '',
    ];
    if (radios.isEmpty) {
      lines.add('No networks in this snapshot.');
    }
    for (final radio in radios) {
      final id = redactBssid ? _redactAddress(radio.bssid) : radio.bssid;
      final heard = scans <= 1 ? '' : '  heard ${radio.hits} of $scans scans';
      final last = radio.lastDbm == radio.bestDbm
          ? ''
          : '  last ${radio.lastDbm} dBm';
      final watch = radio.watched ? '  watched' : '';
      lines.add(
        '${radio.name}  [${kindLabel(radio.category)}]  ${radio.signalLabel}  about ${radio.distanceLabel}$last$heard$watch',
      );
      final auth = radio.auth.isEmpty ? '' : '  ${radio.auth}';
      final band = radio.band.isEmpty
          ? 'band not reported'
          : '${radio.band} GHz ch ${radio.channel}';
      lines.add('  $id  $band$auth');
    }
    lines.add('');
    lines.add(
      'Broadcast advertisements only. No traffic was captured and no passwords are included.',
    );
    lines.add(
      'Distance is a rule of thumb from signal strength, not a measurement.',
    );
    return lines.join('\n');
  }
}

/// Builds the overview for [slices]. Radios outside [bands], hidden radios, and
/// readings weaker than [minDbm] are left out.
AreaSnapshot composeSnapshot({
  required SnapshotRange range,
  required bool sample,
  required DateTime from,
  required DateTime to,
  required List<ScanSlice> slices,
  required Map<String, SnapshotIdentity> identities,
  required int minDbm,
  required bool showHidden,
  required List<String> bands,
  required int txDbm,
  required double exponent,
  required String distanceUnit,
  required String signalUnit,
  required String cellular,
}) {
  final buckets = <String, _Bucket>{};
  for (final slice in slices) {
    for (final entry in slice.signals.entries) {
      final identity = identities[entry.key];
      if (identity == null) continue;
      if (identity.hidden && !showHidden) continue;
      if (identity.band.isNotEmpty && !bands.contains(identity.band)) continue;
      final existing = buckets[entry.key];
      if (existing == null) {
        buckets[entry.key] = _Bucket(entry.key, identity, entry.value);
      } else {
        existing.hear(entry.value);
      }
    }
  }
  buckets.removeWhere((_, bucket) => bucket.best < minDbm);

  final radios = <SnapshotRadio>[];
  for (final bucket in buckets.values) {
    final id = bucket.identity;
    final meters = estimateMeters(
      dbm: bucket.best,
      freqMhz: frequencyMhz(id.band, id.channel).toDouble(),
      txDbm: txDbm.toDouble(),
      exponent: exponent,
    );
    radios.add(
      SnapshotRadio(
        name: id.name,
        bssid: bucket.bssid,
        band: id.band,
        channel: id.channel,
        bestDbm: bucket.best,
        lastDbm: bucket.last,
        hits: bucket.hits,
        category: id.category,
        auth: id.auth,
        vendor: id.vendor,
        distanceLabel: formatDistance(meters, distanceUnit),
        signalLabel: formatSignal(bucket.best, signalUnit),
        watched: id.watched,
      ),
    );
  }
  radios.sort((a, b) {
    final bySignal = b.bestDbm.compareTo(a.bestDbm);
    if (bySignal != 0) return bySignal;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  var band24 = 0;
  var band5 = 0;
  var band6 = 0;
  var strong = 0;
  var fair = 0;
  var faint = 0;
  var watched = 0;
  final channels = <String>{};
  final kinds = <String, int>{};
  final auths = <String, int>{};
  for (final radio in radios) {
    if (radio.band == '2.4') band24++;
    if (radio.band == '5') band5++;
    if (radio.band == '6') band6++;
    if (radio.band.isNotEmpty) channels.add('${radio.band}:${radio.channel}');
    if (radio.bestDbm >= -55) {
      strong++;
    } else if (radio.bestDbm >= -70) {
      fair++;
    } else {
      faint++;
    }
    if (radio.watched) watched++;
    final kind = _kindOrder.contains(radio.category) ? radio.category : 'other';
    kinds[kind] = (kinds[kind] ?? 0) + 1;
    if (radio.auth.isNotEmpty) auths[radio.auth] = (auths[radio.auth] ?? 0) + 1;
  }

  final categories = <CategoryCount>[
    for (final key in _kindOrder)
      if ((kinds[key] ?? 0) > 0) CategoryCount(kindLabel(key), kinds[key]!),
  ];
  final kept = buckets.keys.toSet();
  final scanSets = <Set<String>>[];
  Map<String, int> latestCounts = const {};
  Map<String, int> latestDbm = const {};
  for (final slice in slices) {
    final keys = <String>{};
    final counts = <String, int>{};
    final levels = <String, int>{};
    var used = false;
    for (final bssid in slice.signals.keys) {
      if (!kept.contains(bssid)) continue;
      final id = identities[bssid];
      if (id == null || id.band.isEmpty) continue;
      final key = '${id.band}:${id.channel}';
      keys.add(key);
      counts[key] = (counts[key] ?? 0) + 1;
      final level = slice.signals[bssid]!;
      final current = levels[key];
      if (current == null || level > current) levels[key] = level;
      used = true;
    }
    scanSets.add(keys);
    if (used) {
      latestCounts = counts;
      latestDbm = levels;
    }
  }

  final stays = channelStays(
    scans: scanSets,
    latestDbm: latestDbm,
    latestCounts: latestCounts,
  );
  final steadyRadios = radios
      .where((radio) => slices.isNotEmpty && radio.hits == slices.length)
      .length;
  final quietLine = _quietLine(latestCounts);
  final busyLine = _busyLine(latestCounts, latestDbm);

  return AreaSnapshot(
    range: range,
    sample: sample,
    from: from,
    to: to,
    scans: slices.length,
    radios: radios,
    windowLabel: _windowLabel(range, from, to, slices.length),
    analysis: _analysis(
      slices: slices.length,
      radios: radios,
      band24: band24,
      band5: band5,
      band6: band6,
      channelCount: channels.length,
      watched: watched,
    ),
    signalLine: _signalLine(strong, fair, faint),
    securityLine: _securityLine(auths),
    categoryLine: categories.isEmpty
        ? ''
        : 'Kinds: ${categories.map((item) => '${item.label} ${item.count}').join(', ')}.',
    activityLine: _activityLine(
      slices.length,
      radios.length,
      steadyRadios,
      stays,
    ),
    quietLine: radios.isEmpty ? '' : quietLine,
    busyLine: radios.isEmpty ? '' : busyLine,
    cellular: cellular.trim(),
    band24: band24,
    band5: band5,
    band6: band6,
    strong: strong,
    fair: fair,
    faint: faint,
    channelCount: channels.length,
    categories: categories,
  );
}

class _Bucket {
  _Bucket(this.bssid, this.identity, int dbm)
    : best = dbm,
      last = dbm,
      hits = 1;

  final String bssid;
  final SnapshotIdentity identity;
  int best;
  int last;
  int hits;

  void hear(int dbm) {
    hits++;
    last = dbm;
    if (dbm > best) best = dbm;
  }
}

String _analysis({
  required int slices,
  required List<SnapshotRadio> radios,
  required int band24,
  required int band5,
  required int band6,
  required int channelCount,
  required int watched,
}) {
  if (slices == 0) return 'No scans in this window.';
  if (radios.isEmpty) {
    return 'Nothing in this window matched the radios this app is set to show.';
  }
  final loudest = radios.first;
  final count = radios.length == 1 ? '1 network' : '${radios.length} networks';
  final channel = channelCount == 1 ? '1 channel' : '$channelCount channels';
  final open = radios.where((radio) => radio.open).length;
  final buffer = StringBuffer(
    '$count on $channel. ${_bandSentence(band24, band5, band6)}.${open == 0 ? '' : ' $open open.'} '
    'The loudest is ${loudest.name} at ${loudest.bestDbm} dBm.',
  );
  final unbanded = radios.where((radio) => radio.band.isEmpty).length;
  if (unbanded > 0) {
    buffer.write(
      unbanded == 1
          ? ' 1 had no band reported.'
          : ' $unbanded had no band reported.',
    );
  }
  if (watched > 0) {
    buffer.write(
      watched == 1
          ? ' 1 is on the watch list.'
          : ' $watched are on the watch list.',
    );
  }
  return buffer.toString();
}

String _bandSentence(int low, int mid, int high) {
  final parts = <String>[
    if (low > 0) '$low on 2.4 GHz',
    if (mid > 0) '$mid on 5 GHz',
    if (high > 0) '$high on 6 GHz',
  ];
  if (parts.isEmpty) return 'No 2.4, 5, or 6 GHz band was reported';
  if (parts.length == 1) return parts.single;
  if (parts.length == 2) return '${parts[0]} and ${parts[1]}';
  return '${parts[0]}, ${parts[1]}, and ${parts[2]}';
}

String _signalLine(int strong, int fair, int faint) {
  if (strong + fair + faint == 0) return '';
  return 'Signal: $strong strong (-55 dBm or louder), $fair fair, $faint faint (weaker than -70 dBm).';
}

String _securityLine(Map<String, int> auths) {
  if (auths.isEmpty) return '';
  final ordered = <String>[
    for (final auth in _authOrder)
      if ((auths[auth] ?? 0) > 0) auth,
    for (final auth in (auths.keys.toList()..sort()))
      if (!_authOrder.contains(auth)) auth,
  ];
  return 'Security: ${ordered.map((auth) => '${auths[auth]} $auth').join(', ')}.';
}

String _activityLine(
  int scans,
  int radios,
  int steady,
  List<ChannelStay> stays,
) {
  if (scans < 2 || radios == 0) return '';
  final partial = radios - steady;
  final String presence;
  if (partial <= 0) {
    presence = 'Every network was heard on all $scans scans.';
  } else if (steady == 0) {
    presence = 'Every network was missing from at least one scan.';
  } else {
    final stay = steady == 1
        ? '1 network was heard on every scan'
        : '$steady networks were heard on every scan';
    final come = partial == 1
        ? '1 only some of the time'
        : '$partial only some of the time';
    presence = '$stay, and $come.';
  }
  if (scans < 4) return presence;
  final steadyChannels = stays.where((stay) => stay.pattern == 'Steady').length;
  final briefChannels = stays
      .where((stay) => stay.pattern == 'Intermittent')
      .length;
  final bits = <String>[
    if (steadyChannels > 0)
      steadyChannels == 1
          ? '1 channel stayed present'
          : '$steadyChannels channels stayed present',
    if (briefChannels > 0)
      briefChannels == 1
          ? '1 channel came and went'
          : '$briefChannels channels came and went',
  ];
  if (bits.isEmpty) return presence;
  if (bits.length == 1) return '$presence ${bits.single}.';
  return '$presence ${bits[0]}, and ${bits[1]}.';
}

String _quietLine(Map<String, int> counts) {
  if (counts.isEmpty) return '';
  final channel = quietest24Channel(counts);
  final aps = counts['2.4:$channel'] ?? 0;
  final amount = aps == 0
      ? 'no access points'
      : aps == 1
      ? '1 access point'
      : '$aps access points';
  return 'Quietest 2.4 GHz channel on the latest scan is $channel, with $amount.';
}

String _busyLine(Map<String, int> counts, Map<String, int> levels) {
  String? bestKey;
  var bestAps = 0;
  var bestDbm = -200;
  for (final entry in counts.entries) {
    final dbm = levels[entry.key] ?? -100;
    if (entry.value > bestAps || (entry.value == bestAps && dbm > bestDbm)) {
      bestAps = entry.value;
      bestDbm = dbm;
      bestKey = entry.key;
    }
  }
  if (bestKey == null || bestAps <= 0) return '';
  final parts = bestKey.split(':');
  if (parts.length != 2) return '';
  final points = bestAps == 1 ? '1 access point' : '$bestAps access points';
  return 'Busiest on the latest scan is ${parts[0]} GHz channel ${parts[1]}, with $points at $bestDbm dBm.';
}

String _windowLabel(
  SnapshotRange range,
  DateTime from,
  DateTime to,
  int scans,
) {
  final span = _spanLabel(from, to);
  if (range == SnapshotRange.now) return 'This scan · $span';
  if (scans == 0) return '${snapshotRangeTitle(range)} · $span';
  final count = scans == 1 ? '1 scan' : '$scans scans';
  return '$span · $count';
}

String _spanLabel(DateTime from, DateTime to) {
  final start = from.toLocal();
  final end = to.toLocal();
  if (start.difference(end).inMinutes.abs() < 1 && start.day == end.day) {
    return _stamp(end);
  }
  final sameDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  if (sameDay) {
    return '${_clock(start)} – ${_clock(end)}, ${_months[end.month - 1]} ${end.day}, ${end.year}';
  }
  return '${_stamp(start)} – ${_stamp(end)}';
}

String _stamp(DateTime local) =>
    '${_clock(local)}, ${_months[local.month - 1]} ${local.day}, ${local.year}';

String _clock(DateTime local) {
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String _redactAddress(String bssid) {
  final parts = bssid.split(':');
  if (parts.length != 6) return bssid;
  return '${parts[0]}:${parts[1]}:${parts[2]}:xx:xx:xx';
}
