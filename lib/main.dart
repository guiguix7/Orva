import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  Intl.defaultLocale = 'pt_BR';

  // Firebase is optional for the current local-first feature set. Android has
  // explicit options; iOS/Web must remain usable offline until their owner
  // supplies platform-specific configuration. An external setup error should
  // not make local notes, goals, checklists or diary inaccessible.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on UnsupportedError {
    // DefaultFirebaseOptions intentionally has no iOS/Web configuration yet.
  } catch (_) {
    // Keep local-only functionality available if optional Firebase setup fails.
    // Auth/calendar features must separately report their own configuration
    // state before making external requests.
  }

  runApp(const ProviderScope(child: OrvaApp()));
}
