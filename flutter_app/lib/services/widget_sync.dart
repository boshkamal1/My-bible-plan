import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:home_widget/home_widget.dart';

import '../core/i18n.dart';
import '../state/app_state.dart';

class WidgetSync {
  static Future<void> update(AppState s) async {
    if (kIsWeb) return;
    try {
      final st = s.streak;
      await HomeWidget.saveWidgetData<String>(
        'title',
        s.hasPlan ? '${tr('day')} ${nf(s.dayIndex + 1)}' : tr('appName'),
      );
      await HomeWidget.saveWidgetData<String>('body', s.todaySummary());
      await HomeWidget.saveWidgetData<String>('streak', '🔥 ${nf(st.cur)}');
      await HomeWidget.saveWidgetData<String>(
        'pct',
        '${nf((s.percent * 100).round())}%',
      );
      await HomeWidget.updateWidget(
        name: 'BibleWidgetProvider',
        androidName: 'BibleWidgetProvider',
      );
    } catch (_) {}
  }
}
