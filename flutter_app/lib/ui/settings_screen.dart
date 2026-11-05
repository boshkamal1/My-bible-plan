import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../core/i18n.dart';
import '../services/cloud.dart';
import '../services/notifications.dart';
import '../state/app_state.dart';
import 'privacy_screen.dart';
import 'backup_screen.dart';
import 'theme.dart';

const bool _webPushReady = bool.fromEnvironment('WEB_PUSH_READY');

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _pickTime(BuildContext context, AppState s) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.remindH, minute: s.remindM),
    );
    if (t != null) {
      s.setReminders(h: t.hour, m: t.minute);
      final cloud = context.read<Cloud>();
      if (kIsWeb &&
          _webPushReady &&
          s.remindOn &&
          cloud.webNotificationPermission == 'granted') {
        final error = await cloud.saveWebReminder(s);
        if (error != null && context.mounted) toast(context, error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cl = context.watch<Cloud>();
    return Scaffold(
      appBar: AppBar(title: Text(tr('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _h(tr('language')),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'ar', label: Text(tr('arabic'))),
              const ButtonSegment(value: 'en', label: Text('English')),
            ],
            selected: {s.lang},
            onSelectionChanged: (v) => s.setLang(v.first),
          ),
          const SizedBox(height: 16),
          _h(tr('translation')),
          DropdownButton<String>(
            value: s.translation,
            isExpanded: true,
            items: [
              for (final id in ['svd', 'kjv', 'web'])
                DropdownMenuItem(
                    value: id,
                    child: Text(tr(id), overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) {
              if (v != null) s.setTranslation(v);
            },
          ),
          const SizedBox(height: 16),
          _h(tr('fontSize')),
          Slider(
            min: 14,
            max: 34,
            divisions: 10,
            value: s.fontSize.clamp(14, 34),
            label: s.fontSize.round().toString(),
            onChanged: s.setFont,
          ),
          _h(tr('theme')),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(tr('themeSystem'))),
              ButtonSegment(value: 1, label: Text(tr('themeLight'))),
              ButtonSegment(value: 2, label: Text(tr('themeDark'))),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => s.setTheme(v.first),
          ),
          const Divider(height: 32),
          _h(tr('reminders')),
          if (kIsWeb && !_webPushReady)
            Text(gEn
                ? 'Browser reminders will be available after setup is complete.'
                : 'إشعارات المتصفح هتكون متاحة بعد اكتمال إعدادها.'),
          SwitchListTile(
            title: Text(tr('dailyReminder')),
            value: s.remindOn,
            onChanged: kIsWeb && !_webPushReady
                ? null
                : (v) async {
                    if (kIsWeb) {
                      if (v) {
                        if (!cl.signedIn) {
                          toast(context, tr('needSignIn'));
                          return;
                        }
                        final error = await cl.saveWebReminder(s);
                        if (error != null) {
                          if (context.mounted) toast(context, error);
                          return;
                        }
                      } else {
                        await cl.disableWebReminder();
                      }
                    } else if (v) {
                      await Notifier.requestPermission();
                    }
                    s.setReminders(on: v);
                  },
          ),
          if (kIsWeb && _webPushReady && cl.signedIn && s.remindOn)
            OutlinedButton.icon(
              icon: const Icon(Icons.notifications_active_outlined),
              label: Text(gEn
                  ? 'Enable browser notifications'
                  : 'فعّل إشعارات المتصفح على هذا الجهاز'),
              onPressed: () async {
                final error = await cl.saveWebReminder(s);
                if (context.mounted)
                  toast(
                      context,
                      error ??
                          (gEn
                              ? 'Notifications enabled'
                              : 'تم تفعيل الإشعارات'));
              },
            ),
          ListTile(
            enabled: s.remindOn && (!kIsWeb || _webPushReady),
            title: Text(tr('reminderTime')),
            trailing: Text(
              '${s.remindH.toString().padLeft(2, '0')}:${s.remindM.toString().padLeft(2, '0')}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: s.remindOn && (!kIsWeb || _webPushReady)
                ? () => _pickTime(context, s)
                : null,
          ),
          if (!kIsWeb)
            SwitchListTile(
              title: Text(tr('streakReminder')),
              value: s.riskOn,
              onChanged: (v) async {
                if (v) await Notifier.requestPermission();
                s.setReminders(risk: v);
              },
            ),
          const Divider(height: 32),
          _h(tr('account')),
          if (!cl.available)
            Text(tr('cloudOff'))
          else if (!cl.signedIn)
            const _SignIn()
          else ...[
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text(cl.user?.displayName ?? cl.user?.email ?? '—'),
              subtitle: Text(cl.lastSync == null ? '' : tr('synced')),
            ),
            TextField(
              controller: TextEditingController(text: s.displayName),
              decoration: InputDecoration(
                labelText: gEn ? 'Display name' : 'الاسم المعروض',
                border: const OutlineInputBorder(),
              ),
              onSubmitted: s.setName,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.sync),
                  label: Text(tr('syncNow')),
                  onPressed: cl.busy ? null : () => cl.sync(s),
                ),
                OutlinedButton(
                  onPressed: cl.signOut,
                  child: Text(tr('signOut')),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _deleteAccount(context, s, cl),
                  child: Text(tr('deleteAccount')),
                ),
              ],
            ),
          ],
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: Text(gEn ? 'Backup & restore' : 'تصدير واسترجاع البيانات'),
            subtitle: Text(gEn
                ? 'Your plan, progress and notes in a file'
                : 'خطتك وتقدمك وملاحظاتك في ملف'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const BackupScreen())),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(tr('privacy')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PrivacyScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
            title: Text(
              tr('resetData'),
              style: const TextStyle(color: Colors.red),
            ),
            onTap: () async {
              final ok = await _confirm(
                context,
                gEn
                    ? 'Erase all data on this device?'
                    : 'هتتمسح كل بيانات الجهاز. متأكد؟',
              );
              if (ok) await s.wipeLocal();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(
    BuildContext context,
    AppState s,
    Cloud cl,
  ) async {
    final ok = await _confirm(context, tr('deleteConfirm'));
    if (!ok) return;
    final err = await cl.deleteAccount(s);
    if (context.mounted) {
      if (err == null) {
        toast(context, tr('ok'));
      } else if (err == 'requires-recent-login') {
        toast(
          context,
          gEn ? 'Sign in again, then retry' : 'سجّل الدخول من جديد وحاول تاني',
        );
        await cl.signOut();
      } else {
        toast(context, err);
      }
    }
  }
}

Widget _h(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        t,
        style: const TextStyle(fontWeight: FontWeight.bold, color: kGold),
      ),
    );

Future<bool> _confirm(BuildContext context, String msg) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(tr('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(tr('yes')),
        ),
      ],
    ),
  );
  return r ?? false;
}

