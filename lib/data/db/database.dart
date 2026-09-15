import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'card_cache_dao.dart';
import 'collection_dao.dart';

part 'database.g.dart';

/// Raw TCGdex card JSON, keyed by card id. `fetchedAt` drives the 7-day TTL.
///
/// The previous response is kept alongside so a price move can be shown
/// without a separate history table. One step back is all the badge needs,
/// and it keeps the cache a single row per card.
class CardsCache extends Table {
  TextColumn get id => text()();
  TextColumn get json => text()();
  IntColumn get fetchedAt => integer()();

  /// The response this row replaced, or null if it has only been fetched once.
  TextColumn get previousJson => text().nullable()();
  IntColumn get previousFetchedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per (card, variant, condition, language) the user owns.
class CollectionItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get cardId => text().references(CardsCache, #id)();
  TextColumn get variant => text()(); // normal | holo | reverse | firstEdition | wPromo
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  TextColumn get condition => text().withDefault(const Constant('NM'))(); // NM LP MP HP DMG
  TextColumn get language => text().withDefault(const Constant('en'))();
  TextColumn get scanPath => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get acquiredAt => integer().nullable()();
  RealColumn get pricePaid => real().nullable()();
  IntColumn get addedAt => integer()();
}

@DriftDatabase(tables: [CardsCache, CollectionItems], daos: [CardCacheDao, CollectionDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Production database. Native: app documents dir. Web: sqlite3 wasm with
  /// OPFS or IndexedDB persistence (assets in `web/`).
  AppDatabase.open()
      : super(driftDatabase(
          name: 'pokescan',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ));

  // Tests build `AppDatabase(NativeDatabase.memory())` themselves; importing
  // drift/native.dart here would pull dart:ffi into the web build.

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Existing rows get a null previous snapshot, so they simply show
            // no price-change badge until their next refresh.
            await m.addColumn(cardsCache, cardsCache.previousJson);
            await m.addColumn(cardsCache, cardsCache.previousFetchedAt);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
