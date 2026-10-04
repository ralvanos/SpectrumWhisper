import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_scan/wifi_scan.dart';

import 'local_seal.dart';
import 'logic/radio_math.dart';
import 'logic/snapshot.dart';
import 'models.dart';
import 'oui_table.dart';
import 'sample_radios.dart';

class RadioView {
  const RadioView({
    required this.row,
    required this.audible,
    required this.category,
    required this.confidence,
    required this.reason,
    required this.meters,
    required this.distanceLabel,
    required this.signalLabel,
    required this.displayName,
    required this.open,
    required this.vendor,
    required this.pinned,
    required this.note,
    this.tag = '',
  });

  final RadioRow row;
  final bool audible;
  final String category;
  final String confidence;
  final String reason;
  final double meters;
  final String distanceLabel;
  final String signalLabel;
  final String displayName;
  final bool open;
  final String vendor;
  final bool pinned;
  final String note;
  final String tag;
}

class Frame {
  Frame({
    required this.at,
    required this.channels,
    required this.signals,
    this.counts = const {},
    this.lat,
    this.lon,
  });
  final DateTime at;
  final Map<String, int> channels;
  final Map<String, int> signals;
  final Map<String, int> counts;
  final double? lat;
  final double? lon;
}

class Notice {
  Notice(this.at, this.kind, this.message);
  final DateTime at;
  final String kind;
  final String message;
}

class RadioEnv {
  RadioEnv({LocalSeal? seal}) : _seal = seal ?? LocalSeal();

  final LocalSeal _seal;
  bool _settingsLocked = false;
  bool _libraryLocked = false;
  AppSettings settings = AppSettings.defaults();
  final Map<String, RadioRow> rows = {};
  final List<Obs> observations = [];
  final List<PlaceMark> places = [];
  final List<EmfReading> emf = [];
  final List<Frame> frames = [];
  final List<Notice> notices = [];

  int scanId = 0;
  int _nextId = 1;
  String hardware = 'idle';
  String status = 'Waiting for the first scan.';
  DateTime? lastScan;
  List<String> arrivedNames = [];
  List<String> leftNames = [];
  Set<String> freshBssids = {};
  int scanPulse = 0;
  Map<String, dynamic> cell = const {
    'available': false,
    'detail': 'No cellular reading yet.',
  };
  bool foreground = true;

