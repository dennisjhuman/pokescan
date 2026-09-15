import 'package:drift/drift.dart';

import 'database.dart';

part 'card_cache_dao.g.dart';

@DriftAccessor(tables: [CardsCache])
class CardCacheDao extends DatabaseAccessor<AppDatabase> with _$CardCacheDaoMixin {
  CardCacheDao(super.db);

  Future<CardsCacheData?> get(String id) =>
      (select(cardsCache)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> put(String id, String json, {DateTime? fetchedAt}) =>
      into(cardsCache).insertOnConflictUpdate(CardsCacheCompanion.insert(
        id: id,
        json: json,
        fetchedAt: (fetchedAt ?? DateTime.now()).millisecondsSinceEpoch,
      ));

  Future<List<CardsCacheData>> getMany(Iterable<String> ids) =>
      (select(cardsCache)..where((t) => t.id.isIn(ids))).get();

  Stream<List<CardsCacheData>> watchAll() => select(cardsCache).watch();
}
