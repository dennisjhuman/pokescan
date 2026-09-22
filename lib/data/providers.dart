import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../shared/utils/colour_stats.dart';
import 'db/database.dart';
import 'repositories/card_repository.dart';
import 'repositories/collection_repository.dart';
import 'tcgdex/card_key.dart';
import 'tcgdex/reprints.dart';
import 'tcgdex/set_catalog.dart';
import 'tcgdex/set_index_refresher.dart';
import 'tcgdex/set_info.dart';
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

/// Like [cardProvider] but null instead of an error when the card does not
/// exist. The finder asks for several candidate ids at once and most of them
/// are expected to miss — a 404 there is an answer, not a failure.
final maybeCardProvider = FutureProvider.family<TcgCard?, String>((ref, id) async {
  ref.keepAlive();
  try {
    return await ref.watch(cardRepositoryProvider).getCard(id);
  } on TcgdexException catch (e) {
    if (e.isNotFound) return null;
    rethrow;
  }
});

/// Every card in a set, for browsing by set when the number is unreadable.
/// Keyed by language as well as id: `SV10` is a different set in each.
final setCardsProvider =
    FutureProvider.family<TcgSet, ({String lang, String id})>((ref, key) {
  ref.keepAlive();
  return ref.watch(cardRepositoryProvider).getSet(key.id, lang: key.lang);
});

/// Name search results. Kept in a provider so the finder survives rebuilds
/// and a repeated search is free. A name in kana or kanji searches the
/// Japanese catalogue; TCGdex does not cross-index names between languages.
final cardSearchProvider =
    FutureProvider.family<List<CardBrief>, ({String lang, String name})>((ref, q) {
  ref.keepAlive();
  return ref.watch(cardRepositoryProvider).searchByName(q.name, lang: q.lang);
});

/// Checks TCGdex for sets released since the bundle was built. See
/// [SetIndexRefresher]; this only plugs it into the client and the database.
final setIndexRefresherProvider = Provider<SetIndexRefresher>((ref) {
  final db = ref.watch(databaseProvider);
  final client = ref.watch(tcgdexClientProvider);
  return SetIndexRefresher(
    fetchList: (lang) => client.getSetListJson(lang: lang),
    fetchSet: (lang, id) => client.getSetJson(id, lang: lang),
    load: (lang) async {
      final row = await db.setList(lang);
      if (row == null) return null;
      final sets = (jsonDecode(row.json) as List)
          .whereType<Map<String, dynamic>>()
          .map(SetInfo.fromMap)
          .toList();
      return StoredSets(sets, DateTime.fromMillisecondsSinceEpoch(row.checkedAt));
    },
    save: (lang, sets, at) =>
        db.putSetList(lang, jsonEncode([for (final s in sets) s.toMap()]), at),
  );
});

/// Startup: put previously found sets into the catalogue (local, instant),
/// then check TCGdex for new ones in the background. Never throws — offline
/// just means the catalogue stays as it was.
final setCatalogBootstrapProvider = FutureProvider<void>((ref) async {
  final refresher = ref.watch(setIndexRefresherProvider);
  for (final lang in SetCatalog.languages) {
    try {
      await refresher.restore(lang);
    } catch (e) {
      debugPrint('set catalogue restore failed for $lang: $e');
    }
  }
  for (final lang in SetCatalog.languages) {
    unawaited(refresher.refresh(lang).then<void>((_) {}, onError: (Object e) {
      debugPrint('set catalogue check failed for $lang: $e');
    }));
  }
});

/// Ticks whenever the set catalogue changes, so screens that list sets or
/// resolve numbers pick up a newly found set without a restart.
final setCatalogVersionProvider = StreamProvider<int>((ref) async* {
  var version = 0;
  yield version;
  await for (final _ in SetCatalog.instance.changes) {
    yield ++version;
  }
});

/// Anniversary reprints of the card at [key] that print the same number —
/// see reprints.dart. English only (the reprint sets are English), and never
/// throws: this is a hint alongside a result, so a failure just means no hint.
///
/// Cost: the reprint sets' card lists once per session (two requests, kept),
/// plus one card fetch per same-name candidate — normally zero or one.
final reprintsOfProvider = FutureProvider.family<List<TcgCard>, String>((ref, key) async {
  ref.keepAlive();
  try {
    final k = CardKey.parse(key);
    if (!k.isEnglish || isReprintSet(k.setId)) return const [];
    final original = await ref.watch(maybeCardProvider(key).future);
    if (original == null) return const [];

    final found = <TcgCard>[];
    for (final r in kReprintSets) {
      final set = await ref.watch(setCardsProvider((lang: 'en', id: r.setId)).future);
      for (final brief in nameMatches(original, set.cards)) {
        final card = await ref.watch(maybeCardProvider(brief.key).future);
        if (card != null && isReprintOf(card, original)) found.add(card);
      }
    }
    return found;
  } catch (e) {
    debugPrint('reprint lookup failed for $key: $e');
    return const [];
  }
});

/// Language of a card key, for screens that need to behave differently for a
/// Japanese print (no text-mismatch checks, no English OCR comparison).
String languageOf(String key) => CardKey.parse(key).lang;

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
