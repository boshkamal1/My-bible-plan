import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../services/cloud.dart';
import '../state/app_state.dart';
import 'account_screen.dart';
import 'download_screen.dart';
import 'search_screen.dart';
import 'theme.dart';

class WebHomeBar extends StatelessWidget implements PreferredSizeWidget {
  const WebHomeBar({super.key});

  @override
  Size get preferredSize => Size.fromHeight(kIsWeb ? 100 : 56);

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return AppBar(
        centerTitle: true,
        title: Text(tr('appName')),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: tr('search'),
            onPressed: () => _open(context, const SearchScreen()),
          ),
        ],
      );
    }

    final cloud = context.watch<Cloud>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Theme.of(context).appBarTheme.backgroundColor ??
          Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: tr('search'),
                      onPressed: () => _open(context, const SearchScreen()),
                    ),
                    TextButton.icon(
                      onPressed: () => _open(context, const DownloadScreen()),
                      icon: const Icon(Icons.download_outlined),
                      label: Text(gEn ? 'Download' : 'التنزيل'),
                    ),
                    IconButton(
                      color: accentColor(context),
                      iconSize: 26,
                      icon: CustomPaint(
                        size: const Size(26, 26),
                        painter:
                            _ThemeSymbolPainter(dark, accentColor(context)),
                      ),
                      tooltip: dark
                          ? (gEn
                              ? 'Switch to light mode'
                              : 'التبديل للوضع الفاتح')
                          : (gEn
                              ? 'Switch to dark mode'
                              : 'التبديل للوضع الداكن'),
                      onPressed: () =>
                          context.read<AppState>().setTheme(dark ? 1 : 2),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () =>
                              _open(context, const AccountScreen()),
                          icon: Icon(cloud.signedIn
                              ? Icons.account_circle_outlined
                              : Icons.login),
                          label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                cloud.signedIn
                                    ? tr('account')
                                    : (gEn
                                        ? 'Sign in / Sign up'
                                        : 'تسجيل الدخول / إنشاء حساب'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textDirection:
                                    gEn ? TextDirection.ltr : TextDirection.rtl,
                              )),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  tr('appName'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}

class _ThemeSymbolPainter extends CustomPainter {
  const _ThemeSymbolPainter(this.sun, this.color);
  final bool sun;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final paint = Paint()..color = color;
    if (sun) {
      canvas.drawCircle(center, radius * .4, paint);
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final direction = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(center + direction * (radius * .64),
            center + direction * (radius * .92), paint);
      }
    } else {
      final outer = Path()
        ..addOval(Rect.fromCircle(center: center, radius: radius * .86));
      final inner = Path()
        ..addOval(Rect.fromCircle(
            center: center + Offset(radius * .43, -radius * .28),
            radius: radius * .77));
      canvas.drawPath(
          Path.combine(PathOperation.difference, outer, inner), paint);
    }
  }

  @override
  bool shouldRepaint(_ThemeSymbolPainter oldDelegate) =>
      oldDelegate.sun != sun || oldDelegate.color != color;
}
