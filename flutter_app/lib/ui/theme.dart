import 'package:flutter/material.dart';

const Color kGold = Color(0xFFB8893A);
const Color kNavy = Color(0xFF1F2A44);
const Color kDarkGold = Color(0xFFD7AF62);
const Color kDarkBackground = Color(0xFF101827);
const Color kDarkCard = Color(0xFF1B2940);

Color accentColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? kDarkGold : kGold;

const List<Color> kHlColors = [
  Color(0xFFFFE680),
  Color(0xFFA8E6A1),
  Color(0xFFA6D4FF),
  Color(0xFFFFB3C1),
];

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final baseScheme = ColorScheme.fromSeed(
    seedColor: kGold,
    brightness: b,
    surface: dark ? kDarkBackground : const Color(0xFFFBF8F1),
  );
  final scheme = dark
      ? baseScheme.copyWith(
          primary: kDarkGold,
          onPrimary: kDarkBackground,
          secondary: kDarkGold,
          onSecondary: kDarkBackground,
          primaryContainer: const Color(0xFF34415A),
          onPrimaryContainer: const Color(0xFFF3EDDE),
          surfaceContainerLow: kDarkCard,
          surfaceContainer: kDarkCard,
          surfaceContainerHigh: const Color(0xFF24344D),
          surfaceContainerHighest: const Color(0xFF30425B),
          onSurface: const Color(0xFFF3EDDE),
          onSurfaceVariant: const Color(0xFFC5CBD5),
          outline: const Color(0xFF8391A6),
          outlineVariant: const Color(0xFF354660),
        )
      : baseScheme;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: dark
        ? const CardThemeData(
            color: kDarkCard,
            surfaceTintColor: Colors.transparent,
          )
        : null,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: (dark ? kDarkGold : kGold).withValues(alpha: 0.25),
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
