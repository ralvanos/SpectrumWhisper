import 'package:flutter/material.dart';

import '../radio_env.dart';

class ListeningChoice extends StatelessWidget {
  const ListeningChoice({super.key, required this.env});

  final RadioEnv env;

  @override
  Widget build(BuildContext context) {
    final enabled = env.settings.monitoring;
    return RadioGroup<bool>(
      groupValue: enabled,
      onChanged: (value) async {
        if (value == null || value == enabled) return;
        env.settings.monitoring = value;
        await env.saveSettings();
        if (value) await env.scanNow();
      },
      child: const Column(
        children: [
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            value: true,
            title: Text('Enabled'),
            subtitle: Text('Listen while the app is open.'),
          ),
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            value: false,
            title: Text('Disabled'),
            subtitle: Text('Stop scans until listening is turned back on.'),
          ),
        ],
      ),
    );
  }
}
