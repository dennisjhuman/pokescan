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

  /// Which *printing* of that variant, when the card has several that are
  /// priced apart — a GameStop-stamped holo is not a plain holo. Null means
  /// "not specified", which values the row from the card-level price exactly
  /// as every row written before schema v4 did. See [CardPrinting.key].
  TextColumn get printingKey => text().nullable()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  TextColumn get condition => text().withDefault(const Constant('NM'))(); // NM LP MP HP DMG
  TextColumn get language => text().withDefault(const Constant('en'))();
  TextColumn get scanPath => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get acquiredAt => integer().nullable()();
  RealColumn get pricePaid => real().nullable()();
  IntColumn get addedAt => integer()();
}

/// Sets the runtime check found that were not in the bundled index, one row
/// per language. Stored as a JSON list rather than a row per set: it is read
/// whole at startup, written whole after a check, and is a handful of entries
/// long — a table of its own would be ceremony. See set_index_refresher.dart.
class SetLists extends Table {
  TextColumn get lang => text()();
  TextColumn get json => text()();

  /// When TCGdex was last asked, epoch ms. Drives the once-a-day check.
  IntColumn get checkedAt => integer()();

  @override
  Set<Column> get primaryKey => {lang};
}

@DriftDatabase(tables: [CardsCache, CollectionItems, SetLists], daos: [CardCacheDao, CollectionDao])
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
  int get schemaVersion => 4;

  Future<SetList?> setList(String lang) =>
      (select(setLists)..where((t) => t.lang.equals(lang))).getSingleOrNull();

  Future<void> putSetList(String lang, String json, DateTime checkedAt) =>
      into(setLists).insertOnConflictUpdate(SetListsCompanion.insert(
        lang: lang,
        json: json,
        checkedAt: checkedAt.millisecondsSinceEpoch,
      ));

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Existing rows get a null previous snapshot, so they simply show
            // no price-change badge until their next refresh.
            await m.addColumn(cardsCache, cardsCache.previousJson);
            await m.addColumn(cardsCache, cardsCache.previousFetchedAt);
          }
          if (from < 3) {
            // Starts empty: the first check after upgrading fills it.
            await m.createTable(setLists);
          }
          if (from < 4) {
            // Null on every existing row, which values them from the
            // card-level price — what they were already worth.
            await m.addColumn(collectionItems, collectionItems.printingKey);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
