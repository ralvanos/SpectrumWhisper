import 'dart:async';

import 'package:flutter/material.dart';

import '../logic/radio_math.dart';
import '../radio_env.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/inspect.dart';
import '../widgets/listening_choice.dart';
import '../widgets/scan_meter.dart';
import '../widgets/snapshot_sheet.dart';

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key, required this.env});

  final RadioEnv env;

  @override
  Widget build(BuildContext context) {
    final audible = env.views.where((view) => view.audible).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const Text(
          'SpectrumWhisper',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          env.settings.preview
              ? 'Sample environment. These radios are simulated.'
              : 'Nearby Wi-Fi, while this app is open. Android does not allow a quiet background scan.',
          style: const TextStyle(color: SwColors.muted, height: 1.35),
        ),
        if (env.status.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            env.status,
            style: const TextStyle(color: SwColors.amber, height: 1.35),
          ),
        ],
        const SizedBox(height: 12),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Listening',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose whether this app keeps scanning.',
                style: TextStyle(
                  color: SwColors.muted,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              ListeningChoice(env: env),
            ],
          ),
        ),
        Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: env.settings.monitoring && !env.scanning
                  ? env.scanNow
                  : null,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(env.scanning ? 'Scanning' : 'Scan now'),
            ),
            const SizedBox(width: 12),
            Expanded(child: ScanCountdown(env: env)),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => showSnapshotSheet(context, env),
            icon: const Icon(Icons.ios_share, size: 18),
            label: const Text('Share snapshot'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _scanChange(env),
          style: const TextStyle(color: SwColors.muted, height: 1.35),
        ),
        const SizedBox(height: 16),
        _CategoryCounts(audible: audible),
        const SizedBox(height: 12),
        BandSplit(
          low: audible.where((view) => view.row.band == '2.4').length,
          mid: audible.where((view) => view.row.band == '5').length,
          high: audible.where((view) => view.row.band == '6').length,
        ),
        const SizedBox(height: 8),
        Text(
          _occupancyLine(env),
          style: const TextStyle(color: SwColors.muted, height: 1.35),
        ),
        const SizedBox(height: 16),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Around you',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'You are the center. A stronger signal sits closer to you. The rings are signal levels. Dots are spaced around the circle so they stay readable, and that spacing is not a compass direction. A standard formula can turn a reading into feet or meters. Walls, floors, weather, and how hard the radio transmits make that only a rule of thumb.',
                style: TextStyle(
                  color: SwColors.muted,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              FieldMap(
                views: env.views,
                onOpen: (view) => showRadioSheet(context, view, env),
              ),
            ],
          ),
        ),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This phone',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _cellLine(env),
                style: const TextStyle(color: SwColors.muted, height: 1.35),
              ),
              const SizedBox(height: 8),
              Text(
                _emfLine(env),
                style: const TextStyle(color: SwColors.muted, height: 1.35),
              ),
            ],
          ),
        ),
        const Text(
          'Strongest',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sorted by signal strength. The line under each name is a rule of thumb from a standard formula. The maker comes from the hardware address when the device is not using a private address.',
          style: TextStyle(color: SwColors.muted, fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 8),
        if (audible.isEmpty)
          const Text(
            'Nothing audible yet.',
            style: TextStyle(color: SwColors.muted),
          )
        else
          ...([...audible]
                ..sort((a, b) => b.row.lastDbm.compareTo(a.row.lastDbm)))
              .take(8)
              .map(
                (view) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: SwColors.card,
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      title: Row(
                        children: [
                          Expanded(child: Text(view.displayName)),
                          if (env.freshBssids.contains(view.row.bssid))
                            const Text(
                              'New',
                              style: TextStyle(
                                color: SwColors.teal,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${identityLine(vendor: view.vendor, category: view.category, tag: view.tag)}${view.note.isEmpty ? '' : ' · ${view.note}'}\nAbout ${view.distanceLabel}. A rule of thumb only.',
                      ),
                      isThreeLine: true,
                      trailing: Text(
                        view.signalLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onTap: () => showRadioSheet(context, view, env),
                    ),
                  ),
                ),
              ),
        if (env.notices.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Notices',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...env.notices.reversed
              .take(5)
              .map(
                (notice) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    notice.message,
                    style: const TextStyle(color: SwColors.muted),
                  ),
                ),
              ),
        ],
      ],
    );
  }

  String _scanChange(RadioEnv env) {
    if (env.lastScan == null)
      return 'Arrivals and departures appear after a scan.';
    if (env.arrivedNames.isEmpty && env.leftNames.isEmpty) {
      return 'This scan heard the same radios as the one before it.';
    }
    String brief(List<String> names) {
      if (names.isEmpty) return 'none';
      final shown = names.take(4).join(', ');
      final extra = names.length - 4;
      return extra > 0 ? '$shown +$extra' : shown;
    }

    return 'Appeared: ${brief(env.arrivedNames)}. Gone: ${brief(env.leftNames)}.';
  }

  String _occupancyLine(RadioEnv env) {
    final stays = env.channelOccupancy;
    if (stays.isEmpty) return 'Channel pattern appears after a scan.';
    final steady = stays.where((stay) => stay.pattern == 'Steady').length;
    final brief = stays.where((stay) => stay.pattern == 'Intermittent').length;
    final cell = env.cell['available'] == true
        ? ' Cellular ${env.cell['kind'] ?? ''} ${env.cell['dbm'] ?? ''} dBm.'
        : '';
    return '${env.views.where((view) => view.audible).length} access points on ${stays.length} channels. $steady steady, $brief intermittent.$cell';
  }

  String _cellLine(RadioEnv env) {
    final cell = env.cell;
    if (cell['available'] != true) {
      return 'Cellular: ${cell['detail'] ?? 'No reading.'}';
    }
    final sample = cell['sample'] == true ? ' Sample. ' : ' ';
    final dbm = cell['dbm'];
    return 'Cellular$sample${cell['operator'] ?? ''} ${cell['kind'] ?? ''} ${dbm == null ? '' : '$dbm dBm'}'
        .trim();
  }

  String _emfLine(RadioEnv env) {
    if (env.emf.isEmpty) {
      return 'Magnetic field: this phone has no RF meter. Log a handheld reading from the Log tab.';
    }
    final reading = env.emf.first;
    final shown = _convert(reading.value, reading.unit, env.settings.emfUnit);
    return 'Magnetic field: ${shown.toStringAsFixed(2)} ${env.settings.emfUnit}${reading.note.isEmpty ? '' : ' · ${reading.note}'}';
  }

  double _convert(double value, String from, String to) {
    if (from == to) return value;
    if (from == 'uT' && to == 'mG') return value * 10;
    if (from == 'mG' && to == 'uT') return value / 10;
    return value;
  }
}

