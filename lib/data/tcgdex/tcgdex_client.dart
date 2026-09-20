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

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConstants.tcgdexBaseUrl}/$lang$path').replace(queryParameters: query);

  Future<TcgCard> getCard(String id) async =>
      TcgCard.fromJson(await _getJson('/cards/$id') as Map<String, dynamic>);

  /// Raw JSON for [id]; the cache stores this verbatim (Phase 2).
  Future<Map<String, dynamic>> getCardJson(String id) async =>
      await _getJson('/cards/$id') as Map<String, dynamic>;

  Future<TcgSet> getSet(String id) async =>
      TcgSet.fromJson(await _getJson('/sets/$id') as Map<String, dynamic>);

  Future<List<SetBrief>> getSets() async => (await _getJson('/sets') as List)
      .whereType<Map<String, dynamic>>()
      .map(SetBrief.fromJson)
      .toList();

  /// Substring match on name; optionally narrowed to a set.
  Future<List<CardBrief>> searchCards(String name, {String? setId}) async {
    final res = await _getJson('/cards', {
      'name': name,
      if (setId != null && setId.isNotEmpty) 'set.id': setId,
    });
    return (res as List).whereType<Map<String, dynamic>>().map(CardBrief.fromJson).toList();
  }

  Future<Object?> _getJson(String path, [Map<String, String>? query]) async {
    try {
      return await _getJsonOnce(path, query);
    } on FormatException {
      // TCGdex occasionally answers with an empty or truncated body from one
      // of its nodes (see CLAUDE.md). One retry clears it.
      return _getJsonOnce(path, query);
    }
  }

  Future<Object?> _getJsonOnce(String path, [Map<String, String>? query]) async {
    final uri = _uri(path, query);
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
