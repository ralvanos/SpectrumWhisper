import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../logic/snapshot.dart';
import '../radio_env.dart';
import '../theme.dart';
import 'snapshot_card.dart';

void showSnapshotSheet(BuildContext context, RadioEnv env) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SwColors.ink,
    showDragHandle: true,
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height * 0.92;
      return SizedBox(
        height: height,
        child: SnapshotSheet(env: env),
      );
    },
  );
}

class SnapshotSheet extends StatefulWidget {
  const SnapshotSheet({super.key, required this.env});

  final RadioEnv env;

  @override
  State<SnapshotSheet> createState() => _SnapshotSheetState();
}

class _SnapshotSheetState extends State<SnapshotSheet> {
  final _boundary = GlobalKey();
  SnapshotRange _range = SnapshotRange.now;

  @override
  void initState() {
    super.initState();
    widget.env.addListener(_onEnv);
  }

  @override
  void dispose() {
    widget.env.removeListener(_onEnv);
    super.dispose();
  }

  void _onEnv() {
    if (mounted) setState(() {});
  }

  void _note(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _shareImage() async {
    final boundary = _boundary.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) {
      _note('The snapshot is not ready yet.');
      return;
    }
    try {
      final image = await boundary.toImage(pixelRatio: 2.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (!mounted) return;
      if (data == null) {
        _note('Could not make the image.');
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/spectrumwhisper-snapshot.png');
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: 'image/png',
              name: 'spectrumwhisper-snapshot.png',
            ),
          ],
          subject: 'SpectrumWhisper snapshot',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _note('Could not make the image.');
    }
  }

  Future<void> _shareText(String text) async {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: 'SpectrumWhisper snapshot'),
    );
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _note('Snapshot copied');
  }

  @override
  Widget build(BuildContext context) {
    final env = widget.env;
    final snapshot = env.areaSnapshot(_range);
    final text = snapshot.shareText(redactBssid: env.settings.redactBssid);
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Snapshot',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'This scan is the latest pass. 15 min and 1 hour also use earlier passes from this visit, and the signal log when logging is on. Session is only what this visit still holds in memory.',
                style: TextStyle(color: SwColors.muted, height: 1.35),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final range in SnapshotRange.values)
                    ChoiceChip(
                      label: Text(snapshotRangeChip(range)),
                      selected: _range == range,
                      onSelected: (_) => setState(() => _range = range),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              RepaintBoundary(
                key: _boundary,
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.noScaling),
                  child: SnapshotCard(snapshot: snapshot),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The image is the overview to send. Text lists every network in the window. Hardware addresses stay off the image.',
                style: TextStyle(
                  color: SwColors.muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _shareImage,
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Share image'),
                  ),
                  OutlinedButton(
                    onPressed: () => _shareText(text),
                    child: const Text('Share text'),
                  ),
                  OutlinedButton(
                    onPressed: () => _copy(text),
                    child: const Text('Copy'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