class _SignIn extends StatefulWidget {
  const _SignIn();
  @override
  State<_SignIn> createState() => _SignInState();
}

class _SignInState extends State<_SignIn> {
  final _e = TextEditingController();
  final _p = TextEditingController();
  String? err;
  bool busy = false;

  Future<void> _run(Future<String?> Function() f) async {
    setState(() {
      busy = true;
      err = null;
    });
    final r = await f();
    if (!mounted) return;
    setState(() {
      busy = false;
      err = (r == 'cancelled') ? null : r;
    });
    if (r == null) {
      final s = context.read<AppState>();
      final c = context.read<Cloud>();
      c.sync(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cl = context.read<Cloud>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.login),
          label: Text(tr('signInGoogle')),
          onPressed: busy ? null : () => _run(cl.signInGoogle),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _e,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: tr('email'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _p,
          obscureText: true,
          decoration: InputDecoration(
            labelText: tr('password'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy
                    ? null
                    : () => _run(() => cl.signInEmail(_e.text, _p.text)),
                child: Text(tr('signIn')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: busy
                    ? null
                    : () => _run(
                          () => cl.signInEmail(_e.text, _p.text, create: true),
                        ),
                child: Text(tr('register')),
              ),
            ),
          ],
        ),
        if (err != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              err!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
