import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'repositories/card_repository.dart';
import 'repositories/collection_repository.dart';
import 'tcgdex/tcgdex_client.dart';
import 'tcgdex/tcgdex_models.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final tcgdexClientProvider = Provider<TcgdexClient>((ref) {
  final client = TcgdexClient();
  ref.onDispose(client.close);
  return client;
});

final cardRepositoryProvider = Provider<CardRepository>((ref) => CardRepository(
      ref.watch(tcgdexClientProvider),
      ref.watch(databaseProvider).cardCacheDao,
    ));

final collectionRepositoryProvider =
    Provider<CollectionRepository>((ref) => CollectionRepository(ref.watch(databaseProvider)));

/// One card by TCGdex id, e.g. `swsh3-20`. Cache-first; kept alive so
/// navigating back and forth doesn't refetch.
final cardProvider = FutureProvider.family<TcgCard, String>((ref, id) {
  ref.keepAlive();
  return ref.watch(cardRepositoryProvider).getCard(id);
});

/// Whole collection, live.
final collectionProvider = StreamProvider<List<CollectionEntry>>(
    (ref) => ref.watch(collectionRepositoryProvider).watchAll());

/// Rows the user owns for one card, live.
final collectionForCardProvider = StreamProvider.family<List<CollectionItem>, String>(
    (ref, cardId) => ref.watch(collectionRepositoryProvider).watchForCard(cardId));
