import 'dart:math';

import 'package:flutter/material.dart';

import '../logic/radio_math.dart';
import '../radio_env.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/inspect.dart';

class HeatScreen extends StatefulWidget {
  const HeatScreen({super.key, required this.env});

  final RadioEnv env;

  @override
  State<HeatScreen> createState() => _HeatScreenState();
}

class _HeatScreenState extends State<HeatScreen> {
  final _place = TextEditingController();

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  String _quietest(RadioEnv env) {
    final window = _window(env);
    if (window.isEmpty) return 'The quietest 2.4 GHz channel appears after a scan.';
    final counts = window.last.counts;
    final channel = quietest24Channel(counts);
    final aps = counts['2.4:$channel'] ?? 0;
    if (aps == 0) {
      return 'Channel $channel had no access point on 2.4 GHz in the latest scan. This counts access points the phone heard, not how busy the air is.';
    }
    final radios = aps == 1 ? '1 access point' : '$aps access points';
    return 'Channel $channel had the fewest access points on 2.4 GHz in the latest scan ($radios). This counts access points the phone heard, not how busy the air is.';
  }

  List<Widget> _occupancy(RadioEnv env) {
    final stays = channelStays(
      scans: [for (final frame in _window(env)) frame.channels.keys.toSet()],
      latestDbm: _window(env).isEmpty ? const {} : _window(env).last.channels,
      latestCounts: _window(env).isEmpty ? const {} : _window(env).last.counts,
    );
    if (stays.isEmpty) {
      return const [Text('Occupancy appears after a scan.', style: TextStyle(color: SwColors.muted))];
    }
    return [
      for (final stay in stays.take(12))
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 78,
                child: Text('${stay.band}\nch ${stay.channel}', style: const TextStyle(fontSize: 12, height: 1.2)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 8,
                        child: Row(
                          children: [
                            if (stay.presence > 0)
                              Expanded(
                                flex: max(1, (stay.presence * 100).round()),
                                child: ColoredBox(color: stay.pattern == 'Intermittent' ? SwColors.amber : SwColors.teal),
                              ),
                            if (stay.presence < 1)
                              Expanded(
                                flex: max(1, ((1 - stay.presence) * 100).round()),
                                child: const ColoredBox(color: SwColors.line),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stay.pattern} · ${stay.aps} AP${stay.aps == 1 ? '' : 's'} · ${stay.dbm} dBm',
                      style: const TextStyle(color: SwColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ];
  }

  List<Frame> _window(RadioEnv env) {
    final cutoff = DateTime.now().subtract(Duration(minutes: env.settings.chartWindowMin));
    final recent = env.activeFrames.where((frame) => !frame.at.isBefore(cutoff)).toList();
    if (recent.isNotEmpty) return recent;
    if (env.activeFrames.isEmpty) return const [];
    return [env.activeFrames.last];
  }

  @override
  Widget build(BuildContext context) {
    final env = widget.env;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const Text('Heat', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
        const SizedBox(height: 6),
        const Text(
          'This page is a picture of the Wi-Fi channels, not a street map. Color is signal strength. Read the sentence on each section before the drawing.',
          style: TextStyle(color: SwColors.muted, height: 1.35),
        ),
        const SizedBox(height: 16),
        ChannelHeat(
          frames: _window(env),
          onChannel: (band, channel) => showChannelSheet(context, env, band, channel),
        ),
        const SizedBox(height: 8),
        Text(_quietest(env), style: const TextStyle(height: 1.35)),
        const SignalScale(),
        const SizedBox(height: 18),
        const Text('Channel width', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text(
          'Each row is one radio. Longer bars are wider channels. Tap a row for that radio.',
          style: TextStyle(color: SwColors.muted, height: 1.35),
        ),
        const SizedBox(height: 8),
        WidthMap(views: env.views, onOpen: (view) => showRadioSheet(context, view, env)),
        const SizedBox(height: 8),
        const Text('Occupancy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text(
          'Steady means the channel had an access point in nearly every scan. Intermittent means it appeared and then went quiet.',
          style: TextStyle(color: SwColors.muted, height: 1.35),
        ),
        const SizedBox(height: 8),
        ..._occupancy(env),
        const SizedBox(height: 16),
        const Text('Waterfall', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text(
          'Time runs downward. Each column is a channel, labeled above it. A bright cell is a strong signal on that scan. A dark cell is quiet.',
          style: TextStyle(color: SwColors.muted, height: 1.35),
        ),
        const SizedBox(height: 8),
        WaterfallChart(
          frames: _window(env),
          onCell: (band, channel, at, dbm) => showChannelSheet(context, env, band, channel, at: at, dbm: dbm),
        ),
        const SizedBox(height: 16),
        const Text('This session', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text(
          'One row per radio. Color means it was heard on that scan. A gray gap means it was missing.',
          style: TextStyle(color: SwColors.muted, height: 1.35),
        ),
        const SizedBox(height: 8),
        SessionStrip(frames: _window(env), views: env.views, onOpen: (view) => showRadioSheet(context, view, env)),
        const SizedBox(height: 16),
        const Text('Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text(
          'Each line is one radio over time. Higher on the chart is a stronger signal. Color follows the category: vehicle, hotspot, printer, router, mobile, or other.',
          style: TextStyle(color: SwColors.muted, height: 1.35),
        ),
        const SizedBox(height: 8),
        TrendChart(frames: _window(env), views: env.views, onOpen: (view) => showRadioSheet(context, view, env)),
        const SizedBox(height: 16),
        const Text('Walk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        WalkMap(frames: _window(env)),
        const SizedBox(height: 16),
        const Text('Spots', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text(
          'Name where you are standing. The radios audible right now are saved with that name.',
          style: TextStyle(color: SwColors.muted, height: 1.35),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _place,
                decoration: const InputDecoration(hintText: 'Lobby, desk, driveway'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () async {
                await env.markPlace(_place.text);
                _place.clear();
              },
              child: const Text('Mark'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...env.places.map(
          (place) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(place.name),
            subtitle: Text(
              '${place.radios.length} radios · ${formatSpan(DateTime.now().difference(place.at))} ago',
            ),
            trailing: IconButton(
              onPressed: () => env.removePlace(place.id),
              icon: const Icon(Icons.close),
            ),
          ),
        ),
      ],
    );
  }
}
