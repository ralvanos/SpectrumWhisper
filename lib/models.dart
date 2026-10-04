import 'constants.dart';
import 'logic/radio_math.dart';

class Heard {
  const Heard({
    required this.ssid,
    required this.bssid,
    required this.dbm,
    required this.frequencyMhz,
    required this.radio,
    required this.capabilities,
    this.hidden = false,
    this.widthMhz = 0,
    this.centerMhz = 0,
    this.centerMhz2 = 0,
  });

  final String ssid;
  final String bssid;
  final int dbm;
  final int frequencyMhz;
  final String radio;
  final String capabilities;
  final bool hidden;
  final int widthMhz;
  final int centerMhz;
  final int centerMhz2;
}

class RadioRow {
  RadioRow({
    required this.bssid,
    required this.ssid,
    required this.hidden,
    required this.firstSeen,
    required this.lastSeen,
    required this.presentSince,
    required this.lastVisitSec,
    required this.lastScanId,
    required this.seenScans,
    required this.bestDbm,
    required this.lastDbm,
    required this.band,
    required this.channel,
    required this.radio,
    required this.auth,
    required this.capabilities,
    required this.overrideCategory,
    required this.signals,
    this.widthMhz = 0,
    this.centerMhz = 0,
    this.centerMhz2 = 0,
  });

  String bssid;
  String ssid;
  bool hidden;
  DateTime firstSeen;
  DateTime lastSeen;
  DateTime? presentSince;
  double lastVisitSec;
  int lastScanId;
  int seenScans;
  int bestDbm;
  int lastDbm;
  String band;
  int channel;
  String radio;
  String auth;
  String capabilities;
  String overrideCategory;
  List<int> signals;
  int widthMhz;
  int centerMhz;
  int centerMhz2;

  Map<String, dynamic> toJson() => {
        'bssid': bssid,
        'ssid': ssid,
        'hidden': hidden,
        'firstSeen': firstSeen.millisecondsSinceEpoch,
        'lastSeen': lastSeen.millisecondsSinceEpoch,
        'presentSince': presentSince?.millisecondsSinceEpoch,
        'lastVisitSec': lastVisitSec,
        'lastScanId': lastScanId,
        'seenScans': seenScans,
        'bestDbm': bestDbm,
        'lastDbm': lastDbm,
        'band': band,
        'channel': channel,
        'radio': radio,
        'auth': auth,
        'capabilities': capabilities,
        'overrideCategory': overrideCategory,
        'signals': signals,
        'widthMhz': widthMhz,
        'centerMhz': centerMhz,
        'centerMhz2': centerMhz2,
      };

