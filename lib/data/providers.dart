import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../shared/utils/colour_stats.dart';
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

/// The cached response this card's row replaced, if any. Drives the
/// price-change badge on the detail screen.
final previousCardProvider = FutureProvider.family<TcgCard?, String>((ref, id) async {
  // Rebuild whenever the card itself is refetched, so the badge updates with it.
  await ref.watch(cardProvider(id).future);
  return ref.watch(cardRepositoryProvider).getPreviousCard(id);
});

/// Mean saturation of the official card image, for the soft colour check.
///
/// Null when it cannot be measured, which is the normal case on web: the
/// TCGdex asset host sends no CORS header, so the fetch is blocked. The colour
/// signal is optional by design, so a null simply drops it.
final referenceSaturationProvider = FutureProvider.family<double?, String>((ref, imageUrl) async {
  ref.keepAlive();
  try {
    final res = await http.get(Uri.parse(imageUrl));
    if (res.statusCode != 200) return null;
    return await compute(_saturationOf, res.bodyBytes);
  } catch (_) {
    return null;
  }
});

double? _saturationOf(Uint8List bytes) => meanSaturation(bytes);

/// Rows the user owns for one card, live.
final collectionForCardProvider = StreamProvider.family<List<CollectionItem>, String>(
    (ref, cardId) => ref.watch(collectionRepositoryProvider).watchForCard(cardId));
