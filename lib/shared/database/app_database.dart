// Drift database schema for Monyx.
//
// Drift requires code generation via `build_runner`.
// After running `flutter pub get`, execute:
//   dart run build_runner build --delete-conflicting-outputs
//
// This will generate `app_database.g.dart` alongside this file.
//
// The class definitions below define the full schema; the generated file
// provides the concrete implementations.

import 'dart:io';

/// Stub for drift import – will resolve after `flutter pub get`.
/// Replace the `// ignore` comments with real drift imports once deps land.

// import 'package:drift/drift.dart';
// import 'package:drift/native.dart';
// import 'package:drift_flutter/drift_flutter.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:path/path.dart' as path;

// part 'app_database.g.dart';

// ── Table definitions ─────────────────────────────────────────────────────────

// class PinsTable extends Table {
//   TextColumn get id => text()();
//   RealColumn get latitude => real()();
//   RealColumn get longitude => real()();
//   RealColumn get elevationMeters => real().nullable()();
//   TextColumn get label => text().nullable()();
//   TextColumn get notes => text().nullable()();
//   TextColumn get type => text().withDefault(const Constant('waypoint'))();
//   DateTimeColumn get createdAt => dateTime()();
//
//   @override
//   Set<Column> get primaryKey => {id};
// }

// class RifleProfilesTable extends Table {
//   TextColumn get id => text()();
//   TextColumn get name => text()();
//   TextColumn get caliber => text()();
//   // All profile fields are JSON-serialised for schema flexibility
//   TextColumn get profileJson => text()();
//   DateTimeColumn get createdAt => dateTime()();
//
//   @override
//   Set<Column> get primaryKey => {id};
// }

// class WeatherCacheTable extends Table {
//   // Grid-snapped lat/lon pair as key (e.g. "44.56,-110.48")
//   TextColumn get gridKey => text()();
//   TextColumn get dataJson => text()();
//   DateTimeColumn get fetchedAt => dateTime()();
//
//   @override
//   Set<Column> get primaryKey => {gridKey};
// }

// ── Database ──────────────────────────────────────────────────────────────────

// @DriftDatabase(tables: [PinsTable, RifleProfilesTable, WeatherCacheTable])
// class AppDatabase extends _$AppDatabase {
//   AppDatabase() : super(_openConnection());
//
//   @override
//   int get schemaVersion => 1;
//
//   static QueryExecutor _openConnection() {
//     return driftDatabase(name: 'monyx_db');
//   }
//
//   // ── Pins ──────────────────────────────────────────────────────────────────
//
//   Future<List<PinsTableData>> getAllPins() => select(pinsTable).get();
//
//   Future<void> upsertPin(PinsTableCompanion pin) =>
//       into(pinsTable).insertOnConflictUpdate(pin);
//
//   Future<int> deletePin(String id) =>
//       (delete(pinsTable)..where((t) => t.id.equals(id))).go();
//
//   // ── Rifle profiles ────────────────────────────────────────────────────────
//
//   Future<List<RifleProfilesTableData>> getAllProfiles() =>
//       select(rifleProfilesTable).get();
//
//   Future<void> upsertProfile(RifleProfilesTableCompanion profile) =>
//       into(rifleProfilesTable).insertOnConflictUpdate(profile);
//
//   Future<int> deleteProfile(String id) =>
//       (delete(rifleProfilesTable)..where((t) => t.id.equals(id))).go();
//
//   // ── Weather cache ─────────────────────────────────────────────────────────
//
//   Future<WeatherCacheTableData?> getCachedWeather(String gridKey) =>
//       (select(weatherCacheTable)
//           ..where((t) => t.gridKey.equals(gridKey)))
//           .getSingleOrNull();
//
//   Future<void> cacheWeather(WeatherCacheTableCompanion entry) =>
//       into(weatherCacheTable).insertOnConflictUpdate(entry);
// }

/// Placeholder until `build_runner` generates the real implementation.
class AppDatabase {
  AppDatabase._();

  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase._();

  /// Open the database.  No-op until drift is code-generated.
  Future<void> open() async {}

  /// Close the database.
  Future<void> close() async {}
}
