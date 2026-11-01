import 'package:flutter/material.dart';

import '../core/i18n.dart';

const String _ar = '''
سياسة الخصوصية

آخر تحديث: ٢٠٢٦

١. ما الذي نجمعه
- بيانات القراءة: الأصحاحات التي أتممتها، الملاحظات، التمييز، المفضلة، وقت القراءة، إعدادات الخطة.
- إذا سجّلت الدخول: بريدك الإلكتروني واسمك المعروض ومعرّف الحساب.
- إذا انضممت إلى مجموعة: اسمك المعروض وعدد الأصحاحات المقروءة وسلسلة الأيام ونسبة الإنجاز تظهر لأعضاء المجموعة.

٢. أين تُحفظ البيانات
- على جهازك دائمًا.
- في خدمة Firebase التابعة لشركة Google عند تسجيل الدخول فقط، لمزامنة بياناتك بين أجهزتك.

٣. ما لا نفعله
- لا نبيع بياناتك ولا نعرض إعلانات ولا نتتبّعك.
- لا نقرأ ملاحظاتك لأي غرض آخر.

٤. الإشعارات
التذكيرات تُجدول محليًا على جهازك ولا تحتاج إلى خادم.

٥. حقوقك
- يمكنك حذف حسابك وكل بياناتك السحابية من الإعدادات > الحساب > حذف الحساب.
- يمكنك مسح بيانات الجهاز من الإعدادات.
- يمكنك استخدام التطبيق بدون حساب.

٦. التواصل
للاستفسار عن الخصوصية راسلنا على البريد الإلكتروني الموضّح في صفحة التطبيق على المتجر.
''';

const String _en = '''
Privacy policy

Last updated: 2026

1. What we collect
- Reading data: chapters you completed, notes, highlights, favorites, reading time, plan settings.
- If you sign in: your email, display name and account ID.
- If you join a group: your display name, chapters read, streak and progress percentage are visible to group members.

2. Where data lives
- Always on your device.
- In Google Firebase only if you sign in, to sync between your devices.

3. What we do not do
- We do not sell your data, show ads or track you.
- We do not read your notes for any other purpose.

4. Notifications
Reminders are scheduled locally on your device and need no server.

5. Your rights
- Delete your account and all cloud data in Settings > Account > Delete account.
- Erase on-device data in Settings.
- You can use the app without an account.

6. Contact
Use the contact email listed on the app's store page.
''';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('privacy'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          gEn ? _en : _ar,
          style: const TextStyle(height: 1.7, fontSize: 15),
        ),
      ),
    );
  }
}