  Map<String, RadioRow>? _previewRows;
  int _previewScanId = 0;
  final List<Frame> _previewFrames = [];
  Timer? _timer;
  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      await loadOuiTable();
    } catch (_) {}
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString('settings');
      if (raw != null) {
        final plain = await _seal.openText(raw);
        settings = AppSettings.fromJson(
          jsonDecode(plain) as Map<String, dynamic>,
        );
        if (!_seal.isSealed(raw)) await _persistSettings();
      }
    } catch (_) {
      _settingsLocked = true;
      settings = AppSettings.defaults();
      status = 'Saved settings are encrypted and could not be opened.';
    }
    await _readLibrary();
    if (settings.preview) _enterPreview();
  }

  Future<void> saveSettings() async {
    final turningOnPreview = settings.preview && _previewRows == null;
    final turningOffPreview = !settings.preview && _previewRows != null;
    try {
      await _persistSettings();
    } catch (_) {}
    if (turningOnPreview) _enterPreview();
    if (turningOffPreview) {
      _previewRows = null;
      _previewFrames.clear();
      hardware = 'idle';
      status = 'Waiting for a live scan.';
      cell = const {'available': false, 'detail': 'No cellular reading yet.'};
      lastScan = null;
    }
    _armTimer();
    notify();
  }

  void setForeground(bool value) {
    foreground = value;
    if (value) {
      _armTimer();
      if (settings.monitoring) unawaited(scanNow());
    } else {
      _timer?.cancel();
    }
  }

  void _armTimer() {
    _timer?.cancel();
    if (!settings.monitoring || !foreground) return;
    _timer = Timer.periodic(Duration(seconds: settings.intervalSec), (_) {
      unawaited(scanNow());
    });
  }

  void start() {
    _armTimer();
    if (settings.monitoring) unawaited(scanNow());
  }

  void dispose() {
    _timer?.cancel();
  }

  bool _busy = false;

  bool get scanning => _busy;

  Future<void> scanNow() async {
    if (_busy || !settings.monitoring) return;
    _busy = true;
    try {
      await _scanBody();
    } finally {
      _busy = false;
    }
  }

  Future<void> _scanBody() async {
    if (settings.preview) {
      _scanPreview();
      return;
    }
    final heard = await _liveScan();
    final position = await _position();
    await _readCell();
    if (heard == null) {
      notify();
      return;
    }
    if (heard.isEmpty && hardware != 'live') {
      notify();
      return;
    }
    _apply(
      rows,
      heard,
      ++scanId,
      DateTime.now(),
      persist: true,
      lat: position?.latitude,
      lon: position?.longitude,
    );
    if (settings.logging) _prune();
    lastScan = DateTime.now();
    hardware = 'live';
    if (status.startsWith('Android is limiting')) {
      // keep the throttle note, but we did read the last cache
    } else {
      status = '';
    }
    await _writeLibrary();
    notify();
  }

  void _scanPreview() {
    _enterPreview();
    final now = DateTime.now();
    _previewScanId += 1;
    _apply(
      _previewRows!,
      sampleHeard(now),
      _previewScanId,
      now,
      persist: false,
    );
    cell = {
      'available': true,
      'sample': true,
      'kind': '5G',
      'dbm': -78,
      'operator': 'Sample Carrier',
    };
    hardware = 'sample';
    status = 'Sample environment. These radios are simulated.';
    lastScan = now;
    notify();
  }

  void _enterPreview() {
    if (_previewRows != null) return;
    final now = DateTime.now();
    _previewRows = seedSample(now);
    _previewScanId = 99;
    _previewFrames.clear();
    for (var i = 0; i < 36; i++) {
      final moment = now.subtract(Duration(seconds: (36 - i) * 20));
      _pushFrame(_previewFrames, sampleHeard(moment), moment, null, null);
    }
  }

  Future<List<Heard>?> _liveScan() async {
    try {
      final canStart = await WiFiScan.instance.canStartScan(
        askPermissions: true,
      );
      final canGet = await WiFiScan.instance.canGetScannedResults(
        askPermissions: true,
      );
      if (canGet != CanGetScannedResults.yes) {
        status = _getMessage(canGet);
        hardware = 'unavailable';
        return [];
      }
      if (canStart == CanStartScan.yes) {
        final fresh = await _waitForScan();
        if (fresh == null) return null;
        status = '';
        return _heardNow(fresh);
      }
      if (canStart == CanStartScan.failed) {
        status =
            'Android is limiting scans. Showing the newest list it already has.';
      } else {
        status = _startMessage(canStart);
        hardware = 'unavailable';
      }
      return _heardNow(await WiFiScan.instance.getScannedResults());
    } on MissingPluginException {
      hardware = 'unavailable';
      status =
          'Wi-Fi scan runs on an Android phone. You can turn on the sample environment in Settings.';
      return [];
    } catch (error) {
      hardware = 'unavailable';
      status = 'Scan failed. $error';
      return [];
    }
  }

  /// Waits for the scan that was just started. The cache from before that scan is not used.
  Future<List<WiFiAccessPoint>?> _waitForScan() async {
    final completer = Completer<List<WiFiAccessPoint>>();
    final sub = WiFiScan.instance.onScannedResultsAvailable.listen(
      (event) {
        if (!completer.isCompleted) completer.complete(event);
      },
      onError: (Object error, StackTrace stack) {
        if (!completer.isCompleted) completer.completeError(error, stack);
      },
    );
    try {
      final started = await WiFiScan.instance.startScan();
      if (!started) return WiFiScan.instance.getScannedResults();
      return await completer.future.timeout(const Duration(seconds: 12));
    } on TimeoutException {
      status = 'That scan did not finish. The list is still the previous one.';
      return null;
    } finally {
      await sub.cancel();
    }
  }

  List<Heard> _heardNow(List<WiFiAccessPoint> aps) {
    int? newest;
    for (final ap in aps) {
      final stamp = ap.timestamp;
      if (stamp == null) continue;
      if (newest == null || stamp > newest) newest = stamp;
    }
    return [
      for (final ap in aps)
        if (stampIsCurrent(ap.timestamp, newest)) _heardFrom(ap),
    ];
  }

  Heard _heardFrom(WiFiAccessPoint ap) {
    final radio = switch (ap.standard) {
      WiFiStandards.legacy => '802.11g',
      WiFiStandards.n => '802.11n',
      WiFiStandards.ac => '802.11ac',
      WiFiStandards.ax => '802.11ax',
      WiFiStandards.be => '802.11be',
      WiFiStandards.ad => '802.11ad',
      WiFiStandards.unkown => '',
    };
    return Heard(
      ssid: ap.ssid,
      bssid: ap.bssid.toUpperCase(),
      dbm: ap.level,
      frequencyMhz: ap.frequency,
      radio: radio,
      capabilities: ap.capabilities,
      hidden: ap.ssid.trim().isEmpty,
      widthMhz: _widthMhz(ap.channelWidth),
      centerMhz: ap.centerFrequency0 ?? 0,
      centerMhz2: ap.centerFrequency1 ?? 0,
    );
  }

  int _widthMhz(WiFiChannelWidth? width) {
    return switch (width) {
      WiFiChannelWidth.mhz20 => 20,
      WiFiChannelWidth.mhz40 => 40,
      WiFiChannelWidth.mhz80 => 80,
      WiFiChannelWidth.mhz160 => 160,
      WiFiChannelWidth.mhz80Plus80 => 160,
      WiFiChannelWidth.mhz320 => 320,
      WiFiChannelWidth.unkown || null => 0,
    };
  }

  Future<Position?> _position() async {
    if (!settings.recordLocation || settings.preview) return null;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _readCell() async {
    if (settings.preview) return;
    try {
      final raw = await const MethodChannel(
        'spectrumwhisper/cell',
      ).invokeMapMethod<String, dynamic>('read');
      cell =
          raw ??
          {
            'available': false,
            'detail': 'No cellular reading from this phone.',
          };
    } catch (_) {
      cell = {
        'available': false,
        'detail': 'This phone did not share a cellular reading.',
      };
    }
  }

  void _apply(
    Map<String, RadioRow> target,
    List<Heard> heard,
    int id,
    DateTime now, {
    required bool persist,
    double? lat,
    double? lon,
  }) {
    final previous = <String, String>{
      for (final row in target.values)
        if (row.lastScanId == id - 1) row.bssid: row.ssid,
    };
    final arrivals = <RadioView>[];
    for (final ap in heard) {
      final band = bandOf(ap.frequencyMhz);
      final before = target[ap.bssid];
      final wasAudible = before != null && before.lastScanId == id - 1;
      final row =
          before ??
          RadioRow(
            bssid: ap.bssid,
            ssid: ap.ssid,
            hidden: ap.hidden,
            firstSeen: now,
            lastSeen: now,
            presentSince: now,
            lastVisitSec: 0,
            lastScanId: id,
            seenScans: 0,
            bestDbm: ap.dbm,
            lastDbm: ap.dbm,
            band: band.band,
            channel: band.channel,
            radio: ap.radio,
            auth: authFromCapabilities(ap.capabilities),
            capabilities: ap.capabilities,
            overrideCategory: '',
            signals: [],
          );
      if (before != null && before.lastScanId < id - 1) {
        if (before.presentSince != null) {
          row.lastVisitSec = before.lastSeen
              .difference(before.presentSince!)
              .inSeconds
              .toDouble();
        }
        row.presentSince = now;
      }
      row.ssid = ap.ssid.isEmpty ? row.ssid : ap.ssid;
      row.hidden = ap.hidden;
      row.lastSeen = now;
      row.lastScanId = id;
      row.seenScans += 1;
      row.lastDbm = ap.dbm;
      if (ap.dbm > row.bestDbm) row.bestDbm = ap.dbm;
      if (band.band.isNotEmpty) {
        row.band = band.band;
        row.channel = band.channel;
      }
      if (ap.radio.isNotEmpty) row.radio = ap.radio;
      if (ap.widthMhz > 0) row.widthMhz = ap.widthMhz;
      if (ap.centerMhz > 0) row.centerMhz = ap.centerMhz;
      if (ap.centerMhz2 > 0) row.centerMhz2 = ap.centerMhz2;
      row.auth = authFromCapabilities(ap.capabilities);
      row.capabilities = ap.capabilities;
      row.signals = [...row.signals, ap.dbm];
      if (row.signals.length > 40) {
        row.signals = row.signals.sublist(row.signals.length - 40);
      }
      target[ap.bssid] = row;
      if (persist && settings.logging) {
        observations.add(
          Obs(
            at: now,
            bssid: row.bssid,
            ssid: row.ssid,
            dbm: ap.dbm,
            band: row.band,
            channel: row.channel,
          ),
        );
      }
      if (!wasAudible) arrivals.add(_viewOf(row, id));
    }
    final bucket = settings.preview ? _previewFrames : frames;
    _pushFrame(bucket, heard, now, lat, lon);
    for (final view in arrivals) {
      final watched = _watched(view.row);
      if (watched && settings.alertWatch) {
        notices.add(
          Notice(now, 'watch', 'Watched radio ${view.displayName} is audible.'),
        );
      } else if (view.category == 'vehicle' && settings.alertVehicle) {
        notices.add(
          Notice(
            now,
            'vehicle',
            'Vehicle-like radio ${view.displayName} is audible.',
          ),
        );
      } else if (settings.alertNew) {
        notices.add(
          Notice(
            now,
            'new',
            'New network ${view.displayName} on ${view.row.band} GHz.',
          ),
        );
      }
      if (settings.alertDbm != 0 && view.row.lastDbm >= settings.alertDbm) {
        notices.add(
          Notice(
            now,
            'signal',
            '${view.displayName} is at ${view.signalLabel}.',
          ),
        );
      }
    }
    if (notices.length > 30) notices.removeRange(0, notices.length - 30);
    if (persist) _forgetQuiet(target, now);
    _noteScanChange(previous, heard);
  }

  Future<void> applyCatalogLimit() async {
    final kept = rows.length;
    _forgetQuiet(rows, DateTime.now());
    if (rows.length != kept && !settings.preview) await _writeLibrary();
    notify();
  }

  void _forgetQuiet(Map<String, RadioRow> target, DateTime now) {
    final days = settings.catalogDays;
    if (days <= 0) return;
    final cutoff = now.subtract(Duration(days: days));
    target.removeWhere((_, row) {
      if (!row.lastSeen.isBefore(cutoff)) return false;
      return !_watched(row);
    });
  }

  void _noteScanChange(Map<String, String> previous, List<Heard> heard) {
    final heardIds = <String>{};
    arrivedNames = [];
    leftNames = [];
    freshBssids = {};
    for (final ap in heard) {
      heardIds.add(ap.bssid);
      if (previous.containsKey(ap.bssid)) continue;
      freshBssids.add(ap.bssid);
      arrivedNames.add(ap.ssid.trim().isEmpty ? '(hidden)' : ap.ssid);
    }
    for (final entry in previous.entries) {
      if (heardIds.contains(entry.key)) continue;
      final name = entry.value.trim();
      leftNames.add(name.isEmpty ? '(hidden)' : name);
    }
    scanPulse++;
  }

  void _pushFrame(
    List<Frame> bucket,
    List<Heard> heard,
    DateTime at,
    double? lat,
    double? lon,
  ) {
    final channels = <String, int>{};
    final counts = <String, int>{};
    final signals = <String, int>{};
    for (final ap in heard) {
      signals[ap.bssid] = ap.dbm;
      final band = bandOf(ap.frequencyMhz);
      if (band.band.isEmpty) continue;
      final key = '${band.band}:${band.channel}';
      counts[key] = (counts[key] ?? 0) + 1;
      final current = channels[key];
      if (current == null || ap.dbm > current) channels[key] = ap.dbm;
    }
    bucket.add(
      Frame(
        at: at,
        channels: channels,
        counts: counts,
        signals: signals,
        lat: lat,
        lon: lon,
      ),
    );
    if (bucket.length > 240) bucket.removeRange(0, bucket.length - 240);
  }

  void _prune() {
    if (settings.retentionDays <= 0) return;
    final cutoff = DateTime.now().subtract(
      Duration(days: settings.retentionDays),
    );
    observations.removeWhere((obs) => obs.at.isBefore(cutoff));
  }

  List<RadioView> get views {
    final source = settings.preview
        ? (_previewRows ?? <String, RadioRow>{})
        : rows;
    final id = settings.preview ? _previewScanId : scanId;
    final list = source.values
        .map((row) => _viewOf(row, id))
        .where(_listed)
        .toList();
    list.sort((a, b) {
      if (a.audible != b.audible) return a.audible ? -1 : 1;
      return b.row.lastDbm.compareTo(a.row.lastDbm);
    });
    return list;
  }

  bool _listed(RadioView view) {
    if (view.pinned && !view.audible) return true;
    if (view.row.hidden && !settings.showHidden) return false;
    if (view.row.band.isNotEmpty && !settings.bands.contains(view.row.band))
      return false;
    if (view.audible && view.row.lastDbm < settings.minDbm) return false;
    return true;
  }

  bool _watched(RadioRow row) {
    if (settings.pinned.contains(row.bssid.toUpperCase())) return true;
    final name = row.ssid.trim().toLowerCase();
    if (name.isEmpty) return false;
    return settings.watchNames.any((item) => item.trim().toLowerCase() == name);
  }

  RadioView _viewOf(RadioRow row, int id) {
    final audible = row.lastScanId == id && id > 0;
    final guess = classify(
      ssid: row.ssid,
      bssid: row.bssid,
      hidden: row.hidden,
      overrideCategory: row.overrideCategory,
      autoClassify: settings.autoClassify,
      vehiclePatterns: settings.vehiclePatterns,
      printerPatterns: settings.printerPatterns,
      hotspotPatterns: settings.hotspotPatterns,
      routerPatterns: settings.routerPatterns,
    );
    final meters = estimateMeters(
      dbm: row.lastDbm,
      freqMhz: frequencyMhz(row.band, row.channel).toDouble(),
      txDbm: settings.txPowerDbm.toDouble(),
      exponent: pathLossN(settings.environment, settings.pathLoss),
    );
    return RadioView(
      row: row,
      audible: audible,
      category: guess.category,
      confidence: guess.confidence,
      reason: guess.reason,
      meters: meters,
      distanceLabel: formatDistance(meters, settings.distanceUnit),
      signalLabel: formatSignal(row.lastDbm, settings.signalUnit),
      displayName: row.ssid.trim().isEmpty ? '(hidden)' : row.ssid,
      open: row.auth == 'Open',
      vendor: makerOf(row.bssid),
      pinned: _watched(row),
      note: watchNoteFor(
        bssid: row.bssid,
        ssid: row.ssid,
        notes: settings.watchNotes,
      ),
      tag: guess.tag,
    );
  }

  List<Frame> get activeFrames => settings.preview ? _previewFrames : frames;

  List<ChannelStay> get channelOccupancy {
    final history = activeFrames;
    return channelStays(
      scans: [for (final frame in history) frame.channels.keys.toSet()],
      latestDbm: history.isEmpty ? const {} : history.last.channels,
      latestCounts: history.isEmpty ? const {} : history.last.counts,
    );
  }

  int sessionHits(String bssid) =>
      activeFrames.where((frame) => frame.signals.containsKey(bssid)).length;

  Future<void> setWatchAddress(String bssid, {required bool on}) async {
    final mac = bssid.toUpperCase();
    if (on) {
      if (!settings.pinned.contains(mac) && settings.pinned.length < 80)
        settings.pinned.add(mac);
    } else {
      settings.pinned.remove(mac);
      settings.watchNotes.remove(watchAddressKey(mac));
    }
    await saveSettings();
  }

  Future<void> setWatchName(String ssid, {required bool on}) async {
    final name = ssid.trim();
    if (name.isEmpty) return;
    final have = settings.watchNames.indexWhere(
      (item) => item.trim().toLowerCase() == name.toLowerCase(),
    );
    if (on) {
      if (have < 0 && settings.watchNames.length < 80)
        settings.watchNames.add(name);
    } else if (have >= 0) {
      settings.watchNames.removeAt(have);
      settings.watchNotes.remove(watchNameKey(name));
    }
    await saveSettings();
  }

  String addressNote(String bssid) =>
      settings.watchNotes[watchAddressKey(bssid)] ?? '';

  String nameNote(String ssid) => settings.watchNotes[watchNameKey(ssid)] ?? '';

  Future<void> setAddressNote(String bssid, String note) async {
    final mac = bssid.toUpperCase();
    if (!settings.pinned.contains(mac)) return;
    _putNote(watchAddressKey(mac), note);
    await saveSettings();
  }

  Future<void> setNameNote(String ssid, String note) async {
    final name = ssid.trim();
    if (name.isEmpty) return;
    if (!settings.watchNames.any(
      (item) => item.trim().toLowerCase() == name.toLowerCase(),
    ))
      return;
    _putNote(watchNameKey(name), note);
    await saveSettings();
  }

  void _putNote(String key, String note) {
    final clean = cleanWatchNote(note);
    if (clean.isEmpty) {
      settings.watchNotes.remove(key);
    } else {
      settings.watchNotes[key] = clean;
    }
  }

  Future<void> setOverride(String bssid, String category) async {
    final target = settings.preview ? _previewRows : rows;
    final row = target?[bssid];
    if (row == null) return;
    row.overrideCategory = category == 'auto' ? '' : category;
    if (!settings.preview) await _writeLibrary();
    notify();
  }

  Future<void> markPlace(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final audible = views.where((view) => view.audible).toList();
    final position = await _position();
    places.insert(
      0,
      PlaceMark(
        id: _nextId++,
        name: trimmed,
        at: DateTime.now(),
        lat: position?.latitude,
        lon: position?.longitude,
        radios: audible
            .map(
              (view) => {
                'ssid': view.displayName,
                'dbm': view.row.lastDbm,
                'category': view.category,
                'band': view.row.band,
                'channel': view.row.channel,
              },
            )
            .toList(),
      ),
    );
    await _writeLibrary();
    notify();
  }

  Future<void> addEmf(double value, String note) async {
    emf.insert(
      0,
      EmfReading(
        id: _nextId++,
        at: DateTime.now(),
        value: value,
        unit: settings.emfUnit,
        note: note.trim(),
      ),
    );
    await _writeLibrary();
    notify();
  }

  Future<void> removePlace(int id) async {
    places.removeWhere((place) => place.id == id);
    await _writeLibrary();
    notify();
  }

  Future<void> removeEmf(int id) async {
    emf.removeWhere((reading) => reading.id == id);
    await _writeLibrary();
    notify();
  }

  Future<void> clearCatalog() async {
    rows.clear();
    frames.clear();
    scanId = 0;
    _previewRows = null;
    _previewFrames.clear();
    if (settings.preview) _enterPreview();
    await _writeLibrary();
    notify();
  }

  Future<void> clearLog() async {
    observations.clear();
    await _writeLibrary();
    notify();
  }

  Future<void> clearPlaces() async {
    places.clear();
    await _writeLibrary();
    notify();
  }

  Future<void> clearEmf() async {
    emf.clear();
    await _writeLibrary();
    notify();
  }

  Future<void> restoreSettings() async {
    final preview = settings.preview;
    settings = AppSettings.defaults();
    settings.preview = preview;
    await saveSettings();
  }

  AreaSnapshot areaSnapshot(SnapshotRange range, {DateTime? now}) {
    final moment = now ?? DateTime.now();
    final listed = views;
    final identities = <String, SnapshotIdentity>{
      for (final view in listed) view.row.bssid: _identityOf(view),
    };
    final catalogIds = settings.preview
        ? (_previewRows?.keys.toSet() ?? <String>{})
        : rows.keys.toSet();
    if (range == SnapshotRange.now) {
      final audible = [
        for (final view in listed)
          if (view.audible) view,
      ];
      final slices = <ScanSlice>[];
      if (audible.isNotEmpty || lastScan != null) {
        slices.add(
          ScanSlice(
            at: _audibleAt(audible, moment),
            signals: {
              for (final view in audible) view.row.bssid: view.row.lastDbm,
            },
          ),
        );
      }
      final at = slices.isEmpty ? moment : slices.first.at;
      return _composeSnapshot(range, at, at, slices, identities);
    }

    final start = range == SnapshotRange.session
        ? (activeFrames.isEmpty ? moment : activeFrames.first.at)
        : moment.subtract(
            range == SnapshotRange.quarterHour
                ? const Duration(minutes: 15)
                : const Duration(hours: 1),
          );
    final slices = <ScanSlice>[];
    final frameTimes = <int>{};
    if (range != SnapshotRange.session) {
      final latest = <String, Obs>{};
      for (final obs in observations) {
        if (obs.at.isBefore(start) || obs.at.isAfter(moment)) continue;
        final have = latest[obs.bssid];
        if (have == null || !obs.at.isBefore(have.at)) latest[obs.bssid] = obs;
      }
      for (final obs in latest.values) {
        _ensureObsIdentity(obs, identities, catalogIds);
      }
    }
    for (final frame in activeFrames) {
      if (range != SnapshotRange.session && frame.at.isBefore(start)) continue;
      if (frame.at.isAfter(moment)) continue;
      frameTimes.add(frame.at.millisecondsSinceEpoch);
      slices.add(
        ScanSlice(
          at: frame.at,
          signals: {
            for (final entry in frame.signals.entries)
              if (identities.containsKey(entry.key)) entry.key: entry.value,
          },
        ),
      );
    }
    if (range != SnapshotRange.session) {
      final grouped = <int, List<Obs>>{};
      for (final obs in observations) {
        if (obs.at.isBefore(start) || obs.at.isAfter(moment)) continue;
        if (frameTimes.contains(obs.at.millisecondsSinceEpoch)) continue;
        (grouped[obs.at.millisecondsSinceEpoch] ??= []).add(obs);
      }
      final stamps = grouped.keys.toList()..sort();
      for (final stamp in stamps) {
        final group = grouped[stamp]!;
        final signals = <String, int>{};
        for (final obs in group) {
          if (!identities.containsKey(obs.bssid)) continue;
          final previous = signals[obs.bssid];
          if (previous == null || obs.dbm > previous) {
            signals[obs.bssid] = obs.dbm;
          }
        }
        if (signals.isEmpty) continue;
        slices.add(ScanSlice(at: group.first.at, signals: signals));
      }
      _addCurrentSlice(listed, start, moment, slices);
    }
    slices.sort((a, b) => a.at.compareTo(b.at));
    final from = slices.isEmpty ? start : slices.first.at;
    final to = slices.isEmpty ? moment : slices.last.at;
    return _composeSnapshot(range, from, to, slices, identities);
  }

  AreaSnapshot _composeSnapshot(
    SnapshotRange range,
    DateTime from,
    DateTime to,
    List<ScanSlice> slices,
    Map<String, SnapshotIdentity> identities,
  ) {
    return composeSnapshot(
      range: range,
      sample: settings.preview,
      from: from,
      to: to,
      slices: slices,
      identities: identities,
      minDbm: settings.minDbm,
      showHidden: settings.showHidden,
      bands: settings.bands,
      txDbm: settings.txPowerDbm,
      exponent: pathLossN(settings.environment, settings.pathLoss),
      distanceUnit: settings.distanceUnit,
      signalUnit: settings.signalUnit,
      cellular: _cellularSnapshotLine(),
    );
  }

  DateTime _audibleAt(List<RadioView> audible, DateTime moment) {
    if (lastScan != null) return lastScan!;
    DateTime? latest;
    for (final view in audible) {
      if (latest == null || view.row.lastSeen.isAfter(latest)) {
        latest = view.row.lastSeen;
      }
    }
    return latest ?? moment;
  }

  void _addCurrentSlice(
    List<RadioView> listed,
    DateTime start,
    DateTime moment,
    List<ScanSlice> slices,
  ) {
    final audible = [
      for (final view in listed)
        if (view.audible) view,
    ];
    if (audible.isEmpty) return;
    final at = _audibleAt(audible, moment);
    if (at.isBefore(start) || at.isAfter(moment)) return;
    for (final slice in slices) {
      if (slice.at.difference(at).inSeconds.abs() <= 2) return;
    }
    slices.add(
      ScanSlice(
        at: at,
        signals: {for (final view in audible) view.row.bssid: view.row.lastDbm},
      ),
    );
  }

  void _ensureObsIdentity(
    Obs obs,
    Map<String, SnapshotIdentity> identities,
    Set<String> catalogIds,
  ) {
    if (identities.containsKey(obs.bssid) || catalogIds.contains(obs.bssid)) {
      return;
    }
    final hidden = obs.ssid.trim().isEmpty;
    if (hidden && !settings.showHidden) return;
    if (obs.band.isNotEmpty && !settings.bands.contains(obs.band)) return;
    final guess = classify(
      ssid: obs.ssid,
      bssid: obs.bssid,
      hidden: hidden,
      overrideCategory: '',
      autoClassify: settings.autoClassify,
      vehiclePatterns: settings.vehiclePatterns,
      printerPatterns: settings.printerPatterns,
      hotspotPatterns: settings.hotspotPatterns,
      routerPatterns: settings.routerPatterns,
    );
    identities[obs.bssid] = SnapshotIdentity(
      name: hidden ? '(hidden)' : obs.ssid,
      band: obs.band,
      channel: obs.channel,
      category: guess.category,
      auth: '',
      vendor: makerOf(obs.bssid),
      hidden: hidden,
      watched: _nameWatched(obs.bssid, obs.ssid),
    );
  }

  SnapshotIdentity _identityOf(RadioView view) {
    return SnapshotIdentity(
      name: view.displayName,
      band: view.row.band,
      channel: view.row.channel,
      category: view.category,
      auth: view.row.auth,
      vendor: view.vendor,
      hidden: view.row.hidden,
      watched: view.pinned,
    );
  }

  bool _nameWatched(String bssid, String ssid) {
    if (settings.pinned.contains(bssid.toUpperCase())) return true;
    final name = ssid.trim().toLowerCase();
    if (name.isEmpty) return false;
    return settings.watchNames.any((item) => item.trim().toLowerCase() == name);
  }

  String _cellularSnapshotLine() {
    final reading = cell;
    if (reading['available'] != true) return '';
    final dbm = reading['dbm'];
    final sample = reading['sample'] == true ? 'Sample' : '';
    final operator = (reading['operator'] ?? '').toString().trim();
    final kind = (reading['kind'] ?? '').toString().trim();
    final level = dbm == null ? '' : '$dbm dBm';
    return [
      sample,
      operator,
      kind,
      level,
    ].where((part) => part.isNotEmpty).join(' ');
  }

  String exportText() {
    final audible = views.where((view) => view.audible).toList();
    final lines = <String>[
      'SpectrumWhisper',
      DateTime.now().toUtc().toIso8601String(),
      if (settings.preview) 'SAMPLE DATA. This is not a live scan.',
      'Audible ${audible.length}. '
          'Vehicle ${audible.where((v) => v.category == 'vehicle').length}. '
          'Hotspot ${audible.where((v) => v.category == 'hotspot').length}. '
          'Printer ${audible.where((v) => v.category == 'printer').length}. '
          'Unknown ${audible.where((v) => v.category == 'unknown').length}.',
      '',
    ];
    for (final view in audible) {
      final id = settings.redactBssid
          ? _redact(view.row.bssid)
          : view.row.bssid;
      final known = formatSpan(
        view.row.lastSeen.difference(view.row.firstSeen),
      );
      lines.add(
        '${view.displayName}  [${view.category}]  ${view.signalLabel}  ${view.distanceLabel}${view.note.isEmpty ? '' : '  ${view.note}'}',
      );
      lines.add(
        '  $id  ${view.row.band} GHz ch ${view.row.channel}  ${view.row.auth}  known $known',
      );
      lines.add('  ${view.reason}');
    }
    lines.add('');
    lines.add(
      'Broadcast advertisements only. No traffic was captured and no passwords are included.',
    );
    return lines.join('\n');
  }

  String exportCsv() {
    final buffer = StringBuffer(
      'name,bssid,category,signal_dbm,distance,band,channel,security,known\n',
    );
    for (final view in views.where((view) => view.audible)) {
      final id = settings.redactBssid
          ? _redact(view.row.bssid)
          : view.row.bssid;
      final name = view.displayName.replaceAll('"', '""');
      buffer.writeln(
        '"$name",$id,${view.category},${view.row.lastDbm},${view.distanceLabel},${view.row.band},${view.row.channel},${view.row.auth},${formatSpan(view.row.lastSeen.difference(view.row.firstSeen))}',
      );
    }
    return buffer.toString();
  }

  final List<VoidCallback> _listeners = [];

  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
  void notify() {
    for (final listener in List<VoidCallback>.of(_listeners)) {
      listener();
    }
  }

  Future<void> _readLibrary() async {
    final file = await _libraryFile();
    if (file == null || !await file.exists()) return;
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return;
    final String plain;
    try {
      plain = await _seal.openText(raw);
    } catch (_) {
      _libraryLocked = true;
      status = 'The saved catalog is encrypted and could not be opened.';
      return;
    }
    try {
      final json = jsonDecode(plain) as Map<String, dynamic>;
      rows
        ..clear()
        ..addEntries(
          ((json['rows'] as List?) ?? const []).whereType<Map>().map((raw) {
            final row = RadioRow.fromJson(Map<String, dynamic>.from(raw));
            return MapEntry(row.bssid, row);
          }),
        );
      observations
        ..clear()
        ..addAll(
          ((json['observations'] as List?) ?? const []).whereType<Map>().map(
            (raw) => Obs.fromJson(Map<String, dynamic>.from(raw)),
          ),
        );
      places
        ..clear()
        ..addAll(
          ((json['places'] as List?) ?? const []).whereType<Map>().map(
            (raw) => PlaceMark.fromJson(Map<String, dynamic>.from(raw)),
          ),
        );
      emf
        ..clear()
        ..addAll(
          ((json['emf'] as List?) ?? const []).whereType<Map>().map(
            (raw) => EmfReading.fromJson(Map<String, dynamic>.from(raw)),
          ),
        );
      scanId = json['scanId'] as int? ?? 0;
      _nextId = json['nextId'] as int? ?? 1;
      final kept = rows.length;
      _forgetQuiet(rows, DateTime.now());
      if (!_seal.isSealed(raw) || rows.length != kept) await _writeLibrary();
    } catch (_) {
      _libraryLocked = true;
      status = 'The saved catalog could not be read.';
    }
  }

  Future<void> _persistSettings() async {
    if (_settingsLocked) return;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(
      'settings',
      await _seal.sealText(jsonEncode(settings.toJson())),
    );
  }

  Future<void> _writeLibrary() async {
    if (_libraryLocked) return;
    final file = await _libraryFile();
    if (file == null) return;
    final payload = {
      'rows': rows.values.map((row) => row.toJson()).toList(),
      'observations': observations.map((obs) => obs.toJson()).toList(),
      'places': places.map((place) => place.toJson()).toList(),
      'emf': emf.map((reading) => reading.toJson()).toList(),
      'scanId': scanId,
      'nextId': _nextId,
    };
    await file.writeAsString(await _seal.sealText(jsonEncode(payload)));
  }

  Future<File?> _libraryFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/spectrumwhisper.json');
    } catch (_) {
      return null;
    }
  }
}

