import 'package:flutter/material.dart';

/// Global navigator access so background services (push notifications) can
/// route without a widget [BuildContext].
class NavigationService {
  NavigationService._();
  static final navigatorKey = GlobalKey<NavigatorState>();

  static NavigatorState? get nav => navigatorKey.currentState;
  static BuildContext? get context => navigatorKey.currentContext;
}
