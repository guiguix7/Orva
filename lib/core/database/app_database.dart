import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Drift is used as the database connection/migration layer. The schema is
/// defined explicitly in SQL so migrations are reviewable and do not rely on
/// generated files being present in a fresh checkout.
final class AppDatabase extends GeneratedDatabase {
  AppDatabase()
      : super(
          driftDatabase(
            name: 'orva',
            web: DriftWebOptions(
              sqlite3Wasm: Uri.parse('sqlite3.wasm'),
              driftWorker: Uri.parse('drift_worker.js'),
            ),
          ),
        );

  /// Isolated in-memory executor for repository and migration tests.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  Iterable<TableInfo<Table, Object>> get allTables => const <TableInfo<Table, Object>>[];

  @override
  Iterable<DatabaseSchemaEntity> get allSchemaEntities => const <DatabaseSchemaEntity>[];

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (_) async {
          for (final statement in _schema) {
            await customStatement(statement);
          }
        },
        onUpgrade: (_, from, to) async {
          if (from < 2) {
            for (final statement in _routineTemplateSchema) {
              await customStatement(statement);
            }
          }
          if (from < 3) {
            for (final statement in _weightEntrySchema) {
              await customStatement(statement);
            }
          }
        },
        beforeOpen: (_) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static const List<String> _schema = [
    '''CREATE TABLE categories (
      id TEXT PRIMARY KEY NOT NULL,
      name TEXT NOT NULL COLLATE NOCASE,
      scope TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      UNIQUE(scope, name)
    )''',
    'CREATE INDEX categories_scope_idx ON categories(scope, name COLLATE NOCASE)',
    '''CREATE TABLE goals (
      id TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      period TEXT NOT NULL DEFAULT 'open',
      category TEXT,
      start_date TEXT,
      deadline TEXT,
      metric_name TEXT,
      target_value REAL,
      unit TEXT,
      progress_value REAL NOT NULL DEFAULT 0,
      progress_mode TEXT NOT NULL DEFAULT 'manual',
      parent_id TEXT REFERENCES goals(id) ON DELETE SET NULL DEFERRABLE INITIALLY DEFERRED,
      status TEXT NOT NULL DEFAULT 'active',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      CHECK(progress_value >= 0 AND progress_value <= 100)
    )''',
    'CREATE INDEX goals_status_idx ON goals(status, updated_at DESC)',
    '''CREATE TABLE goal_progress_history (
      id TEXT PRIMARY KEY NOT NULL,
      goal_id TEXT NOT NULL REFERENCES goals(id) ON DELETE RESTRICT,
      progress_value REAL NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      recorded_at TEXT NOT NULL
    )''',
    '''CREATE TABLE checklists (
      id TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      recurrence TEXT NOT NULL DEFAULT 'once',
      weekdays_json TEXT NOT NULL DEFAULT '[]',
      scheduled_date TEXT,
      start_date TEXT,
      end_date TEXT,
      is_template INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX checklists_active_idx ON checklists(is_active, recurrence)',
    '''CREATE TABLE checklist_items (
      id TEXT PRIMARY KEY NOT NULL,
      checklist_id TEXT NOT NULL REFERENCES checklists(id) ON DELETE RESTRICT,
      title TEXT NOT NULL,
      order_index INTEGER NOT NULL DEFAULT 0,
      goal_id TEXT REFERENCES goals(id) ON DELETE SET NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX checklist_items_checklist_idx ON checklist_items(checklist_id, is_active, order_index)',
    '''CREATE TABLE checklist_occurrences (
      id TEXT PRIMARY KEY NOT NULL,
      checklist_id TEXT NOT NULL REFERENCES checklists(id) ON DELETE RESTRICT,
      reference_date TEXT NOT NULL,
      created_at TEXT NOT NULL,
      UNIQUE(checklist_id, reference_date)
    )''',
    'CREATE INDEX checklist_occurrences_date_idx ON checklist_occurrences(reference_date)',
    '''CREATE TABLE checklist_occurrence_items (
      id TEXT PRIMARY KEY NOT NULL,
      occurrence_id TEXT NOT NULL REFERENCES checklist_occurrences(id) ON DELETE CASCADE,
      checklist_item_id TEXT REFERENCES checklist_items(id) ON DELETE SET NULL,
      title_snapshot TEXT NOT NULL,
      order_snapshot INTEGER NOT NULL DEFAULT 0,
      completed INTEGER NOT NULL DEFAULT 0,
      completed_at TEXT,
      UNIQUE(occurrence_id, checklist_item_id)
    )''',
    '''CREATE TABLE routine_blocks (
      id TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT '',
      start_minute INTEGER NOT NULL,
      end_minute INTEGER NOT NULL,
      block_kind TEXT NOT NULL DEFAULT 'weekday',
      weekday INTEGER,
      specific_date TEXT,
      template_name TEXT,
      goal_id TEXT REFERENCES goals(id) ON DELETE SET NULL,
      hobby_id TEXT REFERENCES hobbies(id) ON DELETE SET NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      CHECK(start_minute >= 0 AND start_minute < 1440),
      CHECK(end_minute > start_minute AND end_minute <= 1440)
    )''',
    'CREATE INDEX routine_blocks_weekday_idx ON routine_blocks(block_kind, weekday, start_minute)',
    'CREATE INDEX routine_blocks_date_idx ON routine_blocks(specific_date, start_minute)',
    '''CREATE TABLE hobbies (
      id TEXT PRIMARY KEY NOT NULL,
      name TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      category TEXT,
      weekly_target_minutes INTEGER,
      is_active INTEGER NOT NULL DEFAULT 1,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      CHECK(weekly_target_minutes IS NULL OR weekly_target_minutes >= 0)
    )''',
    'CREATE INDEX hobbies_active_idx ON hobbies(is_active, name)',
    '''CREATE TABLE hobby_sessions (
      id TEXT PRIMARY KEY NOT NULL,
      hobby_id TEXT NOT NULL REFERENCES hobbies(id) ON DELETE RESTRICT,
      session_date TEXT NOT NULL,
      duration_minutes INTEGER NOT NULL,
      start_minute INTEGER,
      end_minute INTEGER,
      note TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      CHECK(duration_minutes > 0),
      CHECK(start_minute IS NULL OR (start_minute >= 0 AND start_minute < 1440)),
      CHECK(end_minute IS NULL OR (end_minute >= 0 AND end_minute <= 1440))
    )''',
    'CREATE INDEX hobby_sessions_date_idx ON hobby_sessions(session_date DESC, hobby_id)',
    '''CREATE TABLE notes (
      id TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL DEFAULT '',
      content TEXT NOT NULL DEFAULT '',
      tags_json TEXT NOT NULL DEFAULT '[]',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX notes_updated_idx ON notes(updated_at DESC)',
    '''CREATE TABLE journal_entries (
      id TEXT PRIMARY KEY NOT NULL,
      entry_date TEXT NOT NULL UNIQUE,
      content TEXT NOT NULL DEFAULT '',
      mood TEXT,
      tags_json TEXT NOT NULL DEFAULT '[]',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX journal_entries_date_idx ON journal_entries(entry_date DESC)',
    '''CREATE TABLE settings (
      setting_key TEXT PRIMARY KEY NOT NULL,
      setting_value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    ..._routineTemplateSchema,
    ..._weightEntrySchema,
  ];

  /// Datado histórico de peso. Cada registro é um ponto no tempo; medições
  /// anteriores nunca são sobrescritas ao registrar um novo peso (ver
  /// OrvaRepository.saveWeightEntry).
  static const List<String> _weightEntrySchema = [
    '''CREATE TABLE weight_entries (
      id TEXT PRIMARY KEY NOT NULL,
      measured_at TEXT NOT NULL,
      weight_kg REAL NOT NULL,
      note TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      CHECK(weight_kg > 0)
    )''',
    'CREATE INDEX weight_entries_date_idx ON weight_entries(measured_at DESC)',
  ];

  static const List<String> _routineTemplateSchema = [
    '''CREATE TABLE routine_templates (
      id TEXT PRIMARY KEY NOT NULL,
      name TEXT NOT NULL COLLATE NOCASE UNIQUE,
      description TEXT NOT NULL DEFAULT '',
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )''',
    'CREATE INDEX routine_templates_name_idx ON routine_templates(name COLLATE NOCASE)',
    '''CREATE TABLE routine_template_blocks (
      id TEXT PRIMARY KEY NOT NULL,
      template_id TEXT NOT NULL REFERENCES routine_templates(id) ON DELETE CASCADE,
      title TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT '',
      start_minute INTEGER NOT NULL,
      end_minute INTEGER NOT NULL,
      weekday INTEGER NOT NULL,
      goal_id TEXT REFERENCES goals(id) ON DELETE SET NULL,
      hobby_id TEXT REFERENCES hobbies(id) ON DELETE SET NULL,
      order_index INTEGER NOT NULL DEFAULT 0,
      CHECK(start_minute >= 0 AND start_minute < 1440),
      CHECK(end_minute > start_minute AND end_minute <= 1440),
      CHECK(weekday >= 1 AND weekday <= 7)
    )''',
    'CREATE INDEX routine_template_blocks_idx ON routine_template_blocks(template_id, weekday, start_minute)',
  ];
}
