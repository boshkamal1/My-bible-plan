import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ui/route_observer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/i18n.dart';
import 'services/cloud.dart';
import 'services/notifications.dart';
import 'services/widget_sync.dart';
import 'state/app_state.dart';
import 'ui/root.dart';
import 'ui/tab_navigation.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final state = AppState(prefs)..load();
  final cloud = Cloud();
  if (!kIsWeb) await Notifier.init();
  state.afterChange = (s) {
    if (!kIsWeb) {
      Notifier.reschedule(s);
      WidgetSync.update(s);
    }
    if (cloud.signedIn) cloud.sync(s);
  };
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: state),
        ChangeNotifierProvider<Cloud>.value(value: cloud),
      ],
      child: const App(),
    ),
  );
  await cloud.init();
  if (cloud.signedIn) cloud.sync(state);
  if (!kIsWeb) {
    Notifier.reschedule(state);
    WidgetSync.update(state);
  }
}

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) SystemNavigator.selectMultiEntryHistory();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      final st = context.read<AppState>();
      st.refreshToday();
      final c = context.read<Cloud>();
      if (c.signedIn) c.sync(st);
    }
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation information) async {
    final uri = information.uri;
    if (kIsWeb && uri.path == '/') {
      if (browserRouteHistory.consumeHistoryEvent()) {
        return true;
      }
      final navigator = _navigatorKey.currentState;
      if (navigator?.canPop() ?? false) {
        browserRouteHistory.handlingBrowserBack = true;
        try {
          await navigator!.maybePop();
        } finally {
          browserRouteHistory.handlingBrowserBack = false;
        }
      }
      currentTab.value = tabFromUri(uri);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    gEn = s.en;
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [readerRouteObserver, browserRouteHistory],
      title: tr('appName'),
      debugShowCheckedModeBanner: false,
      locale: Locale(s.lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: s.flutterThemeMode,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const Root(),
    );
  }
}
