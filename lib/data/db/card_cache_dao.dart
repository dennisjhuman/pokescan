import 'package:drift/drift.dart';

import 'database.dart';

part 'card_cache_dao.g.dart';

@DriftAccessor(tables: [CardsCache])
class CardCacheDao extends DatabaseAccessor<AppDatabase> with _$CardCacheDaoMixin {
  CardCacheDao(super.db);

  Future<CardsCacheData?> get(String id) =>
      (select(cardsCache)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Write a fresh response, rolling the row's current contents into the
  /// previous slot so a price move can be derived later.
  ///
  /// [keepPrevious] leaves the existing snapshot alone; use it when rewriting
  /// a row for a reason other than a refresh, so a real earlier price is not
  /// overwritten by an identical one.
  Future<void> put(
    String id,
    String json, {
    DateTime? fetchedAt,
    bool keepPrevious = false,
  }) async {
    final now = (fetchedAt ?? DateTime.now()).millisecondsSinceEpoch;
    final existing = await get(id);
    if (existing == null) {
      await into(cardsCache).insert(CardsCacheCompanion.insert(id: id, json: json, fetchedAt: now));
      return;
    }
    await (update(cardsCache)..where((t) => t.id.equals(id))).write(CardsCacheCompanion(
      json: Value(json),
      fetchedAt: Value(now),
      previousJson: keepPrevious ? const Value.absent() : Value(existing.json),
      previousFetchedAt: keepPrevious ? const Value.absent() : Value(existing.fetchedAt),
    ));
  }

  Future<List<CardsCacheData>> getMany(Iterable<String> ids) =>
      (select(cardsCache)..where((t) => t.id.isIn(ids))).get();

  Stream<List<CardsCacheData>> watchAll() => select(cardsCache).watch();
}
