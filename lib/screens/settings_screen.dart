import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../radio_env.dart';
import '../theme.dart';
import '../widgets/listening_choice.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.env});

  final RadioEnv env;

  Future<void> _save() => env.saveSettings();

  @override
  Widget build(BuildContext context) {
    final settings = env.settings;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        const Text(
          'Settings',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Scans read broadcast Wi-Fi advertisements. Nothing is joined, and traffic is not captured. The catalog and settings are encrypted on this phone.',
          style: TextStyle(color: SwColors.muted, height: 1.35),
        ),
        const _Head('Reading size'),
        const Text(
          'Makes the words larger everywhere in the app. The zoom buttons on Around you enlarge that picture separately.',
          style: TextStyle(color: SwColors.muted, height: 1.35),
        ),
        const SizedBox(height: 8),
        SegmentedButton<double>(
          segments: const [
            ButtonSegment(value: 1, label: Text('Default')),
            ButtonSegment(value: 1.2, label: Text('Large')),
            ButtonSegment(value: 1.45, label: Text('Larger')),
          ],
          selected: {settings.textScale},
          onSelectionChanged: (value) async {
            settings.textScale = value.first;
            await _save();
          },
        ),
        const _Head('Listening'),
        const Text(
          'Passive monitoring',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'While the app is open. Android pauses scans in the background.',
          style: TextStyle(color: SwColors.muted, height: 1.35),
        ),
        ListeningChoice(env: env),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Scan interval'),
          subtitle: Text(
            '${_intervalLabel(settings.intervalSec)}\n'
            '30 seconds is the fastest useful pace. Android ignores quicker repeats. A scan is the phone listening for advertisements, and the Wi-Fi radio does send its own probe as part of that listen. This app does not add another signal and does not join a network.',
          ),
          trailing: DropdownButton<int>(
            value: settings.intervalSec,
            items: const [
              DropdownMenuItem(value: 30, child: Text('30s')),
              DropdownMenuItem(value: 45, child: Text('45s')),
              DropdownMenuItem(value: 60, child: Text('1 min')),
              DropdownMenuItem(value: 120, child: Text('2 min')),
              DropdownMenuItem(value: 300, child: Text('5 min')),
            ],
            onChanged: (value) async {
              if (value == null) return;
              settings.intervalSec = value;
              await _save();
            },
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sample environment'),
          subtitle: const Text(
            'Simulated radios, labeled on every screen. Useful on a phone with no scan permission.',
          ),
          value: settings.preview,
          onChanged: (value) async {
            settings.preview = value;
            await _save();
          },
        ),
        const _Head('What to show'),
        Wrap(
          spacing: 8,
          children: [
            for (final band in const ['2.4', '5', '6'])
              FilterChip(
                label: Text('$band GHz'),
                selected: settings.bands.contains(band),
                onSelected: (selected) async {
                  final next = List<String>.of(settings.bands);
                  if (selected) {
                    next.add(band);
                  } else {
                    next.remove(band);
                  }
                  settings.bands = next.isEmpty ? ['2.4', '5', '6'] : next;
                  await _save();
                },
              ),
          ],
        ),
        Text(
          'Hide audible radios under ${settings.minDbm} dBm',
          style: const TextStyle(color: SwColors.muted),
        ),
        Slider(
          min: -100,
          max: -50,
          divisions: 10,
          value: settings.minDbm.toDouble(),
          label: '${settings.minDbm} dBm',
          onChanged: (value) {
            settings.minDbm = value.round();
            env.notify();
          },
          onChangeEnd: (_) => _save(),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show hidden names'),
          value: settings.showHidden,
          onChanged: (value) async {
            settings.showHidden = value;
            await _save();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mark open networks'),
          value: settings.highlightOpen,
          onChanged: (value) async {
            settings.highlightOpen = value;
            await _save();
          },
        ),
        const _Head('Rule of thumb'),
        const Text(
          'Lists and Around you use the signal the phone measured. A stronger reading is drawn closer to you. Feet and meters are a rule of thumb from a standard formula. Walls, floors, weather, and how hard the radio transmits can move that number. The choices below only change that rule of thumb.',
          style: TextStyle(color: SwColors.muted, height: 1.35),
        ),
        DropdownButton<String>(
          isExpanded: true,
          value: settings.environment,
          items: const [
            DropdownMenuItem(value: 'indoor', child: Text('Indoor')),
            DropdownMenuItem(value: 'mixed', child: Text('Mixed')),
            DropdownMenuItem(value: 'outdoor', child: Text('Outdoor')),
            DropdownMenuItem(value: 'custom', child: Text('Custom exponent')),
          ],
          onChanged: (value) async {
            if (value == null) return;
            settings.environment = value;
            await _save();
          },
        ),
        if (settings.environment == 'custom')
          TextFormField(
            initialValue: settings.pathLoss.toString(),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Path-loss exponent'),
            onFieldSubmitted: (value) async {
              settings.pathLoss = double.tryParse(value) ?? settings.pathLoss;
              await _save();
            },
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Assumed transmit power: ${settings.txPowerDbm} dBm'),
        ),
        Slider(
          min: 0,
          max: 30,
          divisions: 30,
          value: settings.txPowerDbm.toDouble(),
          onChanged: (value) {
            settings.txPowerDbm = value.round();
            env.notify();
          },
          onChangeEnd: (_) => _save(),
        ),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'm', label: Text('Meters')),
            ButtonSegment(value: 'ft', label: Text('Feet')),
          ],
          selected: {settings.distanceUnit},
          onSelectionChanged: (value) async {
            settings.distanceUnit = value.first;
            await _save();
          },
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'both', label: Text('dBm + %')),
            ButtonSegment(value: 'dbm', label: Text('dBm')),
          ],
          selected: {settings.signalUnit},
          onSelectionChanged: (value) async {
            settings.signalUnit = value.first;
            await _save();
          },
        ),
        const _Head('Categories'),
        const Text(
          'A built-in catalog matches vehicle, hotspot, printer, router, phone, TV, camera, speaker, and appliance names, including common models and connected-car services. A clear name is used even when the hardware address is unknown or belongs to the chip maker. The vendor table supplies the make when the name does not. A randomized address with no matching name stays Unknown. The lists below are extra names you can add.',
          style: TextStyle(color: SwColors.muted, height: 1.35),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Automatic categories'),
          value: settings.autoClassify,
          onChanged: (value) async {
            settings.autoClassify = value;
            await _save();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Vehicle names'),
          subtitle: Text('${settings.vehiclePatterns.length} patterns'),
          onTap: () => _editList(
            context,
            'Vehicle names',
            settings.vehiclePatterns,
            (lines) async {
              settings.vehiclePatterns = lines;
              await _save();
            },
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Printer names'),
          subtitle: Text('${settings.printerPatterns.length} patterns'),
          onTap: () => _editList(
            context,
            'Printer names',
            settings.printerPatterns,
            (lines) async {
              settings.printerPatterns = lines;
              await _save();
            },
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Router names'),
          subtitle: Text('${settings.routerPatterns.length} patterns'),
          onTap: () => _editList(
            context,
            'Router names',
            settings.routerPatterns,
            (lines) async {
              settings.routerPatterns = lines;
              await _save();
            },
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hotspot names'),
          subtitle: Text('${settings.hotspotPatterns.length} patterns'),
          onTap: () => _editList(
            context,
            'Hotspot names',
            settings.hotspotPatterns,
            (lines) async {
              settings.hotspotPatterns = lines;
              await _save();
            },
          ),
        ),
        const _Head('Watch list'),
        const Text(
          'Save a network name or one hardware address to look up again. Tap an entry to add a short note, such as kitchen or neighbor. Open a radio and choose Watch this name or Watch this address. Remove it here or from that radio.',
          style: TextStyle(color: SwColors.muted, height: 1.35),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Notice when a watched radio is heard'),
          value: settings.alertWatch,
          onChanged: (value) async {
            settings.alertWatch = value;
            await _save();
          },
        ),
        if (settings.pinned.isEmpty && settings.watchNames.isEmpty)
          const Text(
            'Nothing is on the watch list.',
            style: TextStyle(color: SwColors.muted),
          )
        else ...[
          for (final name in settings.watchNames)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(name),
              subtitle: Text(_noteLine('Network name', env.nameNote(name))),
              onTap: () => _editNote(
                context,
                name,
                env.nameNote(name),
                (value) => env.setNameNote(name, value),
              ),
              trailing: IconButton(
                tooltip: 'Remove this name',
                onPressed: () => env.setWatchName(name, on: false),
                icon: const Icon(Icons.close),
              ),
            ),
          for (final mac in settings.pinned)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_watchTitle(env, mac)),
              subtitle: Text(_noteLine(mac, env.addressNote(mac))),
              onTap: () => _editNote(
                context,
                _watchTitle(env, mac),
                env.addressNote(mac),
                (value) => env.setAddressNote(mac, value),
              ),
              trailing: IconButton(
                tooltip: 'Remove this address',
                onPressed: () => env.setWatchAddress(mac, on: false),
                icon: const Icon(Icons.close),
              ),
            ),
        ],
        DropdownButton<int>(
          isExpanded: true,
          value: settings.catalogDays,
          items: const [
            DropdownMenuItem(
              value: 1,
              child: Text('Forget quiet radios after 1 day'),
            ),
            DropdownMenuItem(
              value: 7,
              child: Text('Forget quiet radios after 7 days'),
            ),
            DropdownMenuItem(
              value: 30,
              child: Text('Forget quiet radios after 30 days'),
            ),
            DropdownMenuItem(
              value: 0,
              child: Text('Keep quiet radios until I clear the catalog'),
            ),
          ],
          onChanged: (value) async {
            if (value == null) return;
            settings.catalogDays = value;
            await _save();
            await env.applyCatalogLimit();
          },
        ),
        const Text(
          'A radio that stays missing is dropped from the saved catalog after this time. Watched names and addresses stay, so known-for can continue when that radio returns. The live list already hides a radio the last scan missed.',
          style: TextStyle(color: SwColors.muted, height: 1.35),
        ),
        const _Head('Logging and sharing'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Log signal history'),
          value: settings.logging,
          onChanged: (value) async {
            settings.logging = value;
            await _save();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Record position with scans'),
          subtitle: const Text(
            'Off by default. Used only for the walk map and named spots.',
          ),
          value: settings.recordLocation,
          onChanged: (value) async {
            settings.recordLocation = value;
            await _save();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hide hardware addresses when sharing'),
          subtitle: const Text(
            'Applies to the log share and to snapshot text. A snapshot image leaves addresses out.',
          ),
          value: settings.redactBssid,
          onChanged: (value) async {
            settings.redactBssid = value;
            await _save();
          },
        ),
        DropdownButton<String>(
          isExpanded: true,
          value: settings.shareFormat,
          items: const [
            DropdownMenuItem(value: 'text', child: Text('Share as text')),
            DropdownMenuItem(value: 'csv', child: Text('Share as CSV')),
          ],
          onChanged: (value) async {
            if (value == null) return;
            settings.shareFormat = value;
            await _save();
          },
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4, bottom: 8),
          child: Text(
            'That format is for Share on the Log tab. Snapshot, on Live and Log, shares an image or a text list of this scan or a time range.',
            style: TextStyle(color: SwColors.muted, height: 1.35),
          ),
        ),
        DropdownButton<int>(
          isExpanded: true,
          value: settings.retentionDays,
          items: const [
            DropdownMenuItem(value: 1, child: Text('Keep history 1 day')),
            DropdownMenuItem(value: 7, child: Text('Keep history 7 days')),
            DropdownMenuItem(value: 30, child: Text('Keep history 30 days')),
            DropdownMenuItem(value: 90, child: Text('Keep history 90 days')),
            DropdownMenuItem(value: 365, child: Text('Keep history 1 year')),
            DropdownMenuItem(
              value: 0,
              child: Text('Keep history until I clear it'),
            ),
          ],
          onChanged: (value) async {
            if (value == null) return;
            settings.retentionDays = value;
            await _save();
          },
        ),
        const _Head('Charts and notices'),
        DropdownButton<int>(
          isExpanded: true,
          value: settings.chartWindowMin,
          items: const [
            DropdownMenuItem(value: 15, child: Text('Charts show 15 minutes')),
            DropdownMenuItem(value: 60, child: Text('Charts show 1 hour')),
            DropdownMenuItem(value: 360, child: Text('Charts show 6 hours')),
            DropdownMenuItem(value: 1440, child: Text('Charts show 1 day')),
          ],
          onChanged: (value) async {
            if (value == null) return;
            settings.chartWindowMin = value;
            await _save();
          },
        ),
        Text(
          settings.alertDbm == 0
              ? 'Signal notice is off'
              : 'Notice when a radio reaches ${settings.alertDbm} dBm',
          style: const TextStyle(color: SwColors.muted),
        ),
        Slider(
          min: -90,
          max: 0,
          divisions: 18,
          value: settings.alertDbm.toDouble(),
          label: settings.alertDbm == 0 ? 'Off' : '${settings.alertDbm} dBm',
          onChanged: (value) {
            settings.alertDbm = value.round();
            env.notify();
          },
          onChangeEnd: (_) => _save(),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('New network'),
          value: settings.alertNew,
          onChanged: (value) async {
            settings.alertNew = value;
            await _save();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Vehicle-like radio appears'),
          value: settings.alertVehicle,
          onChanged: (value) async {
            settings.alertVehicle = value;
            await _save();
          },
        ),
        const _Head('Meter'),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'uT', label: Text('µT')),
            ButtonSegment(value: 'mG', label: Text('mG')),
          ],
          selected: {settings.emfUnit},
          onSelectionChanged: (value) async {
            settings.emfUnit = value.first;
            await _save();
          },
        ),
        const _Head('On this phone'),
        OutlinedButton(
          onPressed: env.restoreSettings,
          child: const Text('Restore recommended settings'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () async {
            final ok = await _confirm(
              context,
              'Forget every remembered radio on this phone?',
            );
            if (ok) await env.clearCatalog();
          },
          child: const Text('Forget the radio catalog'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: env.clearPlaces,
          child: const Text('Clear spots'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: env.clearEmf,
          child: const Text('Clear meter log'),
        ),
        const _Head('Support'),
        const Text(
          kSupportMessage,
          style: TextStyle(color: SwColors.muted, height: 1.4),
        ),
        const SizedBox(height: 12),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1.1),
            1: FlexColumnWidth(2.2),
            2: FlexColumnWidth(1.2),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            const TableRow(
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Channel',
                    style: TextStyle(color: SwColors.muted),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Address',
                    style: TextStyle(color: SwColors.muted),
                  ),
                ),
                SizedBox.shrink(),
              ],
            ),
            TableRow(
              children: [
                const Text('Feedback'),
                const Text(kFeedbackEmail, style: TextStyle(fontSize: 12)),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => launchUrl(
                      Uri(
                        scheme: 'mailto',
                        path: kFeedbackEmail,
                        query: 'subject=SpectrumWhisper feedback',
                      ),
                    ),
                    child: const Text('Send'),
                  ),
                ),
              ],
            ),
            TableRow(
              children: [
                const Text('Bitcoin'),
                const Text(kDonateBtcAddress, style: TextStyle(fontSize: 11)),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        _copy(context, 'Bitcoin', kDonateBtcAddress),
                    child: const Text('Copy'),
                  ),
                ),
              ],
            ),
            TableRow(
              children: [
                const Text('Monero'),
                const Text(kDonateXmrAddress, style: TextStyle(fontSize: 11)),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        _copy(context, 'Monero', kDonateXmrAddress),
                    child: const Text('Copy'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  String _noteLine(String kind, String note) {
    if (note.isEmpty) return '$kind · Add a note';
    return '$kind · $note';
  }

  Future<void> _editNote(
    BuildContext context,
    String title,
    String current,
    Future<void> Function(String value) onSave,
  ) async {
    final controller = TextEditingController(text: current);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SwColors.card,
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: 'Note',
            hintText: 'Kitchen, neighbor, upstairs',
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => Navigator.pop(context, true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final text = controller.text;
    controller.dispose();
    if (saved == true) await onSave(text);
  }

  String _intervalLabel(int seconds) {
    if (seconds < 60)
      return 'Every $seconds seconds. Android may skip a scan if you go faster than it allows.';
    return 'Every ${seconds ~/ 60} minutes.';
  }

  String _watchTitle(RadioEnv env, String mac) {
    final row = env.rows[mac] ?? env.rows[mac.toUpperCase()];
    final name = row?.ssid.trim() ?? '';
    return name.isEmpty ? 'Hardware address' : name;
  }

  Future<void> _editList(
    BuildContext context,
    String title,
    List<String> current,
    Future<void> Function(List<String> lines) onSave,
  ) async {
    final controller = TextEditingController(text: current.join('\n'));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SwColors.card,
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(hintText: 'One name per line'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    final lines = controller.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    await onSave(lines);
  }

  Future<void> _copy(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label address copied')));
  }

  Future<bool> _confirm(BuildContext context, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: SwColors.card,
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Forget'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }
}
