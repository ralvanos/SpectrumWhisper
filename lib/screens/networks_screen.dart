import 'package:flutter/material.dart';

import '../logic/radio_math.dart';
import '../radio_env.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/watch_actions.dart';

class NetworksScreen extends StatefulWidget {
  const NetworksScreen({super.key, required this.env});

  final RadioEnv env;

  @override
  State<NetworksScreen> createState() => _NetworksScreenState();
}

class _NetworksScreenState extends State<NetworksScreen> {
  String _filter = 'audible';
  String _query = '';
  String _sort = 'signal';

  @override
  Widget build(BuildContext context) {
    final env = widget.env;
    final query = _query.trim().toLowerCase();
    final rows = env.views.where((view) {
      if (_filter == 'watch') {
        if (!view.pinned) return false;
      } else if (!view.audible) {
        return false;
      }
      if (_filter == 'private' && !privateAddress(view.row.bssid)) return false;
      const categories = {'vehicle', 'hotspot', 'printer', 'phone', 'router', 'tv', 'camera', 'other', 'unknown'};
      if (_filter == 'other') {
        const grouped = {'other', 'speaker', 'appliance'};
        if (!grouped.contains(view.category)) return false;
      } else if (categories.contains(_filter) && view.category != _filter) {
        return false;
      }
      if (_filter == 'open' && !view.open) return false;
      if (query.isEmpty) return true;
      final haystack = '${view.displayName} ${view.row.bssid} ${view.row.auth} ${view.vendor}'.toLowerCase();
      return haystack.contains(query);
    }).toList();
    rows.sort((a, b) {
      switch (_sort) {
        case 'name':
          return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
        case 'band':
          final band = a.row.band.compareTo(b.row.band);
          if (band != 0) return band;
          return a.row.channel.compareTo(b.row.channel);
        default:
          return b.row.lastDbm.compareTo(a.row.lastDbm);
      }
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Radios', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(hintText: 'Name, address, or security'),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),
              const Text(
                'This list is the last completed scan. The number on the right is signal strength. Open a radio for the rule-of-thumb distance. Private is a randomized address. Hidden names are turned on or off in Settings.',
                style: TextStyle(color: SwColors.muted, fontSize: 13, height: 1.35),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final item in const ['audible', 'watch', 'private', 'vehicle', 'hotspot', 'printer', 'router', 'phone', 'tv', 'camera', 'other', 'unknown', 'open'])
                    ChoiceChip(
                      label: Text(item == 'phone' ? 'mobile' : item),
                      selected: _filter == item,
                      onSelected: (_) => setState(() => _filter = item),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final item in const ['signal', 'name', 'band'])
                    ChoiceChip(
                      label: Text(item),
                      selected: _sort == item,
                      onSelected: (_) => setState(() => _sort = item),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
                  child: Text(
                    _filter == 'watch'
                        ? 'Nothing is on the watch list.'
                        : 'Nothing in this list from the last completed scan.',
                    style: const TextStyle(color: SwColors.muted, height: 1.35),
                  ),
                )
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final view = rows[index];
              final known = formatSpan(view.row.lastSeen.difference(view.row.firstSeen));
              return ListTile(
                title: Row(
                  children: [
                    Expanded(child: Text(view.displayName)),
                    if (env.freshBssids.contains(view.row.bssid))
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Text('New', style: TextStyle(color: SwColors.teal, fontSize: 12, fontWeight: FontWeight.w700)),
                      ),
                    if (view.pinned) const Icon(Icons.flag_outlined, size: 16, color: SwColors.teal),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${identityLine(vendor: view.vendor, category: view.category, tag: view.tag)}${view.note.isEmpty ? '' : ' · ${view.note}'}\n${view.row.band} GHz ch ${view.row.channel} · known $known',
                    ),
                    SignalTrace(samples: view.row.signals, height: 28, compact: true),
                  ],
                ),
                isThreeLine: true,
                trailing: Text(
                  view.audible ? view.signalLabel : 'Not heard',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () => _open(context, view),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _open(BuildContext context, RadioView view) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SwColors.card,
      builder: (context) {
        const choices = {'auto', 'vehicle', 'hotspot', 'printer', 'phone', 'router', 'tv', 'camera', 'speaker', 'appliance', 'other', 'unknown'};
        var category = view.row.overrideCategory == 'building'
            ? 'other'
            : (choices.contains(view.row.overrideCategory) ? view.row.overrideCategory : 'auto');
        return StatefulBuilder(
          builder: (context, setSheet) {
            final visit = view.audible
                ? 'This visit ${formatSpan(DateTime.now().difference(view.row.presentSince ?? view.row.lastSeen))}'
                : 'Last visit ${formatSpan(Duration(seconds: view.row.lastVisitSec.round()))}';
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(view.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(view.reason, style: const TextStyle(color: SwColors.muted, height: 1.35)),
                  const SizedBox(height: 12),
                  _line('SSID', view.displayName),
                  _line('BSSID', view.row.bssid),
                  _line('RSSI', view.signalLabel),
                  const SizedBox(height: 6),
                  SignalTrace(samples: view.row.signals),
                  const SizedBox(height: 8),
                  _line('Frequency', '${frequencyMhz(view.row.band, view.row.channel)} MHz'),
                  _line('Channel', '${view.row.band} GHz · ${view.row.channel}'),
                  _line('Center', _center(view)),
                  _line('Bandwidth', widthLabel(view.row.widthMhz)),
                  _line('Standard', view.row.radio.isEmpty ? 'Not reported' : view.row.radio),
                  _line('Security', view.row.auth),
                  _line('Access points on this channel', '${_sharing(view)} others audible now'),
                  _line('This session', _session(view)),
                  _line('SNR', 'Not reported. This phone does not provide a noise floor.'),
                  _line('Rule of thumb', ruleOfThumbLine(view.distanceLabel)),
                  _line('Known', '${formatSpan(view.row.lastSeen.difference(view.row.firstSeen))} · $visit'),
                  _line('First heard', _clock(view.row.firstSeen)),
                  _line('Last heard', _clock(view.row.lastSeen)),
                  _line('Identity', identityLine(vendor: view.vendor, category: view.category, tag: view.tag)),
                  _line('Maker', view.vendor),
                  if (view.note.isNotEmpty) _line('Note', view.note),
                  if (_sameName(view).isNotEmpty) _line('Same name', _sameName(view)),
                  const SizedBox(height: 8),
                  const Text(
                    'These fields come from the access point advertisement. Client devices, probe requests, and other traffic are not part of this scan.',
                    style: TextStyle(color: SwColors.muted, height: 1.35, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  WatchActions(env: widget.env, view: view),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: category == 'building' ? 'other' : category,
                    dropdownColor: SwColors.card,
                    items: const [
                      DropdownMenuItem(value: 'auto', child: Text('Automatic category')),
                      DropdownMenuItem(value: 'vehicle', child: Text('Vehicle')),
                      DropdownMenuItem(value: 'hotspot', child: Text('Hotspot')),
                      DropdownMenuItem(value: 'printer', child: Text('Printer')),
                      DropdownMenuItem(value: 'phone', child: Text('Mobile')),
                      DropdownMenuItem(value: 'router', child: Text('Router')),
                      DropdownMenuItem(value: 'tv', child: Text('TV')),
                      DropdownMenuItem(value: 'camera', child: Text('Camera')),
                      DropdownMenuItem(value: 'speaker', child: Text('Speaker')),
                      DropdownMenuItem(value: 'appliance', child: Text('Appliance')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                      DropdownMenuItem(value: 'unknown', child: Text('Unknown')),
                    ],
                    onChanged: (value) async {
                      if (value == null) return;
                      setSheet(() => category = value);
                      await widget.env.setOverride(view.row.bssid, value);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _sameName(RadioView view) {
    return sharedNameLine(
      sharedNameCount(widget.env.views.where((item) => item.audible).map((item) => item.row.ssid), view.row.ssid),
    );
  }

  String _center(RadioView view) {
    if (view.row.centerMhz <= 0) return 'Not reported';
    if (view.row.centerMhz2 > 0) return '${view.row.centerMhz} MHz and ${view.row.centerMhz2} MHz';
    return '${view.row.centerMhz} MHz';
  }

  int _sharing(RadioView view) {
    return widget.env.views.where((other) {
      return other.audible &&
          other.row.bssid != view.row.bssid &&
          other.row.band == view.row.band &&
          other.row.channel == view.row.channel;
    }).length;
  }

  String _session(RadioView view) {
    final scans = widget.env.activeFrames.length;
    final hits = widget.env.sessionHits(view.row.bssid);
    final stay = ChannelStay(band: view.row.band, channel: view.row.channel, hits: hits, scans: scans, aps: 0, dbm: view.row.lastDbm);
    return '${stay.pattern}. ${stay.presenceLabel}.';
  }

  String _clock(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _line(String label, String value) {
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
}
