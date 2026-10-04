import 'package:flutter/material.dart';

import 'app.dart';
import 'radio_env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = RadioEnv();
  await env.load();
  runApp(SpectrumApp(env: env));
}
