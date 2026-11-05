import 'package:bible_journey/core/day_util.dart';
import 'package:bible_journey/core/i18n.dart';
import 'package:bible_journey/core/planner.dart';
import 'package:bible_journey/services/cloud.dart';
import 'package:bible_journey/state/app_state.dart';
import 'package:bible_journey/ui/root.dart';
import 'package:bible_journey/ui/daily_verse_card.dart';
import 'package:bible_journey/ui/daily_reminder_card.dart';
import 'package:bible_journey/core/books.dart';
import 'package:bible_journey/ui/reader_screen.dart';
import 'package:bible_journey/ui/route_observer.dart';
import 'package:bible_journey/ui/setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppState> setupState() async {
    SharedPreferences.setMockInitialValues({});
    return AppState(await SharedPreferences.getInstance())..load();
  }

  Widget app(AppState state, Widget home) => MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: state),
          ChangeNotifierProvider<Cloud>(create: (_) => Cloud()),
        ],
        child: MaterialApp(
          navigatorObservers: [readerRouteObserver],
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate
          ],
          home: home,
        ),
      );

  testWidgets('daily verse shows share action after loading', (tester) async {
    final state = await setupState();
    gEn = false;
    await tester.runAsync(() async {
      final verse = DailyVerseCard.verseForState(state);
      final chapter =
          await state.repo.chapter(verse.$1, verse.$2, state.translation);
      expect(chapter, isNotNull);
    });
    await tester.pumpWidget(app(
        state,
        Scaffold(
          body: SingleChildScrollView(child: DailyVerseCard(state: state)),
        )));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text('مشاركة الآية'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  test('encouragement prefers readings and avoids yesterday', () {
    expect(DailyVerseCard.chooseVerse(1, [const Chap(20, 23)]), (20, 23, 1));
    expect(
        DailyVerseCard.chooseVerse(2, [const Chap(20, 23)],
            previous: (20, 23, 1)),
        isNot((20, 23, 1)));
    expect(DailyVerseCard.chooseVerse(1, []),
        isNot(DailyVerseCard.chooseVerse(2, [])));
  });

  test('daily verse remains stable and advances the next day', () async {
    final state = await setupState();
    final first = DailyVerseCard.verseForState(state);
    expect(DailyVerseCard.verseForState(state), first);
    state.today++;
    expect(DailyVerseCard.verseForState(state), isNot(first));
    state.dispose();
  });

  test('read now resumes the earliest unread plan chapter', () async {
    final state = await setupState();
    state.days = [
      [const Chap(0, 1), const Chap(0, 2)],
      [const Chap(0, 3)]
    ];
    state.done['0:1'] = dayStr(state.today - 1);
    expect(DailyReminderCard.nextReadings(state).first.key, '0:2');
    state.done['0:2'] = dayStr(state.today);
    expect(DailyReminderCard.nextReadings(state).first.key, '0:3');
    state.done['0:3'] = dayStr(state.today);
    expect(DailyReminderCard.nextReadings(state), isEmpty);
    state.dispose();
  });

  testWidgets(
      'daily reminder responds to reading and cancellation on a small screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    gEn = false;
    final state = await setupState();
    await tester.pumpWidget(app(state, const Root()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ابدأ سلسلة قراءتك النهاردة'), findsOneWidget);
    expect(find.text(tr('groups')), findsOneWidget);
    expect(find.text(tr('settings')), findsOneWidget);
    state.toggleChapter('0:1');
    await tester.pump();
    expect(find.text('ابدأ سلسلة قراءتك النهاردة'), findsNothing);
    expect(state.streak.readToday, isTrue);
    state.toggleChapter('0:1');
    await tester.pump();
    expect(find.text('ابدأ سلسلة قراءتك النهاردة'), findsOneWidget);
    expect(state.streak.readToday, isFalse);
    expect(state.readDates.contains(dayStr(state.today)), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  testWidgets(
      'duration accepts Arabic numerals and rejects values outside range',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    gEn = false;
    final state = await setupState();
    await tester.pumpWidget(app(state, const SetupScreen()));
    await tester.pump();
    final input = find.byType(TextField).first;
    await tester.enterText(input, '٢٩');
    await tester.pump();
    expect(find.text('اختار مدة من 30 إلى 730 يوم'), findsOneWidget);
    await tester.enterText(input, '٣٦٥');
    await tester.pump();
    expect(find.text('اختار مدة من 30 إلى 730 يوم'), findsNothing);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 365);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });

  test('streak requires a reading on each consecutive day', () async {
    final state = await setupState();
    state.today = dayNum(2026, 11, 4);
    state.done = {'0:1': '2026-11-02', '0:2': '2026-11-03'};
    expect(state.streak.cur, 2);
    state.delays = ['2026-11-03'];
    state.done.remove('0:2');
    expect(state.streak.cur, 0);
    state.dispose();
  });

  test('earned badges retain their real date after undo and a new journey',
      () async {
    final state = await setupState();
    state.toggleChapter('0:1');
    expect(state.badgeDates['first'], dayStr(state.today));
    state.toggleChapter('0:1');
    expect(state.badges.first.earned, isTrue);
    final start = dayStr(todayNum());
    state.newJourney(Setup(scope: 'ot', days: 100, start: start, first: start));
    expect(state.badges.first.earned, isTrue);
    expect(state.badgeDates['first'], start);
    state.dispose();
  });

  testWidgets('progress tiles and activity details fit mobile and desktop',
      (tester) async {
    final state = await setupState();
    for (final size in [const Size(360, 800), const Size(1100, 800)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      gEn = false;
      await tester.pumpWidget(app(state, const Root()));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text(tr('stats')).last);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('إنجازاتك وسلسلة القراءة'), findsOneWidget);
      expect(find.text('لا توجد خطة'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    state.dispose();
  });

  testWidgets('reading time stops while another route covers the reader',
      (tester) async {
    final state = await setupState();
    await tester.pumpWidget(app(state, const ReaderScreen(b: 0, c: 1)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1200)));
    final navigator = Navigator.of(tester.element(find.byType(ReaderScreen)));
    navigator.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('covered'))));
    await tester.pump(const Duration(milliseconds: 400));
    final recorded = state.secs.values.fold<int>(0, (a, b) => a + b);
    expect(recorded, greaterThanOrEqualTo(1));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1200)));
    navigator.pop();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(state.secs.values.fold<int>(0, (a, b) => a + b), recorded);
    state.dispose();
  });

  testWidgets('book group toggles all its books and exclusion stays separate',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = await setupState();
    gEn = false;
    await tester.pumpWidget(app(state, const SetupScreen()));
    final picker = find.descendant(of: find.byType(ExpansionTile), matching: find.text('هتقرا إيه؟')).first;
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    final group =
        find.widgetWithText(CheckboxListTile, tr('bookGroup_moses')).first;
    await tester.ensureVisible(group);
    await tester.tap(group);
    await tester.pumpAndSettle();
    final genesis = find.widgetWithText(CheckboxListTile, kArNames[0]).first;
    expect(tester.widget<CheckboxListTile>(genesis).value, false);
    await tester.tap(group);
    await tester.pumpAndSettle();
    expect(tester.widget<CheckboxListTile>(genesis).value, true);
    expect(find.text(tr('skipBooks')), findsWidgets);
  });

  testWidgets('advanced drag order is used by the created journey', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = await setupState();
    gEn = false;
    final start = dayStr(todayNum());
    await tester.pumpWidget(app(state, SetupScreen(initial: Setup(
      start: start, first: start, selectedBooks: const [0, 1, 2]))));
    await tester.tap(find.text('Advanced: ترتيب الأسفار'));
    await tester.pumpAndSettle();
    final handles = find.byType(ReorderableDragStartListener);
    await tester.drag(handles.first, const Offset(0, 115));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(tr('start')));
    await tester.pumpAndSettle();
    expect(state.setup!.bookOrder, isNot([0, 1, 2]));
    expect(state.plan!.base.expand((d) => d).first.b, state.setup!.bookOrder.first);
    expect(state.plan!.nDays, 93);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