String _redact(String bssid) {
  final parts = bssid.split(':');
  if (parts.length != 6) return bssid;
  return '${parts[0]}:${parts[1]}:${parts[2]}:xx:xx:xx';
}

String _startMessage(CanStartScan value) {
  switch (value) {
    case CanStartScan.notSupported:
      return 'This phone cannot scan Wi-Fi.';
    case CanStartScan.noLocationPermissionRequired:
    case CanStartScan.noLocationPermissionDenied:
    case CanStartScan.noLocationPermissionUpgradeAccuracy:
      return 'Android needs location permission before it will list nearby Wi-Fi. Allow it, then scan again.';
    case CanStartScan.noLocationServiceDisabled:
      return 'Turn on location services. Android hides Wi-Fi scan results until location is on.';
    case CanStartScan.failed:
      return 'Android is limiting scans. Showing the newest list it already has.';
    case CanStartScan.yes:
      return '';
  }
}

String _getMessage(CanGetScannedResults value) {
  switch (value) {
    case CanGetScannedResults.notSupported:
      return 'This phone cannot list Wi-Fi.';
    case CanGetScannedResults.noLocationPermissionRequired:
    case CanGetScannedResults.noLocationPermissionDenied:
    case CanGetScannedResults.noLocationPermissionUpgradeAccuracy:
      return 'Android needs location permission before it will list nearby Wi-Fi.';
    case CanGetScannedResults.noLocationServiceDisabled:
      return 'Turn on location services so Android will share Wi-Fi scan results.';
    case CanGetScannedResults.yes:
      return '';
  }
}
