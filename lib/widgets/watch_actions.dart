import 'package:flutter/material.dart';

import '../radio_env.dart';
import '../logic/radio_math.dart';

class WatchActions extends StatefulWidget {
  const WatchActions({super.key, required this.env, required this.view});

  final RadioEnv env;
  final RadioView view;

  @override
  State<WatchActions> createState() => _WatchActionsState();
}

class _WatchActionsState extends State<WatchActions> {
  bool get _addressOn => widget.env.settings.pinned.contains(widget.view.row.bssid.toUpperCase());

  bool get _nameOn {
    final name = widget.view.row.ssid.trim().toLowerCase();
    if (name.isEmpty) return false;
    return widget.env.settings.watchNames.any((item) => item.trim().toLowerCase() == name);
  }

  @override
  Widget build(BuildContext context) {
    final named = widget.view.row.ssid.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Watch list keeps a name or an address so you can find it again. A short note stays with that entry.',
          style: TextStyle(height: 1.35),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () async {
                await widget.env.setWatchAddress(widget.view.row.bssid, on: !_addressOn);
                if (mounted) setState(() {});
              },
              child: Text(_addressOn ? 'Remove this address' : 'Watch this address'),
            ),
            if (named)
              OutlinedButton(
                onPressed: () async {
                  await widget.env.setWatchName(widget.view.row.ssid, on: !_nameOn);
                  if (mounted) setState(() {});
                },
                child: Text(_nameOn ? 'Remove this name' : 'Watch this name'),
              ),
          ],
        ),
        if (_addressOn) ...[
          const SizedBox(height: 8),
          _NoteBox(
            key: ValueKey('address-${widget.view.row.bssid}'),
            initial: widget.env.addressNote(widget.view.row.bssid),
            label: 'Note for this address',
            onSave: (value) => widget.env.setAddressNote(widget.view.row.bssid, value),
          ),
        ],
        if (_nameOn) ...[
          const SizedBox(height: 8),
          _NoteBox(
            key: ValueKey('name-${widget.view.row.ssid.trim().toLowerCase()}'),
            initial: widget.env.nameNote(widget.view.row.ssid),
            label: 'Note for this name',
            onSave: (value) => widget.env.setNameNote(widget.view.row.ssid, value),
          ),
        ],
      ],
    );
  }
}

class _NoteBox extends StatefulWidget {
  const _NoteBox({super.key, required this.initial, required this.label, required this.onSave});

  final String initial;
  final String label;
  final Future<void> Function(String value) onSave;

  @override
  State<_NoteBox> createState() => _NoteBoxState();
}

class _NoteBoxState extends State<_NoteBox> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);
  String _saved = '';

  @override
  void initState() {
    super.initState();
    _saved = widget.initial;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final clean = cleanWatchNote(_controller.text);
    await widget.onSave(clean);
    if (!mounted) return;
    _controller.text = clean;
    setState(() => _saved = clean);
  }

  @override
  Widget build(BuildContext context) {
    final pending = cleanWatchNote(_controller.text) != _saved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          maxLength: 80,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: 'Kitchen, neighbor, upstairs',
            counterText: '',
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _save(),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: pending ? _save : null,
            child: Text(_saved.isEmpty ? 'Save note' : 'Update note'),
          ),
        ),
      ],
    );
  }
}
