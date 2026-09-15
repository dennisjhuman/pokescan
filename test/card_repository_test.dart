import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokescan/core/constants.dart';
import 'package:pokescan/data/db/database.dart';
import 'package:pokescan/data/repositories/card_repository.dart';
import 'package:pokescan/data/tcgdex/tcgdex_client.dart';

String fixture(String name) => File('test/fixtures/$name.json').readAsStringSync();

void main() {
  group('mergePricing', () {
    final full = jsonDecode(fixture('swsh3-136')) as Map<String, dynamic>;

    test('keeps old tcgplayer when fresh has null', () {
      final fresh = jsonDecode(fixture('swsh3-136')) as Map<String, dynamic>;
      (fresh['pricing'] as Map<String, dynamic>)['tcgplayer'] = null;
      final merged = CardRepository.mergePricing(full, fresh);
      expect((merged['pricing'] as Map)['tcgplayer'], isNotNull);
      expect((merged['pricing'] as Map)['cardmarket'], (fresh['pricing'] as Map)['cardmarket']);
    });

    test('fresh non-null wins', () {
      final fresh = jsonDecode(fixture('swsh3-136')) as Map<String, dynamic>;
      ((fresh['pricing'] as Map<String, dynamic>)['cardmarket'] as Map<String, dynamic>)['trend'] = 99.0;
      final merged = CardRepository.mergePricing(full, fresh);
      expect(((merged['pricing'] as Map)['cardmarket'] as Map)['trend'], 99.0);
    });

    test('no old → fresh unchanged', () {
      expect(CardRepository.mergePricing(null, full), same(full));
    });
  });

  group('CardRepository cache', () {
    late AppDatabase db;
    late int calls;
    late CardRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      calls = 0;
      final client = TcgdexClient(
        client: MockClient((req) async {
          calls++;
          if (req.url.path.endsWith('/cards/swsh3-136')) {
            return http.Response.bytes(utf8.encode(fixture('swsh3-136')), 200);
          }
          return http.Response('{"status":404}', 404);
        }),
      );
      repo = CardRepository(client, db.cardCacheDao);
    });

    tearDown(() => db.close());

    test('first call hits network and caches; second call does not', () async {
      final a = await repo.getCard('swsh3-136');
      expect(a.name, 'Furret');
      expect(calls, 1);
      final row = await db.cardCacheDao.get('swsh3-136');
      expect(row, isNotNull);

      // New repo instance (no memory cache) still avoids the network.
      final repo2 = CardRepository(
        TcgdexClient(client: MockClient((_) async => throw StateError('no network'))),
        db.cardCacheDao,
      );
      final b = await repo2.getCard('swsh3-136');
      expect(b.name, 'Furret');
    });

    test('stale row refetches; offline stale row still returned', () async {
      await db.cardCacheDao.put(
        'swsh3-136',
        fixture('swsh3-136'),
        fetchedAt: DateTime.now().subtract(AppConstants.cacheTtl + const Duration(days: 1)),
      );
      await repo.getCard('swsh3-136');
      expect(calls, 1, reason: 'stale → refetch');

      final offline = CardRepository(
        TcgdexClient(client: MockClient((_) async => throw const SocketException('down'))),
        db.cardCacheDao,
      );
      await db.cardCacheDao.put(
        'swsh3-136',
        fixture('swsh3-136'),
        fetchedAt: DateTime.now().subtract(const Duration(days: 30)),
      );
      final c = await offline.getCard('swsh3-136');
      expect(c.name, 'Furret');
    });

    test('unknown card throws not-found', () async {
      expect(
        () => repo.getCard('swsh3-9999'),
        throwsA(isA<TcgdexException>().having((e) => e.isNotFound, 'isNotFound', true)),
      );
    });
  });
}
