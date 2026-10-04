import 'package:flutter/material.dart';

import '../logic/snapshot.dart';
import '../theme.dart';

class SnapshotCard extends StatelessWidget {
  const SnapshotCard({super.key, required this.snapshot});

  final AreaSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final shown = snapshot.radios.take(snapshotCardLimit).toList();
    final extra = snapshot.radios.length - shown.length;
    return ColoredBox(
      color: SwColors.ink,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SPECTRUMWHISPER',
              style: TextStyle(
                color: SwColors.teal,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Area snapshot',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              snapshot.windowLabel,
              style: const TextStyle(color: SwColors.muted, height: 1.35),
            ),
            if (snapshot.sample) ...[
              const SizedBox(height: 6),
              const Text(
                'Sample environment. These radios are simulated.',
                style: TextStyle(color: SwColors.amber, height: 1.35),
              ),
            ],
            const SizedBox(height: 12),
            Text(snapshot.analysis, style: const TextStyle(height: 1.35)),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat('Networks', '${snapshot.radios.length}'),
                const SizedBox(width: 8),
                _Stat('Scans', '${snapshot.scans}'),
                const SizedBox(width: 8),
                _Stat('Channels', '${snapshot.channelCount}'),
              ],
            ),
            if (snapshot.band24 + snapshot.band5 + snapshot.band6 > 0) ...[
              const SizedBox(height: 14),
              const Text(
                'Bands',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _SplitBar(
                parts: [
                  if (snapshot.band24 > 0) (snapshot.band24, SwColors.teal),
                  if (snapshot.band5 > 0) (snapshot.band5, SwColors.amber),
                  if (snapshot.band6 > 0) (snapshot.band6, SwColors.slate),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _Key(
                    color: SwColors.teal,
                    label: '2.4 GHz ${snapshot.band24}',
                  ),
                  _Key(color: SwColors.amber, label: '5 GHz ${snapshot.band5}'),
                  _Key(color: SwColors.slate, label: '6 GHz ${snapshot.band6}'),
                ],
              ),
            ],
            if (snapshot.signalLine.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Signal',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              _SplitBar(
                parts: [
                  if (snapshot.strong > 0) (snapshot.strong, SwColors.teal),
                  if (snapshot.fair > 0) (snapshot.fair, SwColors.amber),
                  if (snapshot.faint > 0) (snapshot.faint, SwColors.slate),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                snapshot.signalLine,
                style: const TextStyle(
                  color: SwColors.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            if (snapshot.categories.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                snapshot.categoryLine,
                style: const TextStyle(
                  color: SwColors.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            if (snapshot.securityLine.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                snapshot.securityLine,
                style: const TextStyle(
                  color: SwColors.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
            if (snapshot.activityLine.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(snapshot.activityLine, style: const TextStyle(height: 1.35)),
            ],
            if (snapshot.quietLine.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                snapshot.quietLine,
                style: const TextStyle(color: SwColors.muted, height: 1.35),
              ),
            ],
            if (snapshot.busyLine.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                snapshot.busyLine,
                style: const TextStyle(color: SwColors.muted, height: 1.35),
              ),
            ],
            if (snapshot.cellular.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Serving cell now: ${snapshot.cellular}',
                style: const TextStyle(height: 1.35),
              ),
            ],
            if (shown.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Loudest',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final radio in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: SwColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: SwColors.line),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  radio.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  radio.caption(snapshot.scans),
                                  style: const TextStyle(
                                    color: SwColors.muted,
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            radio.signalLabel,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (extra > 0)
                Text(
                  extra == 1
                      ? '1 more network is in the text share.'
                      : '$extra more networks are in the text share.',
                  style: const TextStyle(color: SwColors.muted, height: 1.35),
                ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Broadcast advertisements only. No traffic was captured and no passwords are included. Distance is a rule of thumb, not a measurement.',
              style: TextStyle(
                color: SwColors.muted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ),
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
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: SwColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SwColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            children: [
              Text(
                label,
                style: const TextStyle(color: SwColors.muted, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.parts});

  final List<(int, Color)> parts;

  @override
  Widget build(BuildContext context) {
    if (parts.isEmpty) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            for (final part in parts)
              Expanded(
                flex: part.$1,
                child: ColoredBox(color: part.$2),
              ),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: SwColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}
