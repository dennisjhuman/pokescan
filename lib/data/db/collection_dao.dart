import 'package:drift/drift.dart';

import 'database.dart';

part 'collection_dao.g.dart';

@DriftAccessor(tables: [CollectionItems, CardsCache])
class CollectionDao extends DatabaseAccessor<AppDatabase> with _$CollectionDaoMixin {
  CollectionDao(super.db);

  Stream<List<CollectionItem>> watchAll() =>
      (select(collectionItems)..orderBy([(t) => OrderingTerm.desc(t.addedAt)])).watch();

  Stream<List<CollectionItem>> watchForCard(String cardId) =>
      (select(collectionItems)..where((t) => t.cardId.equals(cardId))).watch();

  Future<CollectionItem?> getById(int id) =>
      (select(collectionItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insert(CollectionItemsCompanion item) => into(collectionItems).insert(item);

  Future<bool> updateItem(CollectionItem item) => update(collectionItems).replace(item);

  Future<int> deleteById(int id) =>
      (delete(collectionItems)..where((t) => t.id.equals(id))).go();

  Future<int> setQuantity(int id, int quantity) => (update(collectionItems)
        ..where((t) => t.id.equals(id)))
      .write(CollectionItemsCompanion(quantity: Value(quantity)));
}
