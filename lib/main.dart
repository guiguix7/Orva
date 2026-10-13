import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'core/logging/orva_diagnostics.dart';
import 'firebase_options.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      if (kDebugMode) FlutterError.presentError(details);
      OrvaDiagnostics.instance.recordException(
        details.exception,
        details.stack ?? StackTrace.current,
        category: 'flutter',
        module: 'framework',
      );
    };

    PlatformDispatcher.instance.onError = (error, stackTrace) {
      OrvaDiagnostics.instance.recordException(
        error,
        stackTrace,
        category: 'async',
        module: 'platform',
        severity: DiagnosticSeverity.critical,
      );
      // Only swallow the error in debug builds where it has been captured by
      // the in-app console. Production retains the default platform handling.
      return kDebugMode;
    };

    await initializeDateFormatting('pt_BR');
    Intl.defaultLocale = 'pt_BR';
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const ProviderScope(child: OrvaApp()));
  }, (error, stackTrace) {
    OrvaDiagnostics.instance.recordException(
      error,
      stackTrace,
      category: 'zone',
      module: 'dart',
      severity: DiagnosticSeverity.critical,
    );
  });
}
