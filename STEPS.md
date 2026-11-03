# الخطوات الجاية

## ١. نص الأسفار القانونية الثانية
1. على جهازك: `pip install requests beautifulsoup4`
2. `python flutter_app/tools/fetch_takla_deut.py`
3. ارفع التغييرات على GitHub.
4. لو ظهرت تحذيرات ابعتهالي.

## ٢. تشغيل تطبيق Flutter
1. ثبّت Flutter (٣.٢٧ أو أحدث) و Android Studio.
2. من داخل `flutter_app`:
   `flutter create . --platforms=android,ios --org com.beshoy --project-name bible_journey`
3. `flutter pub get`
4. `bash android_snippets/setup_android.sh`
5. ادمج `android_snippets/AndroidManifest_additions.xml` في `AndroidManifest.xml` و `build.gradle`.
6. `flutter analyze` وابعتلي أي أخطاء.
7. `flutter run` على موبايل حقيقي.

## ٣. Firebase (للحساب والمزامنة والمجموعات)
1. أنشئ مشروع في Firebase Console.
2. Authentication: فعّل Google و Email/Password.
3. Firestore: أنشئ قاعدة بيانات وانسخ `flutter_app/firestore.rules` في Rules.
4. أندرويد: أضف تطبيق بنفس package، نزّل `google-services.json` في `android/app/`، وأضف بصمة SHA-1.
5. طبّق plugin الـ google-services في Gradle.
6. انشر القواعد: `firebase deploy --only firestore:rules`

## ٤. تجهيز النشر على Google Play
1. غيّر اسم التطبيق و `applicationId` والأيقونة.
2. انشر صفحة سياسة الخصوصية على رابط عام (ممكن صفحة على GitHub Pages).
3. أنشئ keystore للتوقيع واحتفظ به ولا تضيّعه.
4. `flutter build appbundle --release`

## ٥. Google Play Console
1. أنشئ حساب مطوّر (رسوم ٢٥$ مرة واحدة).
2. أنشئ التطبيق وارفع ملف `.aab`.
3. املأ بيانات المتجر ونموذج Data safety ورابط الخصوصية.
4. ابدأ باختبار مغلق. الحسابات الشخصية الجديدة بتحتاج عدد مختبرين لفترة قبل الإنتاج (راجع الشروط الحالية في Console).
5. بعد الموافقة اطلب النشر للإنتاج.
