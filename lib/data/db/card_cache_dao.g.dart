// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_cache_dao.dart';

// ignore_for_file: type=lint
mixin _$CardCacheDaoMixin on DatabaseAccessor<AppDatabase> {
  $CardsCacheTable get cardsCache => attachedDatabase.cardsCache;
  CardCacheDaoManager get managers => CardCacheDaoManager(this);
}

class CardCacheDaoManager {
  final _$CardCacheDaoMixin _db;
  CardCacheDaoManager(this._db);
  $$CardsCacheTableTableManager get cardsCache =>
      $$CardsCacheTableTableManager(_db.attachedDatabase, _db.cardsCache);
}
