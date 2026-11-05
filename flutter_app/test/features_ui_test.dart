import 'dart:io';
import 'dart:convert';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:bible_journey/ui/backup_screen.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bible_journey/core/i18n.dart';
import 'package:bible_journey/services/cloud.dart';
import 'package:bible_journey/state/app_state.dart';
import 'package:bible_journey/ui/comparison_screen.dart';
import 'package:bible_journey/ui/reader_screen.dart';
import 'package:bible_journey/ui/root.dart';
import 'package:bible_journey/ui/stats_screen.dart';
import 'package:bible_journey/ui/settings_screen.dart';
import 'package:bible_journey/ui/daily_verse_card.dart';
import 'package:bible_journey/ui/tab_navigation.dart';
import 'package:bible_journey/ui/theme.dart';

class _BackupPicker extends FileSelectorPlatform {
  _BackupPicker(this.contents);
  final String contents;
  @override
  Future<XFile?> openFile(
          {List<XTypeGroup>? acceptedTypeGroups,
          String? initialDirectory,
          String? confirmButtonText}) async =>
      XFile.fromData(utf8.encode(contents),
          name: 'backup.json', mimeType: 'application/json');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppState state;
  final captureKey = GlobalKey();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    state = AppState(await SharedPreferences.getInstance())..load();
    gEn = false;
    currentTab.value = 0;
    final fontFile = File(r'C:\Windows\Fonts\segoeui.ttf');
    if (fontFile.existsSync()) {
      await (FontLoader('TestUI')
            ..addFont(
                Future.value(ByteData.sublistView(fontFile.readAsBytesSync()))))
          .load();
    }
    final icons = File('build/web/assets/fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')
            ..addFont(
                Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
          .load();
    }
  });
  tearDown(() => state.dispose());

  Widget app(Widget home) => MultiProvider(
          providers: [
            ChangeNotifierProvider<AppState>.value(value: state),
            ChangeNotifierProvider<Cloud>(create: (_) => Cloud()),
          ],
          child: RepaintBoundary(
              key: captureKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildTheme(Brightness.light).copyWith(
                    textTheme: buildTheme(Brightness.light)
                        .textTheme
                        .apply(fontFamily: 'TestUI'),
                    primaryTextTheme: buildTheme(Brightness.light)
                        .primaryTextTheme
                        .apply(fontFamily: 'TestUI')),
                locale: const Locale('ar'),
                supportedLocales: const [Locale('ar'), Locale('en')],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate
                ],
                home: home,
              )));

  Future<void> settle(WidgetTester tester) async {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Arabic and English comparison fits narrow mobile and switches only English',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      for (final tr in ['svd', 'web', 'kjv']) {
        await state.repo.chapter(0, 1, tr);
      }
      await state.repo.chapter(0, 2, 'kjv');
    });
    await tester.pumpWidget(app(const ComparisonScreen(b: 0, c: 1)));
    await settle(tester);
    expect(find.byType(ListView), findsOneWidget);
    final enFirst = find.byKey(const ValueKey('comparison-left-1'));
    final arFirst = find.byKey(const ValueKey('comparison-right-1'));
    final enY = tester.getTopLeft(enFirst).dy;
    final arY = tester.getTopLeft(arFirst).dy;
    await tester.drag(enFirst, const Offset(0, -100));
    await settle(tester);
    final enMoved = tester.getTopLeft(enFirst).dy - enY;
    final arMoved = tester.getTopLeft(arFirst).dy - arY;
    expect(enMoved, lessThan(-50));
    expect(arMoved, closeTo(enMoved, 0.1));
    final beforeRightDrag = tester.getTopLeft(enFirst).dy;
    final bounds =
        tester.getRect(find.byKey(const ValueKey('comparison-scroll')));
    await tester.dragFrom(
        Offset(bounds.right - 40, bounds.center.dy), const Offset(0, -60));
    await settle(tester);
    expect(tester.getTopLeft(enFirst).dy, lessThan(beforeRightDrag - 20));
    expect(tester.getTopLeft(enFirst).dy - enY,
        closeTo(tester.getTopLeft(arFirst).dy - arY, 0.1));
    final texts = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((w) => w.data!)
        .toList();
    expect(texts.any((s) => s.contains('In the beginning')), true);
    expect(texts.any((s) => RegExp(r'[\u0600-\u06ff]').hasMatch(s)), true);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image = await (captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('test_artifacts/comparison-mobile.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.byKey(const ValueKey('comparison-left-translation')));
    await settle(tester);
    await tester.tap(find.text('KJV').last);
    await settle(tester);
    expect(
        tester
            .widget<DropdownButton<String>>(
                find.byKey(const ValueKey('comparison-left-translation')))
            .value,
        'kjv');
    await tester.tap(find.byKey(const ValueKey('comparison-left-chapter')));
    await settle(tester);
    await tester.tap(find.text('Chapter 2').last);
    await settle(tester);
    expect(
        tester
            .widget<DropdownButton<int>>(
                find.byKey(const ValueKey('comparison-right-chapter')))
            .value,
        1);
    expect(
        tester
            .widget<DropdownButton<int>>(
                find.byKey(const ValueKey('comparison-left-chapter')))
            .value,
        2);
    tester.view.physicalSize = const Size(320, 700);
    await settle(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'normal reader builds visible verses and navigates to the next chapter',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await state.repo.chapter(20, 119, 'svd');
    });
    await tester.pumpWidget(app(const ReaderScreen(b: 20, c: 119)));
    await settle(tester);
    final built = find
        .byWidgetPredicate((w) => w is InkWell && w.key is GlobalKey)
        .evaluate()
        .length;
    expect(built, greaterThan(0));
    expect(built, lessThan(30),
        reason:
            'Psalm 119 has 176 verses; offscreen verses should stay unbuilt');
    print('Psalm 119 initially built verse widgets: $built / 176');
    await tester.tap(find.byIcon(Icons.chevron_right));
    await settle(tester);
    expect(find.textContaining('120'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('only the selected main tab is mounted', (tester) async {
    await tester.runAsync(() async {
      final v = DailyVerseCard.verseForState(state);
      await state.repo.chapter(v.$1, v.$2, state.translation);
    });
    await tester.pumpWidget(app(const Root()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(StatsScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsNothing);
    await tester.tap(find.text(tr('stats')));
    await settle(tester);
    expect(find.byType(StatsScreen), findsOneWidget);
    await tester.tap(find.text(tr('settings')).last);
    await settle(tester);
    expect(find.byType(StatsScreen), findsNothing);
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    currentTab.value = 0;
  });

  testWidgets(
      'restore previews data, cancellation keeps current notes, confirmation restores',
      (tester) async {
    final selector = FileSelectorPlatform.instance;
    addTearDown(() => FileSelectorPlatform.instance = selector);
    state.notes['0:1:1'] = 'From backup';
    FileSelectorPlatform.instance = _BackupPicker(state.exportBackup());
    state.notes['0:1:1'] = 'Current note';
    await tester.pumpWidget(app(const BackupScreen()));
    await tester.tap(find.text('استرجاع من ملف'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('استرجاع النسخة دي؟'), findsOneWidget);
    expect(state.notes['0:1:1'], 'Current note');
    await tester.tap(find.text(tr('cancel')));
    await settle(tester);
    expect(state.notes['0:1:1'], 'Current note');
    await tester.tap(find.text('استرجاع من ملف'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('استرجاع'));
    await settle(tester);
    expect(state.notes['0:1:1'], 'From backup');
    expect(find.text('تم استرجاع بياناتك.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
      'comparison accepts any translation on either side, including matching languages',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      for (final tr in ['svd', 'gna', 'kjv', 'web']) {
        await state.repo.chapter(0, 1, tr);
      }
    });
    await tester.pumpWidget(app(const ComparisonScreen(b: 0, c: 1)));
    await settle(tester);
    Future<void> choose(String side, String id) async {
      await tester.tap(find.byKey(ValueKey('comparison-$side-translation')));
      await settle(tester);
      await tester.tap(find.text(tr(id)).last);
      await settle(tester);
    }

    String text(String side) => tester
        .widget<SelectableText>(find.byKey(ValueKey('comparison-$side-1')))
        .data!;
    final arabic = RegExp(r'[\u0600-\u06ff]');
    await choose('left', 'gna');
    expect(arabic.hasMatch(text('left')), true);
    expect(arabic.hasMatch(text('right')), true);
    expect(text('left'), isNot(text('right')));
    await tester.runAsync(() async {
      final image = await (captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 2);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('test_artifacts/comparison-arabic-mobile.png')
          .writeAsBytes(png!.buffer.asUint8List());
      image.dispose();
    });

    tester.view.physicalSize = const Size(320, 700);
    await settle(tester);
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(360, 800);
    await settle(tester);

    await choose('right', 'kjv');
    await choose('left', 'web');
    expect(text('left'), contains('In the beginning'));
    expect(text('right'), contains('In the beginning'));
    await choose('right', 'gna');
    await choose('left', 'svd');
    expect(arabic.hasMatch(text('left')), true);
    expect(arabic.hasMatch(text('right')), true);
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
