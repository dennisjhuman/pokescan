// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_dao.dart';

// ignore_for_file: type=lint
mixin _$CollectionDaoMixin on DatabaseAccessor<AppDatabase> {
  $CardsCacheTable get cardsCache => attachedDatabase.cardsCache;
  $CollectionItemsTable get collectionItems => attachedDatabase.collectionItems;
  CollectionDaoManager get managers => CollectionDaoManager(this);
}

class CollectionDaoManager {
  final _$CollectionDaoMixin _db;
  CollectionDaoManager(this._db);
  $$CardsCacheTableTableManager get cardsCache =>
      $$CardsCacheTableTableManager(_db.attachedDatabase, _db.cardsCache);
  $$CollectionItemsTableTableManager get collectionItems =>
      $$CollectionItemsTableTableManager(
        _db.attachedDatabase,
        _db.collectionItems,
      );
}
