import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/data_backup.dart';
import '../core/encrypted_backup.dart';
import '../core/i18n.dart';
import '../state/app_state.dart';
import '../services/backup_download_stub.dart'
    if (dart.library.io) '../services/backup_download_io.dart'
    if (dart.library.js_interop) '../services/backup_download_web.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});
  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  String? _message;
  bool _error = false;

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      final message = await action();
      if (mounted) setState(() => _message = message);
    } on FormatException {
      if (mounted)
        setState(() {
          _error = true;
          _message = gEn
              ? 'This backup is invalid or unsupported. Your current data was kept.'
              : 'ملف النسخة الاحتياطية غير صالح أو غير مدعوم. بياناتك الحالية محفوظة.';
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _error = true;
          _message = gEn
              ? 'Could not complete the operation. Please try again.'
              : 'تعذر إكمال العملية. حاول تاني.';
        });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _export({bool encrypted = false}) async {
    final state = context.read<AppState>(),
        session = context.read<AppState>().sessionRevision;
    var source = state.exportBackup();
    if (encrypted) {
      final password = await showDialog<String>(
          context: context,
          builder: (_) => const _BackupPasswordDialog(confirm: true));
      if (password == null) return null;
      source = await EncryptedBackup.encrypt(source, password);
    }
    if (!mounted || state.sessionRevision != session) return null;
    final filename =
        'bible-plan-backup-${DateTime.now().toIso8601String().substring(0, 10)}${encrypted ? '.encrypted' : ''}.json';
    final path = await downloadBackup(source, filename);
    if (path == '') return null;
    return path == null
        ? (gEn
            ? 'Backup prepared. Keep the JSON file in a safe place.'
            : 'النسخة جاهزة. احتفظ بملف JSON في مكان آمن.')
        : (gEn ? 'Backup saved: $path' : 'تم حفظ النسخة: $path');
  }

  Future<String?> _import() async {
    final file = await openFile(acceptedTypeGroups: [
      const XTypeGroup(
        label: 'Bible plan backup',
        extensions: ['json'],
        mimeTypes: ['application/json'],
        uniformTypeIdentifiers: ['public.json'],
      )
    ]);
    if (file == null) return null;
    if (await file.length() > EncryptedBackup.maxEnvelopeBytes)
      throw const FormatException('Backup too large');
    final source = utf8.decode(await file.readAsBytes());
    DataBackup backup;
    if (EncryptedBackup.isEncrypted(source)) {
      if (!mounted) return null;
      final password = await showDialog<String>(
          context: context,
          builder: (_) => const _BackupPasswordDialog(confirm: false));
      if (password == null) return null;
      backup = await EncryptedBackup.decrypt(source, password);
    } else {
      backup = DataBackup.decode(source);
    }
    if (!mounted) return null;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(gEn ? 'Restore this backup?' : 'استرجاع النسخة دي؟'),
              content: SingleChildScrollView(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(gEn
                        ? 'Completed chapters: ${backup.completed}'
                        : 'أصحاحات مقروءة: ${backup.completed}'),
                    Text(gEn
                        ? 'Notes: ${backup.noteCount} • Favorites: ${backup.favorites}'
                        : 'ملاحظات: ${backup.noteCount} • مفضلة: ${backup.favorites}'),
                    Text(backup.readingDays == null
                        ? (gEn ? 'No reading plan' : 'بدون خطة قراءة')
                        : (gEn
                            ? 'Plan: ${backup.readingDays} reading days'
                            : 'الخطة: ${backup.readingDays} يوم قراءة')),
                    const SizedBox(height: 16),
                    Text(gEn
                        ? 'This replaces your current plan, progress, notes and settings. Export your current data first if you want to keep it. Restored data will sync if you are signed in.'
                        : 'هيستبدل الخطة والتقدم والملاحظات والإعدادات الحالية. صدّر بياناتك الأول لو محتاج تحتفظ بيها. البيانات المسترجعة هتتزامن لو مسجل دخول.'),
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(tr('cancel'))),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(gEn ? 'Restore' : 'استرجاع')),
              ],
            ));
    if (confirmed != true || !mounted) return null;
    await context.read<AppState>().restoreBackup(backup);
    return gEn ? 'Your data has been restored.' : 'تم استرجاع بياناتك.';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(gEn ? 'Backup & restore' : 'تصدير واسترجاع البيانات')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  const Icon(Icons.backup_outlined, size: 52),
                  const SizedBox(height: 16),
                  Text(
                      gEn
                          ? 'Keep a copy of your journey'
                          : 'احتفظ بنسخة من رحلتك',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text(gEn
                      ? 'Your plan, daily assignments, progress, notes, highlights, favorites, reading time and settings in one JSON file. You can restore it on another device or on the backup site.'
                      : 'خطتك وتوزيع الأيام والتقدم والملاحظات والتظليل والمفضلة ووقت القراءة والإعدادات في ملف JSON واحد. تقدر تسترجعه على جهاز تاني أو الموقع الاحتياطي.'),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                      onPressed: _busy ? null : () => _run(() => _export()),
                      icon: const Icon(Icons.file_download_outlined),
                      label:
                          Text(gEn ? 'Export backup' : 'تصدير نسخة احتياطية')),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(() => _export(encrypted: true)),
                      icon: const Icon(Icons.lock_outline),
                      label: Text(gEn
                          ? 'Export encrypted backup'
                          : 'تصدير نسخة مشفرة بكلمة مرور')),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      onPressed: _busy ? null : () => _run(_import),
                      icon: const Icon(Icons.upload_file_outlined),
                      label:
                          Text(gEn ? 'Restore from file' : 'استرجاع من ملف')),
                  if (_busy)
                    const Padding(
                        padding: EdgeInsets.all(16),
                        child: LinearProgressIndicator()),
                  if (_message != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Text(_message!,
                            style: TextStyle(
                                color: _error
                                    ? Theme.of(context).colorScheme.error
                                    : null))),
                ]))),
      );
}

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog({required this.confirm});
  final bool confirm;
  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final password = TextEditingController(), repeat = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    password.clear();
    repeat.clear();
    password.dispose();
    repeat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(gEn ? 'Backup password' : 'كلمة مرور النسخة'),
          content: Form(
              key: form,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(gEn
                    ? 'This protects the file. Keep the password separately; a forgotten password cannot be recovered.'
                    : 'دي كلمة مرور للملف. احفظها في مكان منفصل؛ لو نسيتها مش هنقدر نرجّع النسخة المشفرة.'),
                TextFormField(
                    controller: password,
                    obscureText: true,
                    autofocus: true,
                    decoration: InputDecoration(
                        labelText: gEn ? 'Password' : 'كلمة المرور'),
                    validator: (v) => v == null ||
                            v.isEmpty ||
                            (widget.confirm && v.length < 12) ||
                            v.length > 1024
                        ? (gEn
                            ? 'Use at least 12 characters'
                            : 'استخدم 12 حرف على الأقل')
                        : null),
                if (widget.confirm)
                  TextFormField(
                      controller: repeat,
                      obscureText: true,
                      decoration: InputDecoration(
                          labelText:
                              gEn ? 'Confirm password' : 'تأكيد كلمة المرور'),
                      validator: (v) => v != password.text
                          ? (gEn
                              ? 'Passwords do not match'
                              : 'كلمتا المرور مش متطابقتين')
                          : null),
              ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr('cancel'))),
            FilledButton(
                onPressed: () {
                  if (form.currentState!.validate())
                    Navigator.pop(context, password.text);
                },
                child: Text(gEn ? 'Continue' : 'متابعة'))
          ]);
}
