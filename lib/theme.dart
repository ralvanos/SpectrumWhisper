import 'package:flutter/material.dart';

class SwColors {
  static const ink = Color(0xFF101410);
  static const card = Color(0xFF1B2420);
  static const line = Color(0xFF314038);
  static const paper = Color(0xFFE7F3EC);
  static const muted = Color(0xFF93A59A);
  static const teal = Color(0xFF3DCEB6);
  static const amber = Color(0xFFE2A23A);
  static const rose = Color(0xFFE36D6D);
  static const slate = Color(0xFF9AABBD);
  static const catHotspot = Color(0xFFB388FF);
  static const catRouter = Color(0xFF64B5F6);
  static const catMobile = Color(0xFFF06292);
  static const catOther = Color(0xFFDCE775);
}

ThemeData swTheme() {
  const scheme = ColorScheme.dark(
    primary: SwColors.teal,
    secondary: SwColors.amber,
    surface: SwColors.ink,
    error: SwColors.rose,
    onPrimary: Color(0xFF10211C),
    onSurface: SwColors.paper,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: SwColors.ink,
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFF161C18),
      indicatorColor: Color(0x333DCEB6),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: SwColors.card,
      contentTextStyle: const TextStyle(color: SwColors.paper),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
