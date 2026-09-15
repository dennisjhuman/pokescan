import 'dart:convert';

import '../../core/constants.dart';
import '../db/card_cache_dao.dart';
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

  Future<TcgCard> getCard(String id, {bool forceRefresh = false}) async {
    final key = id.toLowerCase();
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
      return _memory[key] = TcgCard.fromJson(cachedJson);
    }

    try {
      final json = await _client.getCardJson(key);
      final merged = mergePricing(cachedJson, json);
      await _cache.put(key, jsonEncode(merged));
      return _memory[key] = TcgCard.fromJson(merged);
    } catch (e) {
      if (cachedJson != null) {
        // Offline or API hiccup: stale beats nothing.
        return _memory[key] = TcgCard.fromJson(cachedJson);
      }
      rethrow;
    }
  }

  /// Parse a cached row without touching the network. Null if not cached.
  Future<TcgCard?> getCachedOnly(String id) async {
    final key = id.toLowerCase();
    final hit = _memory[key];
    if (hit != null) return hit;
    final row = await _cache.get(key);
    if (row == null) return null;
    return _memory[key] = TcgCard.fromJson(jsonDecode(row.json) as Map<String, dynamic>);
  }

  Future<List<CardBrief>> searchByName(String name, {String? setId}) =>
      _client.searchCards(name.trim(), setId: setId);

  Future<TcgSet> getSet(String id) => _client.getSet(id.toLowerCase());

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
