import 'dart:async';

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
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on UnsupportedError catch (error, stackTrace) {
      // Firebase is optional for the local-first experience. Some platforms,
      // including Web in this project, do not have generated Firebase options.
      OrvaDiagnostics.instance.recordException(
        error,
        stackTrace,
        category: 'firebase-configuration',
        module: 'startup',
        severity: DiagnosticSeverity.warning,
      );
    }
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
