import 'i18n.dart';
import 'books.dart';

const kTranslationIds = ['svd', 'gna', 'jesuit', 'kjv', 'web'];
bool isArabicTranslation(String id) =>
    const {'svd', 'gna', 'jesuit'}.contains(id);

bool translationHasBook(String id, int book) =>
    id != 'jesuit' || kDeut.contains(book) || book == kPsalms;

final storedJesuitChapters = <Chap>[
  for (var b = 0; b < kBookCount; b++)
    if (kDeut.contains(b)) ...[
      for (var c = 1; c <= kChapters[b]; c++) Chap(b, c),
    ] else if (b == kPsalms)
      const Chap(kPsalms, 151),
];

/// Storage keys remain plan-compatible; citations use the edition's own numbers.
({int chapter, int verse}) sourceVerseReference(
    int book, int chapter, int verse, String id) {
  if (id == 'gna') {
    if (book == 33 && chapter == 2 && verse > 27)
      return (chapter: 3, verse: verse - 27);
    if (book == 33 && chapter == 3) return (chapter: 4, verse: verse);
    if (book == 43 && chapter == 4) return (chapter: 3, verse: verse + 18);
  }
  return (chapter: displayChapterNumber(book, chapter, id), verse: verse);
}

String editionVerseLabel(int book, int chapter, int verse, String id) {
  final ref = sourceVerseReference(book, chapter, verse, id);
  return ref.chapter == displayChapterNumber(book, chapter, id)
      ? nf(ref.verse)
      : bibleReference('', ref.chapter, ref.verse).trim();
}

String? translationSourceNote(String requested, String? source, int book) {
  if (source == 'manasseh-ar') {
    return gEn
        ? 'Prayer of Manasseh: the previously saved Arabic liturgical text, not a text of the selected edition.'
        : 'صلاة منسى: النص العربي الطقسي المحفوظ سابقًا، وليس نصًا من الترجمة المختارة.';
  }
  if (source == 'psalm151-ar' && requested != 'svd') {
    return gEn
        ? 'Psalm 151: the previously saved Arabic text; not attributed to the selected edition.'
        : 'المزمور 151: النص العربي المحفوظ سابقًا، ولا يُنسب للترجمة المختارة.';
  }
  if (requested == 'gna' && source == 'jesuit-old') {
    return gEn
        ? 'Supplement: old Jesuit text (1877), not the Good News Arabic text.'
        : 'نص مكمل من اليسوعية القديمة 1877، وليس من الترجمة العربية المشتركة.';
  }
  if (requested == 'gna' && (book == 33 || book == 43)) {
    return gEn
        ? 'GNA verse wording is unchanged. Joel and Malachi follow this app’s plan chapter divisions; the source edition divides them differently.'
        : 'نص المشتركة كما هو دون تغيير الكلمات. تقسيم يوئيل وملاخي هنا متوافق مع الخطة؛ تقسيم الأصحاحات في الطبعة الأصلية مختلف.';
  }
  return null;
}

String translationUnavailable(String id) => id == 'jesuit'
    ? (gEn
        ? 'The old Jesuit text currently available here covers the Deuterocanonical books. It is not available for this book; choose another translation.'
        : 'النص اليسوعي القديم المتاح هنا يغطي الأسفار القانونية الثانية. السفر ده غير متاح منه؛ اختار ترجمة أخرى.')
    : (gEn
        ? 'Chapter unavailable in this translation.'
        : 'الأصحاح غير متاح في الترجمة دي.');

String get gnaAttribution => gEn
    ? 'Good News Arabic 2025 • Bible Society in Lebanon • CC BY-NC-ND 4.0'
    : 'المشتركة 2025 • دار الكتاب المقدس في لبنان • CC BY-NC-ND 4.0';
