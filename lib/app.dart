import 'package:flutter/material.dart';

import 'radio_env.dart';
import 'screens/heat_screen.dart';
import 'screens/live_screen.dart';
import 'screens/log_screen.dart';
import 'screens/networks_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';
import 'widgets/scan_meter.dart';

class SpectrumApp extends StatefulWidget {
  const SpectrumApp({super.key, required this.env});

  final RadioEnv env;

  @override
  State<SpectrumApp> createState() => _SpectrumAppState();
}

class _SpectrumAppState extends State<SpectrumApp> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.env.addListener(_onEnv);
    widget.env.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.env.removeListener(_onEnv);
    widget.env.dispose();
    super.dispose();
  }

  void _onEnv() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.env.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    final env = widget.env;
    final scale = env.settings.textScale;
    return MaterialApp(
      title: 'SpectrumWhisper',
      debugShowCheckedModeBanner: false,
      theme: swTheme(),
      builder: (context, child) {
        final system = MediaQuery.textScalerOf(context).scale(1);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(system * scale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ScanMeter(env: env),
                ),
              ),
              Expanded(child: _page(env, _index)),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.sensors), label: 'Live'),
            NavigationDestination(icon: Icon(Icons.grid_on), label: 'Heat'),
            NavigationDestination(icon: Icon(Icons.wifi), label: 'Radios'),
            NavigationDestination(icon: Icon(Icons.ios_share), label: 'Log'),
            NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

Widget _page(RadioEnv env, int index) {
  switch (index) {
    case 1:
      return HeatScreen(env: env);
    case 2:
      return NetworksScreen(env: env);
    case 3:
      return LogScreen(env: env);
    case 4:
      return SettingsScreen(env: env);
    default:
      return LiveScreen(env: env);
  }
}