class ScanCountdown extends StatefulWidget {
  const ScanCountdown({super.key, required this.env});

  final RadioEnv env;

  @override
  State<ScanCountdown> createState() => _ScanCountdownState();
}

class _ScanCountdownState extends State<ScanCountdown> {
  @override
  void initState() {
    super.initState();
    _tick = Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (mounted) setState(() {});
    });
  }

  late final StreamSubscription<dynamic> _tick;

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      scanStatusLabel(widget.env),
      style: const TextStyle(
        color: SwColors.paper,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _CategoryCounts extends StatelessWidget {
  const _CategoryCounts({required this.audible});

  final List<RadioView> audible;

  @override
  Widget build(BuildContext context) {
    const order = [
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
    final counts = <String, int>{};
    for (final view in audible) {
      final key = order.contains(view.category) ? view.category : 'other';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final shown = [
      for (final key in order)
        if ((counts[key] ?? 0) > 0)
          (label: kindLabel(key), count: counts[key]!),
    ];
    if (shown.isEmpty) {
      return const Text(
        'Category counts appear when a scan hears a radio.',
        style: TextStyle(color: SwColors.muted, height: 1.35),
      );
    }
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shown.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = shown[index];
          return SizedBox(
            width: 104,
            child: _Stat(item.label, '${item.count}'),
          );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SwColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SwColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(color: SwColors.muted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: SwColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: SwColors.line),
        ),
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      ),
    );
  }
}
