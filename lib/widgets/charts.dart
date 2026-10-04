import 'dart:math';

import 'package:flutter/material.dart';

import '../logic/radio_math.dart';
import '../radio_env.dart';
import '../theme.dart';

const _band5 = [
  36, 40, 44, 48, 52, 56, 60, 64,
  100, 104, 108, 112, 116, 120, 124, 128,
  132, 136, 140, 144, 149, 153, 157, 161, 165,
];

class FieldMap extends StatefulWidget {
  const FieldMap({super.key, required this.views, this.onOpen});

  final List<RadioView> views;
  final void Function(RadioView view)? onOpen;

  @override
  State<FieldMap> createState() => _FieldMapState();
}

class _FieldMapState extends State<FieldMap> {
  final _transform = TransformationController();
  final _viewKey = GlobalKey();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _setScale(double scale) {
    final next = scale.clamp(1.0, 4.0);
    if (next <= 1) {
      _transform.value = Matrix4.identity();
      return;
    }
    final box = _viewKey.currentContext?.findRenderObject() as RenderBox?;
    final focal = box == null ? Offset.zero : Offset(box.size.width / 2, box.size.height / 2);
    final scene = _transform.toScene(focal);
    _transform.value = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(next, next, 1, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
  }

  @override
  Widget build(BuildContext context) {
    final audible = widget.views.where((view) => view.audible).toList()
      ..sort((a, b) => b.row.lastDbm.compareTo(a.row.lastDbm));
    final shown = [
      for (final index in shownFieldIndexes(audible.length, (index) => audible[index].pinned)) audible[index],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _KeyDot(color: SwColors.amber, label: 'Vehicle'),
            _KeyDot(color: SwColors.catHotspot, label: 'Hotspot'),
            _KeyDot(color: SwColors.rose, label: 'Printer'),
            _KeyDot(color: SwColors.catRouter, label: 'Router'),
            _KeyDot(color: SwColors.catMobile, label: 'Mobile'),
            _KeyDot(color: SwColors.catOther, label: 'Other'),
          ],
        ),
        const SizedBox(height: 6),
        const Text('Closer to you is a stronger signal. A teal flag is a watched radio that the last scan heard, including one quieter than the eight strongest. Use the buttons to zoom. Dots are spaced apart so names do not sit on top of each other. Tap a dot for the rule-of-thumb distance.', style: TextStyle(color: SwColors.muted, fontSize: 12, height: 1.35)),
        const SizedBox(height: 8),
        Row(
          children: [
            _ZoomButton(icon: Icons.remove, tooltip: 'Zoom out', onPressed: () => _setScale(_transform.value.getMaxScaleOnAxis() / 1.25)),
            _ZoomButton(icon: Icons.add, tooltip: 'Zoom in', onPressed: () => _setScale(_transform.value.getMaxScaleOnAxis() * 1.25)),
            _ZoomButton(icon: Icons.fit_screen, tooltip: 'Reset zoom', onPressed: () => _setScale(1)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: DecoratedBox(
            decoration: BoxDecoration(color: const Color(0xFF141C18), border: Border.all(color: SwColors.line), borderRadius: BorderRadius.circular(18)),
            child: SizedBox(
              key: _viewKey,
              height: 360,
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: 4,
                boundaryMargin: const EdgeInsets.all(48),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = Size(constraints.maxWidth, 360);
                    return GestureDetector(
                      onTapUp: (details) {
                        final hit = _nearestDot(size, shown, details.localPosition);
                        if (hit != null) widget.onOpen?.call(hit);
                      },
                      child: CustomPaint(
                        painter: _FieldPainter(views: shown),
                        child: const SizedBox.expand(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldPainter extends CustomPainter {
  _FieldPainter({required this.views});
  final List<RadioView> views;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 8);
    final radius = min(size.width, size.height) * 0.38;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = SwColors.line;
    for (final ring in signalRingDbm) {
      final r = radius * signalReach(ring);
      canvas.drawCircle(center, r, ringPaint);
      _paintText(canvas, '$ring dBm', center + Offset(4, -r - 2), SwColors.muted, 10, 56);
    }
    canvas.drawCircle(center, 7, Paint()..color = SwColors.paper);
    canvas.drawCircle(
      center,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = SwColors.teal,
    );
    _paintText(canvas, 'You', center + const Offset(14, -6), SwColors.paper, 12, 40);
    for (final dot in _fieldDots(size, views)) {
      final view = dot.view;
      final point = dot.point;
      canvas.drawLine(
        center,
        point,
        Paint()
          ..color = _cat(view.category).withValues(alpha: 0.35)
          ..strokeWidth = 1,
      );
      canvas.drawCircle(point, 10, Paint()..color = SwColors.ink);
      canvas.drawCircle(point, 7, Paint()..color = _cat(view.category));
      if (view.pinned) _paintFlag(canvas, point);
      final right = point.dx >= center.dx;
      final band = view.row.band;
      final signal = '${view.row.lastDbm} dBm';
      _paintText(
        canvas,
        TextSpan(
          style: const TextStyle(fontSize: 11, height: 1.15),
          children: [
            TextSpan(
              text: '${view.displayName}\n',
              style: TextStyle(color: _cat(view.category), fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: band.isEmpty ? signal : '$band GHz',
              style: TextStyle(color: band.isEmpty ? SwColors.muted : _bandColor(band)),
            ),
            if (band.isNotEmpty) TextSpan(text: '  $signal', style: const TextStyle(color: SwColors.muted)),
          ],
        ),
        point + Offset(right ? 14 : -104, -8),
        SwColors.paper,
        11,
        96,
        alignRight: !right,
      );
    }
  }

  void _paintText(Canvas canvas, Object text, Offset at, Color color, double size, double maxWidth, {bool alignRight = false}) {
    final span = text is InlineSpan
        ? text
        : TextSpan(text: text as String, style: TextStyle(color: color, fontSize: size, height: 1.15));
    final painter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    final dx = alignRight ? at.dx + (maxWidth - painter.width) : at.dx;
    painter.paint(canvas, Offset(dx, at.dy));
  }

  void _paintFlag(Canvas canvas, Offset point) {
    final pole = point + const Offset(-12, -16);
    canvas.drawLine(
      pole,
      pole + const Offset(0, 16),
      Paint()
        ..color = SwColors.teal
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
    final fly = Path()
      ..moveTo(pole.dx, pole.dy)
      ..lineTo(pole.dx + 8, pole.dy + 3)
      ..lineTo(pole.dx, pole.dy + 6)
      ..close();
    canvas.drawPath(fly, Paint()..color = SwColors.teal);
  }

  @override
  bool shouldRepaint(covariant _FieldPainter oldDelegate) => true;
}

List<({RadioView view, Offset point})> _fieldDots(Size size, List<RadioView> views) {
  final center = Offset(size.width / 2, size.height / 2 + 8);
  final radius = min(size.width, size.height) * 0.38;
  final shown = [
    for (final index in shownFieldIndexes(views.length, (index) => views[index].pinned)) views[index],
  ];
  return [
    for (var i = 0; i < shown.length; i++)
      () {
        final view = shown[i];
        final theta = shown.length == 1 ? -pi / 2 : -pi / 2 + (i * 2 * pi / shown.length);
        final reach = max(18.0, signalReach(view.row.lastDbm) * radius);
        return (view: view, point: center + Offset(cos(theta), sin(theta)) * reach);
      }(),
  ];
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 28,
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        backgroundColor: SwColors.card,
        foregroundColor: SwColors.paper,
        side: const BorderSide(color: SwColors.line),
      ),
    );
  }
}

RadioView? _nearestDot(Size size, List<RadioView> views, Offset position) {
  RadioView? hit;
  var best = 36.0;
  for (final dot in _fieldDots(size, views)) {
    final distance = (dot.point - position).distance;
    if (distance < best) {
      best = distance;
      hit = dot.view;
    }
  }
  return hit;
}

class ChannelHeat extends StatelessWidget {
  const ChannelHeat({super.key, required this.frames, this.onChannel});

  final List<Frame> frames;
  final void Function(String band, int channel)? onChannel;

  @override
  Widget build(BuildContext context) {
    final latest = frames.isEmpty ? null : frames.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Each bar is one Wi-Fi channel. A taller, warmer bar is a stronger access point on that channel. A flat bar means nothing was heard there on the last scan.',
          style: TextStyle(color: SwColors.muted, fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 8),
        Text(_loudest(latest), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _BandBars(
          title: '2.4 GHz channels',
          channels: List.generate(13, (i) => i + 1),
          values: _values(latest, '2.4', List.generate(13, (i) => i + 1)),
          onChannel: onChannel == null ? null : (channel) => onChannel!('2.4', channel),
        ),
        const SizedBox(height: 12),
        _BandBars(
          title: '5 GHz channels',
          channels: _band5,
          values: _values(latest, '5', _band5),
          onChannel: onChannel == null ? null : (channel) => onChannel!('5', channel),
        ),
        const SizedBox(height: 8),
        Text(
          _has6(latest) ? '6 GHz radios are in the latest scan.' : '6 GHz: nothing heard on the latest scan.',
          style: const TextStyle(color: SwColors.muted, fontSize: 13),
        ),
      ],
    );
  }

  bool _has6(Frame? frame) => frame?.channels.keys.any((key) => key.startsWith('6:')) ?? false;

  String _loudest(Frame? frame) {
    if (frame == null || frame.channels.isEmpty) return 'No channel has a signal yet.';
    final best = frame.channels.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final parts = best.key.split(':');
    if (parts.length != 2) return 'Strongest signal is ${best.value} dBm.';
    return 'Strongest right now: ${parts[0]} GHz channel ${parts[1]} at ${best.value} dBm.';
  }

  List<int> _values(Frame? frame, String band, List<int> channels) {
    return channels.map((channel) => frame?.channels['$band:$channel'] ?? -100).toList();
  }
}

Widget _scrollable(bool scroll, Widget child) {
  if (!scroll) return child;
  return SizedBox(
    height: 108,
    child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: child),
  );
}

class _BandBars extends StatelessWidget {
  const _BandBars({required this.title, required this.channels, required this.values, this.onChannel});
  final String title;
  final List<int> channels;
  final List<int> values;
  final void Function(int channel)? onChannel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: SwColors.muted, fontSize: 13)),
        const SizedBox(height: 6),
        _scrollable(
          channels.length > 16,
          SizedBox(
            height: 108,
            width: channels.length > 16 ? channels.length * 22.0 : null,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapUp: onChannel == null
                      ? null
                      : (details) {
                          final width = constraints.maxWidth <= 0 ? 1.0 : constraints.maxWidth;
                          final index = (details.localPosition.dx / width * channels.length).floor().clamp(0, channels.length - 1);
                          onChannel!(channels[index]);
                        },
                  child: CustomPaint(
                    painter: _BarPainter(channels, values),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.channels, this.values);
  final List<int> channels;
  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    final gap = 3.0;
    final width = max(3.0, (size.width - gap * (channels.length - 1)) / channels.length);
    for (var i = 0; i < channels.length; i++) {
      final dbm = values[i];
      final t = dbm <= -100 ? 0.0 : ((dbm + 100) / 60).clamp(0.0, 1.0);
      final bar = t <= 0 ? 2.0 : max(4.0, t * (size.height - 18));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * (width + gap), size.height - 16 - bar, width, bar),
          const Radius.circular(3),
        ),
        Paint()..color = _heat(t),
      );
      if (width >= 12) {
        final text = TextPainter(
          text: TextSpan(
            text: '${channels[i]}',
            style: const TextStyle(color: SwColors.muted, fontSize: 9),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: width + gap);
        text.paint(canvas, Offset(i * (width + gap) + (width - text.width) / 2, size.height - 12));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter oldDelegate) => true;
}

class WaterfallChart extends StatelessWidget {
  const WaterfallChart({super.key, required this.frames, this.onCell});
  final List<Frame> frames;
  final void Function(String band, int channel, DateTime at, int? dbm)? onCell;

  @override
  Widget build(BuildContext context) {
    final columns = <String>{};
    for (final frame in frames) {
      columns.addAll(frame.channels.keys);
    }
    final keys = columns.toList()..sort();
    if (keys.isEmpty) {
      return const Text('The waterfall fills in as scans arrive. Newest is at the bottom.', style: TextStyle(color: SwColors.muted, height: 1.35));
    }
    final chartWidth = max(280.0, keys.length * 36.0);
    return SizedBox(
      height: 206,
      child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (final key in keys)
                  SizedBox(
                    width: chartWidth / keys.length,
                    child: Text(_columnLabel(key), textAlign: TextAlign.center, style: const TextStyle(color: SwColors.muted, fontSize: 10)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 180,
              child: GestureDetector(
                onTapUp: onCell == null
                    ? null
                    : (details) {
                        final shown = frames.length > 60 ? frames.sublist(frames.length - 60) : frames;
                        if (shown.isEmpty || keys.isEmpty) return;
                        final x = (details.localPosition.dx / chartWidth * keys.length).floor().clamp(0, keys.length - 1);
                        final y = (details.localPosition.dy / 180 * shown.length).floor().clamp(0, shown.length - 1);
                        final parts = keys[x].split(':');
                        if (parts.length != 2) return;
                        final channel = int.tryParse(parts[1]);
                        if (channel == null) return;
                        onCell!(parts[0], channel, shown[y].at, shown[y].channels[keys[x]]);
                      },
                child: CustomPaint(
                  painter: _WaterfallPainter(frames, keys),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

String _columnLabel(String key) {
  final parts = key.split(':');
  if (parts.length != 2) return key;
  final band = parts[0] == '2.4' ? '2' : parts[0];
  return '$band·${parts[1]}';
}

class _WaterfallPainter extends CustomPainter {
  _WaterfallPainter(this.frames, this.columns);
  final List<Frame> frames;
  final List<String> columns;

  @override
  void paint(Canvas canvas, Size size) {
    if (frames.isEmpty || columns.isEmpty) return;
    final shown = frames.length > 60 ? frames.sublist(frames.length - 60) : frames;
    final cellW = size.width / columns.length;
    final cellH = size.height / shown.length;
    for (var y = 0; y < shown.length; y++) {
      for (var x = 0; x < columns.length; x++) {
        final dbm = shown[y].channels[columns[x]];
        final t = dbm == null ? 0.0 : ((dbm + 100) / 60).clamp(0.0, 1.0);
        canvas.drawRect(
          Rect.fromLTWH(x * cellW, y * cellH, cellW + 0.5, cellH + 0.5),
          Paint()..color = _heat(t),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WaterfallPainter oldDelegate) => true;
}

class TrendChart extends StatelessWidget {
  const TrendChart({super.key, required this.frames, required this.views, this.onOpen});
  final List<Frame> frames;
  final List<RadioView> views;
  final void Function(RadioView view)? onOpen;

  @override
  Widget build(BuildContext context) {
    final chosen = <RadioView>[];
    final audible = views.where((view) => view.audible).toList()
      ..sort((a, b) => b.row.lastDbm.compareTo(a.row.lastDbm));
    final pinned = audible.where((view) => view.pinned);
    final rest = audible.where((view) => !view.pinned);
    final seen = <String>{};
    for (final view in [...pinned, ...rest]) {
      if (seen.add(view.row.bssid)) chosen.add(view);
      if (chosen.length == 6) break;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, 200);
              return GestureDetector(
                onTapUp: onOpen == null
                    ? null
                    : (details) {
                        final radio = _nearestTrend(frames, chosen, details.localPosition, size);
                        if (radio != null) onOpen!(radio);
                      },
                child: CustomPaint(
                  painter: _TrendPainter(frames, chosen),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          children: chosen
              .map(
                (view) => GestureDetector(
                  onTap: onOpen == null ? null : () => onOpen!(view),
                  child: Text(
                    view.displayName,
                    style: TextStyle(color: _cat(view.category), fontSize: 12),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.frames, this.views);
  final List<Frame> frames;
  final List<RadioView> views;

  @override
  void paint(Canvas canvas, Size size) {
    if (frames.length < 2 || views.isEmpty) return;
    final start = frames.first.at.millisecondsSinceEpoch.toDouble();
    final end = frames.last.at.millisecondsSinceEpoch.toDouble();
    final span = max(1.0, end - start);
    for (final view in views) {
      final paint = Paint()
        ..color = _cat(view.category)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final path = Path();
      var moved = false;
      for (final frame in frames) {
        final dbm = frame.signals[view.row.bssid];
        if (dbm == null) continue;
        final x = (frame.at.millisecondsSinceEpoch - start) / span * size.width;
        final y = (1 - ((dbm + 100) / 70).clamp(0.0, 1.0)) * size.height;
        if (!moved) {
          path.moveTo(x, y);
          moved = true;
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) => true;
}

RadioView? _nearestTrend(List<Frame> frames, List<RadioView> views, Offset position, Size size) {
  if (frames.length < 2 || views.isEmpty) return null;
  final start = frames.first.at.millisecondsSinceEpoch.toDouble();
  final end = frames.last.at.millisecondsSinceEpoch.toDouble();
  final span = max(1.0, end - start);
  RadioView? hit;
  var best = 36.0;
  for (final view in views) {
    for (final frame in frames) {
      final dbm = frame.signals[view.row.bssid];
      if (dbm == null) continue;
      final x = (frame.at.millisecondsSinceEpoch - start) / span * size.width;
      final y = (1 - ((dbm + 100) / 70).clamp(0.0, 1.0)) * size.height;
      final distance = (Offset(x, y) - position).distance;
      if (distance < best) {
        best = distance;
        hit = view;
      }
    }
  }
  return hit;
}

class WalkMap extends StatelessWidget {
  const WalkMap({super.key, required this.frames});
  final List<Frame> frames;

  @override
  Widget build(BuildContext context) {
    final points = frames.where((frame) => frame.lat != null && frame.lon != null).toList();
    if (points.length < 2) {
      return const Text(
        'Turn on Record position in Settings, then walk with the app open. Each scan drops a point colored by the loudest signal.',
        style: TextStyle(color: SwColors.muted, height: 1.35),
      );
    }
    return SizedBox(
      height: 220,
      child: CustomPaint(
        painter: _WalkPainter(points),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WalkPainter extends CustomPainter {
  _WalkPainter(this.frames);
  final List<Frame> frames;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = frames.first;
    final meters = frames.map((frame) {
      final north = ((frame.lat! - origin.lat!) * 111320);
      final east = ((frame.lon! - origin.lon!) * 111320 * cos(origin.lat! * pi / 180));
      final loudest = frame.channels.values.fold<int>(-100, max);
      return (east: east, north: north, dbm: loudest);
    }).toList();
    var maxAbs = 8.0;
    for (final point in meters) {
      maxAbs = max(maxAbs, max(point.east.abs(), point.north.abs()));
    }
    for (final point in meters) {
      final dx = size.width / 2 + (point.east / maxAbs) * (size.width * 0.4);
      final dy = size.height / 2 - (point.north / maxAbs) * (size.height * 0.4);
      final t = ((point.dbm + 100) / 60).clamp(0.0, 1.0);
      canvas.drawCircle(Offset(dx, dy), 7, Paint()..color = _heat(t));
    }
  }

  @override
  bool shouldRepaint(covariant _WalkPainter oldDelegate) => true;
}

class SignalScale extends StatelessWidget {
  const SignalScale({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                for (var i = 0; i < 24; i++)
                  Expanded(child: ColoredBox(color: _heat(i / 23))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('−100 dBm', style: TextStyle(color: SwColors.muted, fontSize: 11)),
            Text('−70', style: TextStyle(color: SwColors.muted, fontSize: 11)),
            Text('−40 strong', style: TextStyle(color: SwColors.muted, fontSize: 11)),
          ],
        ),
      ],
    );
  }
}

class BandSplit extends StatelessWidget {
  const BandSplit({super.key, required this.low, required this.mid, required this.high});

  final int low;
  final int mid;
  final int high;

  @override
  Widget build(BuildContext context) {
    final total = low + mid + high;
    if (total == 0) {
      return const Text('No access points on 2.4, 5, or 6 GHz yet.', style: TextStyle(color: SwColors.muted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                if (low > 0) Expanded(flex: low, child: const ColoredBox(color: SwColors.teal)),
                if (mid > 0) Expanded(flex: mid, child: const ColoredBox(color: SwColors.amber)),
                if (high > 0) Expanded(flex: high, child: const ColoredBox(color: SwColors.slate)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _KeyDot(color: SwColors.teal, label: '2.4 GHz · $low'),
            _KeyDot(color: SwColors.amber, label: '5 GHz · $mid'),
            _KeyDot(color: SwColors.slate, label: '6 GHz · $high'),
          ],
        ),
      ],
    );
  }
}

class _KeyDot extends StatelessWidget {
  const _KeyDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: SwColors.muted, fontSize: 12)),
      ],
    );
  }
}

class WidthMap extends StatelessWidget {
  const WidthMap({super.key, required this.views, this.onOpen});

  final List<RadioView> views;
  final void Function(RadioView view)? onOpen;

  @override
  Widget build(BuildContext context) {
    final audible = views.where((view) => view.audible && view.row.band.isNotEmpty).toList();
    if (audible.isEmpty) {
      return const Text('Channel width appears when an access point is audible.', style: TextStyle(color: SwColors.muted, height: 1.35));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _KeyDot(color: SwColors.amber, label: 'Vehicle'),
            _KeyDot(color: SwColors.catHotspot, label: 'Hotspot'),
            _KeyDot(color: SwColors.rose, label: 'Printer'),
            _KeyDot(color: SwColors.catRouter, label: 'Router'),
            _KeyDot(color: SwColors.catMobile, label: 'Mobile'),
            _KeyDot(color: SwColors.catOther, label: 'Other'),
          ],
        ),
        const SizedBox(height: 8),
        const Text('A longer bar is a wider channel. Compare the lengths in each band.', style: TextStyle(color: SwColors.muted, fontSize: 12, height: 1.35)),
        const SizedBox(height: 10),
        for (final band in const ['2.4', '5', '6'])
          if (audible.any((view) => view.row.band == band))
            _WidthBand(
              band: band,
              views: audible.where((view) => view.row.band == band).toList(),
              onOpen: onOpen,
            ),
      ],
    );
  }
}

class _WidthBand extends StatelessWidget {
  const _WidthBand({required this.band, required this.views, this.onOpen});

  final String band;
  final List<RadioView> views;
  final void Function(RadioView view)? onOpen;

  @override
  Widget build(BuildContext context) {
    final spans = _Span.from(views)..sort((a, b) {
      final width = b.width.compareTo(a.width);
      return width != 0 ? width : a.start.compareTo(b.start);
    });
    final widest = spans.map((span) => span.width).reduce(max);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$band GHz', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final span in spans) _WidthRow(span: span, widest: widest, onOpen: onOpen),
        ],
      ),
    );
  }
}

class _WidthRow extends StatelessWidget {
  const _WidthRow({required this.span, required this.widest, this.onOpen});

  final _Span span;
  final double widest;
  final void Function(RadioView view)? onOpen;

  @override
  Widget build(BuildContext context) {
    final color = _cat(span.category);
    final mhz = span.width.round();
    return InkWell(
      onTap: onOpen == null ? null : () => onOpen!(span.view),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(span.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: 8),
                Text(
                  '$mhz MHz · ch ${span.view.row.channel}',
                  style: const TextStyle(color: SwColors.muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                final track = constraints.maxWidth;
                final bar = max(12.0, track * (span.width / widest));
                return Stack(
                  children: [
                    Container(
                      height: 16,
                      width: track,
                      decoration: BoxDecoration(color: SwColors.line, borderRadius: BorderRadius.circular(8)),
                    ),
                    Container(
                      height: 16,
                      width: bar,
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


class _Span {
  _Span(this.view, this.start, this.end);
  final RadioView view;
  final double start;
  final double end;

  String get name => view.displayName;
  String get category => view.category;
  double get width => end - start;

  static List<_Span> from(List<RadioView> views) {
    return [
      for (final view in views)
        () {
          final center = (view.row.centerMhz > 0 ? view.row.centerMhz : frequencyMhz(view.row.band, view.row.channel)).toDouble();
          final half = (view.row.widthMhz > 0 ? view.row.widthMhz : 20) / 2;
          return _Span(view, center - half, center + half);
        }(),
    ];
  }
}

class SessionStrip extends StatelessWidget {
  const SessionStrip({super.key, required this.frames, required this.views, this.onOpen});

  final List<Frame> frames;
  final List<RadioView> views;
  final void Function(RadioView view)? onOpen;

  @override
  Widget build(BuildContext context) {
    if (frames.length < 2) {
      return const Text('A few scans will show which radios stay and which drop out.', style: TextStyle(color: SwColors.muted, height: 1.35));
    }
    final ranked = views.where((view) => view.audible && frames.any((frame) => frame.signals.containsKey(view.row.bssid))).toList()
      ..sort((a, b) => b.row.lastDbm.compareTo(a.row.lastDbm));
    final shown = ranked.take(8).toList();
    if (shown.isEmpty) {
      return const Text('No radio has been heard in this window yet.', style: TextStyle(color: SwColors.muted));
    }
    return Column(
      children: [
        for (final view in shown) ...[
          GestureDetector(
            onTap: onOpen == null ? null : () => onOpen!(view),
            child: Row(
            children: [
              SizedBox(
                width: 108,
                child: Text(view.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
              ),
              Expanded(
                child: SizedBox(
                  height: 14,
                  child: CustomPaint(
                    painter: _StripPainter(frames, view.row.bssid, _cat(view.category)),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ],
          ),
          ),
          const SizedBox(height: 8),
        ],
        const Align(
          alignment: Alignment.centerLeft,
          child: Text('Each block is a scan. A gap is a scan where that radio was quiet.', style: TextStyle(color: SwColors.muted, fontSize: 12, height: 1.35)),
        ),
      ],
    );
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter(this.frames, this.bssid, this.color);
  final List<Frame> frames;
  final String bssid;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final shown = frames.length > 80 ? frames.sublist(frames.length - 80) : frames;
    final cell = size.width / shown.length;
    for (var i = 0; i < shown.length; i++) {
      final heard = shown[i].signals.containsKey(bssid);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * cell + 0.5, 1, max(1, cell - 1), size.height - 2),
          const Radius.circular(2),
        ),
        Paint()..color = heard ? color : SwColors.line.withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StripPainter oldDelegate) => true;
}

class SignalTrace extends StatelessWidget {
  const SignalTrace({super.key, required this.samples, this.height = 72, this.compact = false});

  final List<int> samples;
  final double height;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (samples.length < 2) {
      if (compact) return const SizedBox.shrink();
      return const Text('The signal trace starts after the next scan.', style: TextStyle(color: SwColors.muted, fontSize: 13));
    }
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _TracePainter(samples),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter(this.samples);
  final List<int> samples;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final fill = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = samples.length == 1 ? 0.0 : i / (samples.length - 1) * size.width;
      final y = (1 - ((samples[i] + 100) / 70).clamp(0.0, 1.0)) * (size.height - 8) + 4;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();
    canvas.drawPath(fill, Paint()..color = SwColors.teal.withValues(alpha: 0.18));
    canvas.drawPath(
      path,
      Paint()
        ..color = SwColors.teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TracePainter oldDelegate) => true;
}

Color _bandColor(String band) {
  switch (band) {
    case '5':
      return SwColors.amber;
    case '6':
      return SwColors.slate;
    default:
      return SwColors.teal;
  }
}

Color _cat(String category) {
  switch (category) {
    case 'vehicle':
      return SwColors.amber;
    case 'hotspot':
      return SwColors.catHotspot;
    case 'printer':
      return SwColors.rose;
    case 'phone':
      return SwColors.catMobile;
    case 'router':
      return SwColors.catRouter;
    case 'tv':
    case 'camera':
    case 'speaker':
    case 'appliance':
    case 'other':
      return SwColors.catOther;
    default:
      return SwColors.muted;
  }
}

Color _heat(double t) {
  if (t <= 0) return const Color(0xFF1A2420);
  if (t < 0.4) return Color.lerp(const Color(0xFF1C3D48), const Color(0xFF2F8F86), t / 0.4)!;
  if (t < 0.75) return Color.lerp(const Color(0xFF2F8F86), SwColors.amber, (t - 0.4) / 0.35)!;
  return Color.lerp(SwColors.amber, SwColors.rose, (t - 0.75) / 0.25)!;
}
