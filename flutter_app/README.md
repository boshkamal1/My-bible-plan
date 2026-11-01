# رحلة الكتاب المقدس (Flutter)

تطبيق Flutter: خطة قراءة مرنة، قارئ بنص فان دايك و KJV، استماع، ملاحظات وتمييز ومفضلة، بحث، إحصائيات وأوسمة، تذكيرات، ويدجت، مزامنة ومجموعات.

> الكود مكتوب بدون تشغيل Flutter عندي. شغّل `flutter analyze` وابعتلي أي أخطاء.
> المطلوب Flutter 3.27 أو أحدث.

## التشغيل لأول مرة

```bash
cd flutter_app
flutter create . --platforms=android,ios --org com.beshoy --project-name bible_journey
flutter pub get
bash android_snippets/setup_android.sh
```

بعدها ادمج `android_snippets/AndroidManifest_additions.xml` في `android/app/src/main/AndroidManifest.xml` و `build.gradle` (الأذونات، مستقبلات الإشعارات، الويدجت، desugaring).

## Firebase (المزامنة والمجموعات)

1. أنشئ مشروع في Firebase Console وفعّل Authentication (Google + Email/Password) و Firestore.
2. أضف تطبيق Android بنفس الـ package، نزّل `google-services.json` في `android/app/`.
3. أضف بصمة SHA-1 لتسجيل الدخول بجوجل.
4. طبّق plugin الـ google-services في Gradle (أو شغّل `flutterfire configure`).
5. انسخ محتوى `firestore.rules` في Rules.

بدون Firebase التطبيق يشتغل كامل محليًا، وأقسام الحساب والمجموعات تظهر برسالة أنها غير مفعّلة.

## النصوص

- فان دايك: `assets/bible/svd` (٦٦ سفر).
- KJV: `assets/bible/kjv` (كل الـ٧٦ سفر بما فيها القانونية الثانية).
- القانونية الثانية بدون نص عربي حاليًا فتظهر بالإنجليزية مع تنبيه. لإضافة نص عربي: ضع `assets/bible/ar_extra/<رقم السفر>.json` (قائمة أصحاحات، كل أصحاح قائمة آيات) وأضف الرقم في `_arExtra` داخل `lib/core/bible_repo.dart`.

## الويدجت

بعد `setup_android.sh` يظهر "BibleWidgetProvider" في قائمة ويدجت الجهاز.

## النشر

`flutter build appbundle --release` ثم رفع الملف في Google Play Console (حساب مطوّر ٢٥$ مرة واحدة). عدّل `applicationId` واسم التطبيق والأيقونة قبل النشر وأضف رابط سياسة الخصوصية.
