import 'dart:convert';

import '../../core/constants.dart';
import '../db/card_cache_dao.dart';
import '../tcgdex/card_key.dart';
import '../tcgdex/tcgdex_client.dart';
import '../tcgdex/tcgdex_models.dart';

/// Cache-first access to cards: memory → drift `cards_cache` → network.
///
/// Refresh rules (CLAUDE.md): use the cached copy if younger than
/// [AppConstants.cacheTtl]; otherwise refetch. If the network is down, a
/// stale cached copy is still returned. TCGdex sometimes answers with a null
/// `pricing.tcgplayer` / `cardmarket` block, so a refresh never overwrites a
/// non-null pricing block with a null one.
class CardRepository {
  CardRepository(this._client, this._cache);

  final TcgdexClient _client;
  final CardCacheDao _cache;
  final _memory = <String, TcgCard>{};

  /// [id] is a card key (see [CardKey]): `swsh3-20` or `ja:M6-058`. The cache
  /// is keyed on the lower-cased key, so the language prefix keeps English
  /// `sv10-100` and Japanese `ja:sv10-100` apart.
  Future<TcgCard> getCard(String id, {bool forceRefresh = false}) async {
    final ref = CardKey.parse(id);
    final key = ref.key.toLowerCase();
    TcgCard parse(Map<String, dynamic> j) => TcgCard.fromJson(j, lang: ref.lang);
    if (!forceRefresh) {
      final hit = _memory[key];
      if (hit != null) return hit;
    }

    final cached = await _cache.get(key);
    final cachedJson = cached == null ? null : jsonDecode(cached.json) as Map<String, dynamic>;
    final age = cached == null
        ? null
        : DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(cached.fetchedAt));
    final fresh = age != null && age < AppConstants.cacheTtl;

    if (cachedJson != null && fresh && !forceRefresh) {
      return _memory[key] = parse(cachedJson);
    }

    try {
      final json = await _client.getCardJson(ref.id, lang: ref.lang);
      final merged = mergePricing(cachedJson, json);
      await _cache.put(key, jsonEncode(merged));
      return _memory[key] = parse(merged);
    } catch (e) {
      if (cachedJson != null) {
        // Offline or API hiccup: stale beats nothing.
        return _memory[key] = parse(cachedJson);
      }
      rethrow;
    }
  }

  /// Parse a cached row without touching the network. Null if not cached.
  Future<TcgCard?> getCachedOnly(String id) async {
    final ref = CardKey.parse(id);
    final key = ref.key.toLowerCase();
    final hit = _memory[key];
    if (hit != null) return hit;
    final row = await _cache.get(key);
    if (row == null) return null;
    return _memory[key] =
        TcgCard.fromJson(jsonDecode(row.json) as Map<String, dynamic>, lang: ref.lang);
  }

  /// The response the cached row replaced, or null if it has only ever been
  /// fetched once.
  Future<TcgCard?> getPreviousCard(String id) async {
    final ref = CardKey.parse(id);
    final row = await _cache.get(ref.key.toLowerCase());
    final prev = row?.previousJson;
    if (prev == null) return null;
    return TcgCard.fromJson(jsonDecode(prev) as Map<String, dynamic>, lang: ref.lang);
  }

  Future<List<CardBrief>> searchByName(String name, {String? setId, String lang = CardKey.defaultLang}) =>
      _client.searchCards(name.trim(), setId: setId, lang: lang);

  /// Japanese set ids are mixed case (`SV2a`) and TCGdex matches them either
  /// way, so the id is passed through as given rather than lower-cased.
  Future<TcgSet> getSet(String id, {String lang = CardKey.defaultLang}) =>
      _client.getSet(id, lang: lang);

  /// Keep old `pricing.cardmarket` / `pricing.tcgplayer` when the new response
  /// has them as null. Pure; unit-tested.
  static Map<String, dynamic> mergePricing(Map<String, dynamic>? old, Map<String, dynamic> fresh) {
    if (old == null) return fresh;
    final oldP = old['pricing'];
    if (oldP is! Map<String, dynamic>) return fresh;
    final freshP = fresh['pricing'];
    final merged = <String, dynamic>{...?(freshP is Map<String, dynamic> ? freshP : null)};
    for (final k in const ['cardmarket', 'tcgplayer']) {
      if (merged[k] == null && oldP[k] != null) merged[k] = oldP[k];
    }
    return {...fresh, 'pricing': merged};
  }
}
