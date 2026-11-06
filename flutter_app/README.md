# كود رحلة الكتاب المقدس 📖

ده مجلد تطبيق Flutter اللي بيشغّل الموقع. الشرح الكامل والمميزات والترجمات والمشاكل اللي لسه محتاجة إصلاح موجودين في [الـREADME الرئيسي](../README.md).

## تشغّله من هنا

```powershell
flutter pub get
node tools/split_chapters.cjs
flutter run -d chrome
```

اتجرب على Flutter 3.41.6، وهتحتاج Node.js لتوليد ملفات الأصحاحات. ملفات المنصات موجودة بالفعل، فمتشغّلش `flutter create` فوقها.

## تختبره

```powershell
flutter analyze --no-fatal-infos
flutter test
node --test tools/bootstrap_test.cjs tools/backup_download_test.cjs tools/split_chapters_test.cjs tools/sw_test.cjs tools/import_web_test.cjs tools/import_gna_test.cjs
```

## تبني نسخة الويب

```powershell
pwsh -File tools/build_web.ps1
```

السكربت بيجهز ملفات الأصحاحات الصغيرة وبعدين بيعمل Release build. خطوات النشر والـBackup موجودة في [الشرح الرئيسي](../README.md).

الاختيارات الحالية: فان دايك + يسوعية، المشتركة 2025 مع المكملات الموضحة المصدر، KJV وWEB. اليسوعية القديمة مش اختيار مستقل؛ نصوصها بتكمل القانونية الثانية. صلاة منسى والمزمور 151 موجودين في النصوص المخزنة.

مصادر النصوص والتراخيص في [SOURCES.md](assets/bible/SOURCES.md). ونتيجة مراجعة الحسابات والمزامنة وباقي الموقع في [تقرير المراجعة](../REVIEW-20261105.md).


تحديث الأمان والأداء: شوف [خطة الإصلاح](../SECURITY-FIX-PLAN.md) و[استرجاع البيانات](../DATA-RECOVERY.md). البناء الحالي بيستخدم `flutter build web --wasm --release` ومعاه بديل JavaScript تلقائي.
