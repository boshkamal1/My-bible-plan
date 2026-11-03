import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/day_util.dart';
import '../core/i18n.dart';
import '../state/app_state.dart';

class Notifier {
  static final FlutterLocalNotificationsPlugin _p =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
      const init = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _p.initialize(init);
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  static Future<bool> requestPermission() async {
    if (!_ready) return false;
    final a = _p
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final r1 = await a?.requestNotificationsPermission();
    final i = _p
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final r2 = await i?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return (r1 ?? r2 ?? true);
  }

  static NotificationDetails _details(String channel, String name) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          name,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  static Future<void> reschedule(AppState s) async {
    if (!_ready) return;
    try {
      await _p.cancelAll();
      if (!s.hasPlan) return;
      final now = tz.TZDateTime.now(tz.local);
      final st = s.streak;
      final todayRead =
          st.readToday ||
          s.frozenDates.contains(dayStr(s.today)) ||
          s.dayComplete(s.dayIndex);
      for (var i = 0; i < 14; i++) {
        final day = now.add(Duration(days: i));
        if (s.remindOn && !(i == 0 && todayRead)) {
          final at = tz.TZDateTime(
            tz.local,
            day.year,
            day.month,
            day.day,
            s.remindH,
            s.remindM,
          );
          if (at.isAfter(now)) {
            await _p.zonedSchedule(
              100 + i,
              tr('notifDailyTitle'),
              '${tr('notifDailyBody')}: ${s.todaySummary()}',
              at,
              _details('daily', 'Daily reminder'),
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
          }
        }
        if (s.riskOn && st.cur > 0 && !(i == 0 && todayRead)) {
          final at = tz.TZDateTime(
            tz.local,
            day.year,
            day.month,
            day.day,
            20,
            30,
          );
          if (at.isAfter(now)) {
            await _p.zonedSchedule(
              200 + i,
              tr('notifRiskTitle'),
              tr('notifRiskBody'),
              at,
              _details('risk', 'Streak alert'),
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
            );
          }
        }
      }
    } catch (_) {}
  }
}
