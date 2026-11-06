import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../core/i18n.dart';
import 'backup_screen.dart';

class SyncConflictsScreen extends StatelessWidget {
  const SyncConflictsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
          title:
              Text(gEn ? 'Saved conflicting versions' : 'نسخ مختلفة محفوظة')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(gEn
            ? 'Changes from different devices were kept. Choose the version to use; export a backup first to keep all alternatives.'
            : 'حفظنا التعديلات المختلفة من أجهزتك. اختار النسخة اللي عايز تستخدمها، وتقدر تصدّر Backup الأول عشان تحتفظ بكل النسخ.'),
        TextButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const BackupScreen())),
            icon: const Icon(Icons.download),
            label: Text(gEn ? 'Backup' : 'تصدير نسخة احتياطية')),
        if (state.syncConflicts.isEmpty)
          Text(gEn
              ? 'All conflicts resolved.'
              : 'مفيش نسخ متعارضة محتاجة اختيار.'),
        for (final item in state.syncConflicts.entries) ...[
          const Divider(),
          _versions(context, state, item.key, jsonDecode(item.value)),
        ],
      ]),
    );
  }

  Widget _versions(
      BuildContext context, AppState state, String id, Map record) {
    final field = record['field'];
    final title = {
          'notes': 'ملاحظة',
          'done': 'قراءة',
          'hl': 'تظليل',
          'badgeDates': 'وسام',
          'journey': 'الخطة'
        }[field] ??
        'بيانات محفوظة';
    final values = record['versions'] as List;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(gEn ? 'Choose a saved version' : title,
          style: Theme.of(context).textTheme.titleMedium),
      for (var i = 0; i < values.length; i++)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (field == 'journey' && values[i] is Map)
                        Text((values[i]['setup'] == null)
                            ? (gEn ? 'No active plan' : 'من غير خطة نشطة')
                            : (gEn
                                ? 'Plan starting ${values[i]['setup']['start']} (${values[i]['setup']['days']} requested days)'
                                : 'خطة بتبدأ ${values[i]['setup']['start']} · المدة المختارة ${values[i]['setup']['days']} يوم'))
                      else
                        SelectableText(values[i] == null
                            ? (gEn ? 'Delete this item' : 'حذف العنصر')
                            : values[i].toString()),
                      TextButton(
                          onPressed: () {
                            try {
                              state.resolveConflict(id, i);
                            } catch (_) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(gEn
                                      ? 'This version could not be applied safely.'
                                      : 'تعذر تطبيق النسخة دي بأمان. بياناتك الحالية محفوظة.')));
                            }
                          },
                          child: Text(
                              gEn ? 'Use this version' : 'استخدم النسخة دي')),
                    ]))),
    ]);
  }
}
