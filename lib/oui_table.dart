import 'package:flutter/services.dart';

final Map<String, String> _oui = {};
var _ouiReady = false;

/// Loads the on-phone vendor table. Nothing is fetched when a scan runs.
Future<void> loadOuiTable() async {
  if (_ouiReady) return;
  final raw = await rootBundle.loadString('assets/oui.tsv');
  for (final line in raw.split('\n')) {
    final tab = line.indexOf('\t');
    if (tab <= 0) continue;
    final name = line.substring(tab + 1).trim();
    if (name.isEmpty) continue;
    _oui[line.substring(0, tab).toUpperCase()] = name;
  }
  _ouiReady = true;
}

/// Longest matching vendor block for a MAC with the colons removed.
String? vendorFor(String compact) {
  if (!_ouiReady) return null;
  for (final length in const [9, 7, 6]) {
    if (compact.length < length) continue;
    final name = _oui[compact.substring(0, length)];
    if (name != null) return name;
  }
  return null;
}
