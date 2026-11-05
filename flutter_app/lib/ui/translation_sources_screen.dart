import 'package:flutter/material.dart';
import '../core/i18n.dart';
import '../core/translations.dart';

class TranslationSourcesScreen extends StatelessWidget {
  const TranslationSourcesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: Text(gEn ? 'Translation sources' : 'مصادر الترجمات')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(tr('svd'), style: Theme.of(context).textTheme.titleMedium),
          Text(gEn
              ? 'Van Dyck for the main books, with old Jesuit text (1877) for the Deuterocanonical books.'
              : 'فان دايك للأسفار الأساسية، ومعه نص اليسوعية القديمة 1877 للأسفار القانونية الثانية.'),
          const SelectableText('https://st-takla.org/Holy-Bible_.html'),
          const Divider(height: 28),
          Text(tr('gna'), style: Theme.of(context).textTheme.titleMedium),
          Text(gnaAttribution),
          Text(gEn
              ? 'This available GNA2025 edition contains 66 books. Missing Deuterocanonical books use the separately identified old Jesuit text. Verse wording is unchanged. Joel and Malachi use plan-compatible chapter divisions; the original edition has four and three chapters respectively.'
              : 'الإصدار المتاح من المشتركة 2025 يضم 66 سفرًا. الأسفار القانونية الثانية الناقصة تُعرض من اليسوعية القديمة مع بيان المصدر. كلمات الآيات دون تعديل. يوئيل وملاخي بتقسيم أصحاحات متوافق مع الخطة؛ الطبعة الأصلية فيهما 4 و3 أصحاحات على الترتيب.'),
          const SelectableText(
              'Bible Society in Lebanon\nhttps://creativecommons.org/licenses/by-nc-nd/4.0/\nhttps://app.library.bible/content/fd5704b4b8ddef79\nhttps://bible.helloao.org/api/arb_gna/complete.simple.json'),
          Text(gEn
              ? 'Licensed for non-commercial use, with attribution and no changes to the translation wording.'
              : 'الترخيص للاستخدام غير التجاري مع نسب النص إلى مصدره وعدم تعديل نص الترجمة.'),
          const Divider(height: 28),
          Text(
              gEn
                  ? 'Deuterocanonical supplements'
                  : 'مكملات الأسفار القانونية الثانية',
              style: Theme.of(context).textTheme.titleMedium),
          Text(gEn
              ? 'The stored old Jesuit texts supply the Deuterocanonical books in the combined Van Dyck edition and the missing GNA supplements. This partial text is not offered as a separate translation.'
              : 'نصوص اليسوعية القديمة المحفوظة بتكمّل الأسفار القانونية الثانية مع فان دايك، والناقص من المشتركة. النص الجزئي ده مش موجود كاختيار ترجمة لوحده.'),
          const SelectableText(
              'https://st-takla.org/pub_Deuterocanon/Deuterocanon-Apocrypha_El-Asfar_El-Kanoneya_El-Tanya__0-index_.html'),
          const Divider(height: 28),
          Text(
              gEn
                  ? 'Prayer of Manasseh and Psalm 151'
                  : 'صلاة منسى والمزمور 151',
              style: Theme.of(context).textTheme.titleMedium),
          Text(gEn
              ? 'Missing texts use the previously saved Arabic copies and are identified as supplements. Prayer of Manasseh is the Coptic liturgical text, not attributed to Jesuit or GNA.'
              : 'عند عدم توفرهما تُستخدم النسخ العربية القديمة المحفوظة ويظهر بيان بأنها مكملات. صلاة منسى هي النص الطقسي القبطي، ولا تُنسب إلى المشتركة أو اليسوعية.'),
          const SelectableText(
              'https://st-takla.org/lyrics/ar/liturgy/holy-pascha/483.html'),
          const Divider(height: 28),
          Text('WEB / KJV', style: Theme.of(context).textTheme.titleMedium),
          Text(gEn
              ? 'Existing English texts with Deuterocanonical supplements. Edition and verse-numbering differences remain visible.'
              : 'النصوص الإنجليزية الموجودة مع مكملاتها القانونية الثانية، مع مراعاة اختلاف ترقيم الطبعات.'),
          const SelectableText(
              'https://ebible.org/find/details.php?id=eng-web'),
        ]),
      );
}
