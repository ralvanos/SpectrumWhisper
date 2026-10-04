import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../logic/radio_math.dart';
import '../radio_env.dart';
import '../theme.dart';
import '../widgets/snapshot_sheet.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key, required this.env});

  final RadioEnv env;

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final _value = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final env = widget.env;
    final recent = env.observations.reversed.take(30).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const Text(
          'Log',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'The catalog of radios stays on this phone so “known for” survives a restart. Signal history is stored only while logging is on.',
          style: TextStyle(color: SwColors.muted, height: 1.35),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Log signal history'),
          value: env.settings.logging,
          onChanged: (value) async {
            env.settings.logging = value;
            await env.saveSettings();
          },
        ),
        Text(
          env.settings.logging
              ? '${env.observations.length} stored rows · ${env.rows.length} radios in the catalog.'
              : 'Logging is off. ${env.rows.length} radios are still in the catalog.',
          style: const TextStyle(color: SwColors.muted),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              onPressed: () async {
                final text = env.settings.shareFormat == 'csv'
                    ? env.exportCsv()
                    : env.exportText();
                await SharePlus.instance.share(
                  ShareParams(text: text, subject: 'SpectrumWhisper'),
                );
              },
              child: const Text('Share'),
            ),
            OutlinedButton(
              onPressed: () => showSnapshotSheet(context, env),
              child: const Text('Snapshot'),
            ),
            OutlinedButton(
              onPressed: () async {
                final text = env.exportText();
                await Clipboard.setData(ClipboardData(text: text));
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Summary copied')));
              },
              child: const Text('Copy summary'),
            ),
            OutlinedButton(
              onPressed: env.clearLog,
              child: const Text('Clear signal log'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (recent.isEmpty)
          Text(
            env.settings.logging
                ? 'No stored rows yet.'
                : 'Turn logging on to keep each scan.',
            style: const TextStyle(color: SwColors.muted),
          )
        else
          ...recent.map(
            (obs) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(obs.ssid.isEmpty ? '(hidden)' : obs.ssid),
              subtitle: Text(
                '${obs.band} GHz ch ${obs.channel} · ${formatSpan(DateTime.now().difference(obs.at))} ago',
              ),
              trailing: Text('${obs.dbm} dBm'),
            ),
          ),
        const SizedBox(height: 20),
        const Text(
          'Meter',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          'Type a reading from a handheld EMF meter. This phone cannot measure the magnetic field itself.',
          style: TextStyle(color: SwColors.muted, height: 1.35),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 110,
              child: TextField(
                controller: _value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(hintText: env.settings.emfUnit),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _note,
                decoration: const InputDecoration(
                  hintText: 'Where you measured it',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: () async {
              final value = double.tryParse(_value.text.trim());
              if (value == null || value < 0) return;
              await env.addEmf(value, _note.text);
              _value.clear();
              _note.clear();
            },
            child: const Text('Log reading'),
          ),
        ),
        ...env.emf
            .take(8)
            .map(
              (reading) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${reading.value} ${reading.unit}'),
                subtitle: Text(
                  reading.note.isEmpty
                      ? formatSpan(DateTime.now().difference(reading.at))
                      : reading.note,
                ),
                trailing: IconButton(
                  onPressed: () => env.removeEmf(reading.id),
                  icon: const Icon(Icons.close),
                ),
              ),
            ),
      ],
    );
  }
}
