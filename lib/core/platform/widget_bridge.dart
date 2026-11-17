import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/widget_snapshot.dart';

/// Thin transport between Flutter and the native Android widget providers.
///
/// The native side only stores and renders a sanitized snapshot; it never
/// opens Drift or computes progress. On non-Android platforms every call is a
/// no-op so the rest of the app stays platform independent.
abstract final class OrvaWidgetBridge {
  static const _channel = MethodChannel('com.appguilherme.orva/widgets');
  static final _routes = StreamController<String>.broadcast();
  static bool _initialized = false;

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Stream<String> get routes => _routes.stream;

  /// Installs the native callback once. Safe to call repeatedly.
  static void initialize() {
    if (!isSupported || _initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openRoute') {
        final route = call.arguments;
        if (route is String && route.isNotEmpty) _routes.add(route);
      }
      return null;
    });
  }

  /// Route requested by the intent that launched the app, if any. Consumed once.
  static Future<String?> consumeInitialRoute() async {
    if (!isSupported) return null;
    try {
      return await _channel.invokeMethod<String>('consumeInitialRoute');
    } on PlatformException catch (error) {
      debugPrint('Widget route unavailable: ${error.code}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Replaces the shared snapshot and asks every placed widget to redraw.
  static Future<void> saveSnapshot(WidgetSnapshot snapshot) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>('saveSnapshot', {
        'json': jsonEncode(snapshot.toJson()),
      });
    } on PlatformException catch (error) {
      debugPrint('Widget snapshot failed: ${error.code}');
    } on MissingPluginException {
      // Widgets are optional on builds without the native channel (e.g. tests).
    }
  }
}
