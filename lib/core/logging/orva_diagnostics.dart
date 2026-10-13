import 'package:flutter/foundation.dart';

enum DiagnosticSeverity { debug, info, warning, error, critical }

class OrvaDiagnosticEvent {
  const OrvaDiagnosticEvent({
    required this.id,
    required this.timestamp,
    required this.severity,
    required this.category,
    required this.module,
    required this.message,
    this.stackTrace,
  });

  final String id;
  final DateTime timestamp;
  final DiagnosticSeverity severity;
  final String category;
  final String module;
  final String message;
  final String? stackTrace;

  String toExportLine() {
    final head = '${timestamp.toIso8601String()} | ${severity.name.toUpperCase()} | $category | $module | $id';
    final details = message + (stackTrace == null ? '' : '\n$stackTrace');
    return head + '\n' + details;
  }
}

/// Development-only, in-memory diagnostics. Nothing is persisted or sent to
/// a remote service; exported content is sanitized before it leaves the app.
class OrvaDiagnostics extends ChangeNotifier {
  OrvaDiagnostics._();

  static final OrvaDiagnostics instance = OrvaDiagnostics._();
  static const int maxEvents = 500;

  final List<OrvaDiagnosticEvent> _events = <OrvaDiagnosticEvent>[];
  int _sequence = 0;

  static final RegExp _credentialPattern = RegExp(
    r'((?:access[_-]?token|refresh[_-]?token|id[_-]?token|authorization|password|passwd|pin|secret|api[_-]?key)\s*[:=]\s*)[^\s,;]+',
    caseSensitive: false,
  );
  static final RegExp _bearerPattern = RegExp(
    r'\bBearer\s+[A-Za-z0-9._~+/-]+=*',
    caseSensitive: false,
  );
  static final RegExp _emailPattern = RegExp(
    r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
    caseSensitive: false,
  );

  List<OrvaDiagnosticEvent> get events =>
      List<OrvaDiagnosticEvent>.unmodifiable(_events.reversed);

  void record({
    required DiagnosticSeverity severity,
    required String category,
    required String module,
    required String message,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;

    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString() + '-' + (++_sequence).toString();
    _events.add(OrvaDiagnosticEvent(
      id: id,
      timestamp: now,
      severity: severity,
      category: sanitize(category),
      module: sanitize(module),
      message: sanitize(message),
      stackTrace: stackTrace == null ? null : sanitize(stackTrace.toString()),
    ));
    if (_events.length > maxEvents) {
      _events.removeRange(0, _events.length - maxEvents);
    }
    notifyListeners();
  }

  void recordException(
    Object error,
    StackTrace? stackTrace, {
    String category = 'uncaught',
    String module = 'app',
    DiagnosticSeverity severity = DiagnosticSeverity.error,
  }) {
    record(
      severity: severity,
      category: category,
      module: module,
      message: error.runtimeType.toString() + ': ' + error.toString(),
      stackTrace: stackTrace,
    );
  }

  void clear() {
    if (!kDebugMode) return;
    _events.clear();
    notifyListeners();
  }

  String exportText() => events.map((event) => event.toExportLine()).join('\n\n');

  static String sanitize(String value) {
    var sanitized = value.replaceAllMapped(
      _credentialPattern,
      (match) => (match.group(1) ?? '') + '[redigido]',
    );
    sanitized = sanitized.replaceAll(_bearerPattern, 'Bearer [redigido]');
    sanitized = sanitized.replaceAll(_emailPattern, '[e-mail]');
    if (sanitized.length > 4000) {
      sanitized = sanitized.substring(0, 4000) + '…';
    }
    return sanitized;
  }
}
