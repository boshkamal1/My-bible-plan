import 'package:flutter/material.dart';

const Color kGold = Color(0xFFB8893A);
const Color kNavy = Color(0xFF1F2A44);

const List<Color> kHlColors = [
  Color(0xFFFFE680),
  Color(0xFFA8E6A1),
  Color(0xFFA6D4FF),
  Color(0xFFFFB3C1),
];

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: kGold,
    brightness: b,
    surface: dark ? const Color(0xFF14171F) : const Color(0xFFFBF8F1),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: kGold.withValues(alpha: 0.25),
    ),
  );
}

void toast(BuildContext c, String m) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(m), behavior: SnackBarBehavior.floating),
    );
}
