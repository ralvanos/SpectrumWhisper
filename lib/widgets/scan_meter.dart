import 'dart:async';

import 'package:flutter/material.dart';

import '../radio_env.dart';
import '../theme.dart';

String scanStatusLabel(RadioEnv env) {
  if (env.scanning) return 'Scanning';
  if (!env.settings.monitoring) return 'Auto scan is off';
  if (!env.foreground) return 'Paused in background';
  final last = env.lastScan;
  if (last == null) return 'Waiting for a scan';
  final left = last.add(Duration(seconds: env.settings.intervalSec)).difference(DateTime.now()).inSeconds;
  if (left <= 0) return 'Refreshing';
  final minutes = left ~/ 60;
  final seconds = (left % 60).toString().padLeft(2, '0');
  return 'Next scan $minutes:$seconds';
}

double? scanProgress(RadioEnv env) {
  if (env.scanning) return null;
  if (!env.settings.monitoring || !env.foreground || env.lastScan == null) return 0;
  final total = env.settings.intervalSec;
  if (total <= 0) return 0;
  final left = env.lastScan!.add(Duration(seconds: total)).difference(DateTime.now()).inSeconds;
  if (left <= 0) return 1;
  return ((total - left) / total).clamp(0.0, 1.0);
}

class ScanMeter extends StatefulWidget {
  const ScanMeter({super.key, required this.env});

  final RadioEnv env;

  @override
  State<ScanMeter> createState() => _ScanMeterState();
}

class _ScanMeterState extends State<ScanMeter> with SingleTickerProviderStateMixin {
  late final StreamSubscription<dynamic> _tick;
  late final AnimationController _pulse;
  late int _seen;

  @override
  void initState() {
    super.initState();
    _seen = widget.env.scanPulse;
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    widget.env.addListener(_onEnv);
    _tick = Stream.periodic(const Duration(seconds: 1)).listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _onEnv() {
    if (!mounted) return;
    if (widget.env.scanPulse != _seen) {
      _seen = widget.env.scanPulse;
      _pulse.forward(from: 0);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _tick.cancel();
    widget.env.removeListener(_onEnv);
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = scanStatusLabel(widget.env);
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = _pulse.value;
            final scale = t == 0 || t == 1 ? 1.0 : 1 + (0.28 * (t < 0.5 ? t / 0.5 : (1 - t) / 0.5));
            return Transform.scale(scale: scale, child: child);
          },
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              value: scanProgress(widget.env),
              strokeWidth: 3,
              color: SwColors.teal,
              backgroundColor: SwColors.line,
            ),
          ),
        ),
      ),
    );
  }
}