  static RadioRow fromJson(Map<String, dynamic> json) {
    return RadioRow(
      bssid: json['bssid'] as String,
      ssid: (json['ssid'] as String?) ?? '',
      hidden: json['hidden'] == true,
      firstSeen: DateTime.fromMillisecondsSinceEpoch(json['firstSeen'] as int),
      lastSeen: DateTime.fromMillisecondsSinceEpoch(json['lastSeen'] as int),
      presentSince: json['presentSince'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(json['presentSince'] as int),
      lastVisitSec: (json['lastVisitSec'] as num?)?.toDouble() ?? 0,
      lastScanId: json['lastScanId'] as int? ?? 0,
      seenScans: json['seenScans'] as int? ?? 1,
      bestDbm: json['bestDbm'] as int? ?? -100,
      lastDbm: json['lastDbm'] as int? ?? -100,
      band: (json['band'] as String?) ?? '',
      channel: json['channel'] as int? ?? 0,
      radio: (json['radio'] as String?) ?? '',
      auth: (json['auth'] as String?) ?? '',
      capabilities: (json['capabilities'] as String?) ?? '',
      overrideCategory: (json['overrideCategory'] as String?) ?? '',
      signals: ((json['signals'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
      widthMhz: json['widthMhz'] as int? ?? 0,
      centerMhz: json['centerMhz'] as int? ?? 0,
      centerMhz2: json['centerMhz2'] as int? ?? 0,
    );
  }
}

class AppSettings {
  AppSettings({
    required this.monitoring,
    required this.intervalSec,
    required this.bands,
    required this.minDbm,
    required this.showHidden,
    required this.highlightOpen,
    required this.preview,
    required this.environment,
    required this.pathLoss,
    required this.txPowerDbm,
    required this.distanceUnit,
    required this.signalUnit,
    required this.autoClassify,
    required this.fixedDwellMin,
    required this.mobileDwellMaxMin,
    required this.varianceFixedMax,
    required this.varianceMobileMin,
    required this.vehiclePatterns,
    required this.printerPatterns,
    required this.hotspotPatterns,
    required this.routerPatterns,
    required this.logging,
    required this.retentionDays,
    required this.catalogDays,
    required this.redactBssid,
    required this.shareFormat,
    required this.recordLocation,
    required this.chartWindowMin,
    required this.alertNew,
    required this.alertVehicle,
    required this.alertWatch,
    required this.alertDbm,
    required this.emfUnit,
    required this.pinned,
    required this.watchNames,
    required this.watchNotes,
    this.textScale = 1,
  });

  bool monitoring;
  int intervalSec;
  List<String> bands;
  int minDbm;
  bool showHidden;
  bool highlightOpen;
  bool preview;
  String environment;
  double pathLoss;
  int txPowerDbm;
  String distanceUnit;
  String signalUnit;
  bool autoClassify;
  int fixedDwellMin;
  int mobileDwellMaxMin;
  int varianceFixedMax;
  int varianceMobileMin;
  List<String> vehiclePatterns;
  List<String> printerPatterns;
  List<String> hotspotPatterns;
  List<String> routerPatterns;
  bool logging;
  int retentionDays;
  int catalogDays;
  bool redactBssid;
  String shareFormat;
  bool recordLocation;
  int chartWindowMin;
  bool alertNew;
  bool alertVehicle;
  bool alertWatch;
  int alertDbm;
  String emfUnit;
  List<String> pinned;
  List<String> watchNames;
  Map<String, String> watchNotes;
  double textScale;

  static double _textScale(Object? raw) {
    final value = raw is num ? raw.toDouble() : 1.0;
    for (final allowed in const [1.0, 1.2, 1.45]) {
      if ((value - allowed).abs() < 0.05) return allowed;
    }
    return 1;
  }

  factory AppSettings.defaults() => AppSettings(
        monitoring: true,
        intervalSec: 30,
        bands: ['2.4', '5', '6'],
        minDbm: -100,
        showHidden: true,
        highlightOpen: true,
        preview: false,
        environment: 'indoor',
        pathLoss: 3,
        txPowerDbm: 18,
        distanceUnit: 'm',
        signalUnit: 'both',
        autoClassify: true,
        fixedDwellMin: 10,
        mobileDwellMaxMin: 4,
        varianceFixedMax: 4,
        varianceMobileMin: 8,
        vehiclePatterns: List.of(kVehiclePatterns),
        printerPatterns: List.of(kPrinterPatterns),
        hotspotPatterns: List.of(kHotspotPatterns),
        routerPatterns: List.of(kRouterPatterns),
        logging: false,
        retentionDays: 30,
        catalogDays: 7,
        redactBssid: false,
        shareFormat: 'text',
        recordLocation: false,
        chartWindowMin: 60,
        alertNew: true,
        alertVehicle: true,
        alertWatch: true,
        alertDbm: 0,
        emfUnit: 'uT',
        pinned: [],
        watchNames: [],
        watchNotes: {},
        textScale: 1,
      );

  Map<String, dynamic> toJson() => {
        'monitoring': monitoring,
        'intervalSec': intervalSec,
        'bands': bands,
        'minDbm': minDbm,
        'showHidden': showHidden,
        'highlightOpen': highlightOpen,
        'preview': preview,
        'environment': environment,
        'pathLoss': pathLoss,
        'txPowerDbm': txPowerDbm,
        'distanceUnit': distanceUnit,
        'signalUnit': signalUnit,
        'autoClassify': autoClassify,
        'fixedDwellMin': fixedDwellMin,
        'mobileDwellMaxMin': mobileDwellMaxMin,
        'varianceFixedMax': varianceFixedMax,
        'varianceMobileMin': varianceMobileMin,
        'vehiclePatterns': vehiclePatterns,
        'printerPatterns': printerPatterns,
        'hotspotPatterns': hotspotPatterns,
        'routerPatterns': routerPatterns,
        'logging': logging,
        'retentionDays': retentionDays,
        'catalogDays': catalogDays,
        'redactBssid': redactBssid,
        'shareFormat': shareFormat,
        'recordLocation': recordLocation,
        'chartWindowMin': chartWindowMin,
        'alertNew': alertNew,
        'alertVehicle': alertVehicle,
        'alertWatch': alertWatch,
        'alertDbm': alertDbm,
        'emfUnit': emfUnit,
        'pinned': pinned,
        'watchNames': watchNames,
        'watchNotes': watchNotes,
        'textScale': textScale,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final defaults = AppSettings.defaults();
    List<String> strings(String key, List<String> fallback, {bool keepDefaults = false}) {
      final raw = json[key];
      if (raw is! List || raw.isEmpty) return List.of(fallback);
      final saved = raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty);
      if (!keepDefaults) return saved.take(80).toList();
      final merged = [...fallback];
      for (final item in saved) {
        if (!merged.any((have) => have.toLowerCase() == item.toLowerCase())) merged.add(item);
      }
      return merged.take(180).toList();
    }

    int pickInt(String key, int fallback, List<int> allowed) {
      final value = json[key];
      final number = value is num ? value.toInt() : fallback;
      return allowed.contains(number) ? number : fallback;
    }

    final bands = strings('bands', defaults.bands).where((b) => b == '2.4' || b == '5' || b == '6').toList();
    final pinned = strings('pinned', const []).take(80).map((e) => e.toUpperCase()).toList();
    final watchNames = strings('watchNames', const []).take(80).toList();
    final allowedNotes = {
      for (final mac in pinned) watchAddressKey(mac),
      for (final name in watchNames) watchNameKey(name),
    };
    final watchNotes = <String, String>{};
    final rawNotes = json['watchNotes'];
    if (rawNotes is Map) {
      for (final entry in rawNotes.entries) {
        final key = entry.key.toString();
        if (!allowedNotes.contains(key)) continue;
        final value = cleanWatchNote(entry.value.toString());
        if (value.isEmpty) continue;
        watchNotes[key] = value;
        if (watchNotes.length >= 160) break;
      }
    }
    return AppSettings(
      monitoring: json['monitoring'] is bool ? json['monitoring'] as bool : defaults.monitoring,
      intervalSec: pickInt('intervalSec', 30, const [30, 45, 60, 120, 300]),
      bands: bands.isEmpty ? defaults.bands : bands,
      minDbm: ((json['minDbm'] as num?)?.toInt() ?? -100).clamp(-100, -40),
      showHidden: json['showHidden'] is bool ? json['showHidden'] as bool : true,
      highlightOpen: json['highlightOpen'] is bool ? json['highlightOpen'] as bool : true,
      preview: json['preview'] == true,
      environment: const {'indoor', 'mixed', 'outdoor', 'custom'}.contains(json['environment'])
          ? json['environment'] as String
          : 'indoor',
      pathLoss: ((json['pathLoss'] as num?)?.toDouble() ?? 3).clamp(1.6, 6),
      txPowerDbm: ((json['txPowerDbm'] as num?)?.toInt() ?? 18).clamp(0, 30),
      distanceUnit: json['distanceUnit'] == 'ft' ? 'ft' : 'm',
      signalUnit: json['signalUnit'] == 'dbm' ? 'dbm' : 'both',
      autoClassify: json['autoClassify'] is bool ? json['autoClassify'] as bool : true,
      fixedDwellMin: ((json['fixedDwellMin'] as num?)?.toInt() ?? 10).clamp(1, 180),
      mobileDwellMaxMin: ((json['mobileDwellMaxMin'] as num?)?.toInt() ?? 4).clamp(1, 60),
      varianceFixedMax: ((json['varianceFixedMax'] as num?)?.toInt() ?? 4).clamp(1, 30),
      varianceMobileMin: ((json['varianceMobileMin'] as num?)?.toInt() ?? 8).clamp(1, 40),
      vehiclePatterns: strings('vehiclePatterns', defaults.vehiclePatterns, keepDefaults: true),
      printerPatterns: strings('printerPatterns', defaults.printerPatterns, keepDefaults: true),
      hotspotPatterns: strings('hotspotPatterns', defaults.hotspotPatterns, keepDefaults: true),
      routerPatterns: strings('routerPatterns', defaults.routerPatterns, keepDefaults: true),
      logging: json['logging'] == true,
      retentionDays: pickInt('retentionDays', 30, const [0, 1, 7, 30, 90, 365]),
      catalogDays: pickInt('catalogDays', 7, const [0, 1, 7, 30]),
      redactBssid: json['redactBssid'] == true,
      shareFormat: json['shareFormat'] == 'csv' ? 'csv' : 'text',
      recordLocation: json['recordLocation'] == true,
      chartWindowMin: pickInt('chartWindowMin', 60, const [15, 60, 360, 1440]),
      alertNew: json['alertNew'] is bool ? json['alertNew'] as bool : true,
      alertVehicle: json['alertVehicle'] is bool ? json['alertVehicle'] as bool : true,
      alertWatch: json['alertWatch'] is bool ? json['alertWatch'] as bool : true,
      alertDbm: ((json['alertDbm'] as num?)?.toInt() ?? 0).clamp(-90, 0),
      emfUnit: json['emfUnit'] == 'mG' ? 'mG' : 'uT',
      pinned: pinned,
      watchNames: watchNames,
      watchNotes: watchNotes,
      textScale: _textScale(json['textScale']),
    );
  }
}

class PlaceMark {
  PlaceMark({
    required this.id,
    required this.name,
    required this.at,
    required this.radios,
    this.lat,
    this.lon,
  });

  final int id;
  final String name;
  final DateTime at;
  final List<Map<String, dynamic>> radios;
  final double? lat;
  final double? lon;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'at': at.millisecondsSinceEpoch,
        'radios': radios,
        'lat': lat,
        'lon': lon,
      };

  static PlaceMark fromJson(Map<String, dynamic> json) => PlaceMark(
        id: json['id'] as int,
        name: json['name'] as String? ?? 'Spot',
        at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
        radios: ((json['radios'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(),
        lat: (json['lat'] as num?)?.toDouble(),
        lon: (json['lon'] as num?)?.toDouble(),
      );
}

class EmfReading {
  EmfReading({required this.id, required this.at, required this.value, required this.unit, required this.note});

  final int id;
  final DateTime at;
  final double value;
  final String unit;
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.millisecondsSinceEpoch,
        'value': value,
        'unit': unit,
        'note': note,
      };

  static EmfReading fromJson(Map<String, dynamic> json) => EmfReading(
        id: json['id'] as int,
        at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
        value: (json['value'] as num).toDouble(),
        unit: json['unit'] as String? ?? 'uT',
        note: json['note'] as String? ?? '',
      );
}

class Obs {
  Obs({
    required this.at,
    required this.bssid,
    required this.ssid,
    required this.dbm,
    required this.band,
    required this.channel,
  });

  final DateTime at;
  final String bssid;
  final String ssid;
  final int dbm;
  final String band;
  final int channel;

  Map<String, dynamic> toJson() => {
        'at': at.millisecondsSinceEpoch,
        'bssid': bssid,
        'ssid': ssid,
        'dbm': dbm,
        'band': band,
        'channel': channel,
      };

  static Obs fromJson(Map<String, dynamic> json) => Obs(
        at: DateTime.fromMillisecondsSinceEpoch(json['at'] as int),
        bssid: json['bssid'] as String? ?? '',
        ssid: json['ssid'] as String? ?? '',
        dbm: json['dbm'] as int? ?? -100,
        band: json['band'] as String? ?? '',
        channel: json['channel'] as int? ?? 0,
      );
}
