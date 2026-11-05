import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/browser_back_stub.dart'
    if (dart.library.js_interop) '../services/browser_back_web.dart';

int tabFromUri(Uri uri) {
  final fragment =
      uri.fragment.startsWith('/') ? Uri.tryParse(uri.fragment) : null;
  final params = {...uri.queryParameters, ...?fragment?.queryParameters};
  final tab = int.tryParse(params['tab'] ?? '');
  if (tab != null && tab >= 0 && tab < 7) return tab;
  return params.containsKey('group') ? 5 : 0;
}

final ValueNotifier<int> currentTab = ValueNotifier<int>(tabFromUri(Uri.base));

class BrowserRouteHistory extends NavigatorObserver {
  bool handlingBrowserBack = false;
  int _pendingHistoryEvents = 0;
  int _sequence = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!kIsWeb || previousRoute == null) return;
    final base = Uri.base;
    final fragment =
        base.fragment.startsWith('/') ? Uri.tryParse(base.fragment) : null;
    final params = <String, String>{
      ...base.queryParameters,
      ...?fragment?.queryParameters
    };
    params['view'] = '${++_sequence}';
    SystemNavigator.routeInformationUpdated(
        uri: Uri(path: '/', queryParameters: params), replace: false);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!kIsWeb || previousRoute == null || handlingBrowserBack) return;
    _pendingHistoryEvents++;
    if (_pendingHistoryEvents == 1) browserHistoryBack();
  }

  bool consumeHistoryEvent() {
    if (_pendingHistoryEvents == 0) return false;
    _pendingHistoryEvents--;
    if (_pendingHistoryEvents > 0) browserHistoryBack();
    return true;
  }
}

final BrowserRouteHistory browserRouteHistory = BrowserRouteHistory();
