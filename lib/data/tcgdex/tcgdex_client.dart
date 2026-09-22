import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants.dart';
import 'tcgdex_models.dart';

/// Thrown for non-2xx responses. `statusCode == 404` means "no such card/set".
class TcgdexException implements Exception {
  const TcgdexException(this.statusCode, this.message, {this.endpoint});
  final int statusCode;
  final String message;
  final String? endpoint;

  bool get isNotFound => statusCode == 404;

  @override
  String toString() => 'TcgdexException($statusCode): $message';
}

/// Thin HTTP wrapper around TCGdex v2. No auth, no key.
class TcgdexClient {
  TcgdexClient({http.Client? client, this.lang = AppConstants.defaultLang})
      : _client = client ?? http.Client();

  final http.Client _client;
  /// TCGdex language segment (`en`, `ja`, …).
  final String lang;

  /// Every call takes an optional [lang] because the app now holds cards from
  /// more than one TCGdex catalogue at once; the client's own [lang] is just
  /// the default.
  Uri _uri(String path, String? lang, [Map<String, String>? query]) =>
      Uri.parse('${AppConstants.tcgdexBaseUrl}/${lang ?? this.lang}$path')
          .replace(queryParameters: query);

  /// Ids are path-encoded: set ids can contain characters (`M-P`) that are
  /// harmless today but have no business being trusted raw in a URL.
  static String _seg(String s) => Uri.encodeComponent(s);

  Future<TcgCard> getCard(String id, {String? lang}) async => TcgCard.fromJson(
      await _getJson('/cards/${_seg(id)}', lang) as Map<String, dynamic>,
      lang: lang ?? this.lang);

  /// Raw JSON for [id]; the cache stores this verbatim (Phase 2).
  Future<Map<String, dynamic>> getCardJson(String id, {String? lang}) async =>
      await _getJson('/cards/${_seg(id)}', lang) as Map<String, dynamic>;

  Future<TcgSet> getSet(String id, {String? lang}) async => TcgSet.fromJson(
      await _getJson('/sets/${_seg(id)}', lang) as Map<String, dynamic>,
      lang: lang ?? this.lang);

  /// Raw set JSON, for building a SetInfo from a newly released set.
  Future<Map<String, dynamic>> getSetJson(String id, {String? lang}) async =>
      await _getJson('/sets/${_seg(id)}', lang) as Map<String, dynamic>;

  /// The raw set list: `{id, name, cardCount}` per set. One request, and the
  /// whole of what the daily new-set check costs on a day with no releases.
  Future<List<Map<String, dynamic>>> getSetListJson({String? lang}) async =>
      (await _getJson('/sets', lang) as List).whereType<Map<String, dynamic>>().toList();

  Future<List<SetBrief>> getSets({String? lang}) async => (await _getJson('/sets', lang) as List)
      .whereType<Map<String, dynamic>>()
      .map(SetBrief.fromJson)
      .toList();

  /// Substring match on name; optionally narrowed to a set.
  Future<List<CardBrief>> searchCards(String name, {String? setId, String? lang}) async {
    final res = await _getJson('/cards', lang, {
      'name': name,
      if (setId != null && setId.isNotEmpty) 'set.id': setId,
    });
    return (res as List)
        .whereType<Map<String, dynamic>>()
        .map((j) => CardBrief.fromJson(j, lang: lang ?? this.lang))
        .toList();
  }

  Future<Object?> _getJson(String path, String? lang, [Map<String, String>? query]) async {
    try {
      return await _getJsonOnce(path, lang, query);
    } on FormatException {
      // TCGdex occasionally answers with an empty or truncated body from one
      // of its nodes (see CLAUDE.md). One retry clears it.
      return _getJsonOnce(path, lang, query);
    }
  }

  Future<Object?> _getJsonOnce(String path, String? lang, [Map<String, String>? query]) async {
    final uri = _uri(path, lang, query);
    final res = await _client.get(uri, headers: const {'Accept': 'application/json'});
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = utf8.decode(res.bodyBytes);
      if (body.trim().isEmpty) throw const FormatException('Empty response body');
      return jsonDecode(body);
    }
    String message = 'HTTP ${res.statusCode}';
    try {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      message = body['title'] as String? ?? message;
    } catch (_) {}
    throw TcgdexException(res.statusCode, message, endpoint: uri.path);
  }

  void close() => _client.close();
}
