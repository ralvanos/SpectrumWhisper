import 'package:flutter/material.dart';

import '../logic/radio_math.dart';
import '../radio_env.dart';
import '../theme.dart';
import 'watch_actions.dart';

void showRadioSheet(BuildContext context, RadioView view, RadioEnv env) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: SwColors.card,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.viewPaddingOf(context).bottom),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(view.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(view.reason, style: const TextStyle(color: SwColors.muted, height: 1.35)),
            const SizedBox(height: 12),
            _fact('Signal', view.signalLabel),
            _fact('Rule of thumb', ruleOfThumbLine(view.distanceLabel)),
            if (view.note.isNotEmpty) _fact('Note', view.note),
            if (_shared(env, view).isNotEmpty) _fact('Same name', _shared(env, view)),
            _fact('Identity', identityLine(vendor: view.vendor, category: view.category, tag: view.tag)),
            _fact('Maker', view.vendor),
            _fact('Channel', '${view.row.band} GHz · ${view.row.channel}'),
            _fact('Frequency', '${frequencyMhz(view.row.band, view.row.channel)} MHz'),
            _fact('Width', widthLabel(view.row.widthMhz)),
            _fact('Security', view.row.auth),
            const SizedBox(height: 8),
            const Text(
              'Tap another mark for a different radio. Closer to the center means a stronger signal, and that place is not a compass bearing.',
              style: TextStyle(color: SwColors.muted, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 12),
            WatchActions(env: env, view: view),
          ],
        ),
      );
    },
  );
}

void showChannelSheet(
  BuildContext context,
  RadioEnv env,
  String band,
  int channel, {
  DateTime? at,
  int? dbm,
}) {
  final matches = env.views.where((view) => view.audible && view.row.band == band && view.row.channel == channel).toList()
    ..sort((a, b) => b.row.lastDbm.compareTo(a.row.lastDbm));
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: SwColors.card,
    showDragHandle: true,
    builder: (context) {
      final clock = at == null
          ? null
          : '${at.toLocal().hour.toString().padLeft(2, '0')}:${at.toLocal().minute.toString().padLeft(2, '0')}';
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.viewPaddingOf(context).bottom),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text('$band GHz · channel $channel', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              [
                if (clock != null) 'Scan at $clock',
                if (dbm != null && dbm > -100) 'Loudest reading $dbm dBm',
                if (matches.isEmpty) 'Nothing on this channel in the last scan.',
                if (matches.isNotEmpty) '${matches.length} radio${matches.length == 1 ? '' : 's'} on this channel',
              ].join(' · '),
              style: const TextStyle(color: SwColors.muted, height: 1.35),
            ),
            const SizedBox(height: 12),
            for (final view in matches)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(view.displayName),
                subtitle: Text('${identityLine(vendor: view.vendor, category: view.category, tag: view.tag)}\n${view.signalLabel} · about ${view.distanceLabel}'),
                isThreeLine: true,
                onTap: () {
                  Navigator.pop(context);
                  showRadioSheet(context, view, env);
                },
              ),
          ],
        ),
      );
    },
  );
}

String _shared(RadioEnv env, RadioView view) {
  return sharedNameLine(
    sharedNameCount(env.views.where((item) => item.audible).map((item) => item.row.ssid), view.row.ssid),
  );
}

Widget _fact(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label  ', style: const TextStyle(color: SwColors.muted)),
          TextSpan(text: value),
        ],
      ),
    ),
  );
}
