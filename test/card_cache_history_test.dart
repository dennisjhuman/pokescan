import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/data/db/database.dart';

String cardJson({required double trend, String id = 'swsh3-136'}) => jsonEncode({
      'id': id,
      'localId': '136',
      'name': 'Furret',
      'set': {'id': 'swsh3', 'name': 'Darkness Ablaze'},
      'variants': {'normal': true},
      'pricing': {
        'cardmarket': {'unit': 'EUR', 'trend': trend},
      },
    });

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('cards_cache keeps one step of history', () {
    test('a first write has no previous snapshot', () async {
      await db.cardCacheDao.put('swsh3-136', cardJson(trend: 1.0));
      final row = await db.cardCacheDao.get('swsh3-136');
      expect(row!.previousJson, isNull);
      expect(row.previousFetchedAt, isNull);
    });

    test('a refresh rolls the old response into the previous slot', () async {
      await db.cardCacheDao.put('swsh3-136', cardJson(trend: 1.0),
          fetchedAt: DateTime(2026, 9, 1));
      await db.cardCacheDao.put('swsh3-136', cardJson(trend: 2.0),
          fetchedAt: DateTime(2026, 9, 15));

      final row = await db.cardCacheDao.get('swsh3-136');
      expect(jsonDecode(row!.json)['pricing']['cardmarket']['trend'], 2.0);
      expect(jsonDecode(row.previousJson!)['pricing']['cardmarket']['trend'], 1.0);
      expect(
        DateTime.fromMillisecondsSinceEpoch(row.previousFetchedAt!),
        DateTime(2026, 9, 1),
      );
      expect(DateTime.fromMillisecondsSinceEpoch(row.fetchedAt), DateTime(2026, 9, 15));
    });

    test('only one step is kept', () async {
      await db.cardCacheDao.put('swsh3-136', cardJson(trend: 1.0));
      await db.cardCacheDao.put('swsh3-136', cardJson(trend: 2.0));
      await db.cardCacheDao.put('swsh3-136', cardJson(trend: 3.0));

      final row = await db.cardCacheDao.get('swsh3-136');
      expect(jsonDecode(row!.json)['pricing']['cardmarket']['trend'], 3.0);
      expect(jsonDecode(row.previousJson!)['pricing']['cardmarket']['trend'], 2.0);
    });

    test('keepPrevious leaves an earlier snapshot intact', () async {
      await db.cardCacheDao.put('swsh3-136', cardJson(trend: 1.0));
      await db.cardCacheDao.put('swsh3-136', cardJson(trend: 2.0));
      await db.cardCacheDao.put('swsh3-136', cardJson(trend: 2.0), keepPrevious: true);

      final row = await db.cardCacheDao.get('swsh3-136');
      expect(jsonDecode(row!.previousJson!)['pricing']['cardmarket']['trend'], 1.0,
          reason: 'a non-refresh rewrite must not clobber the real earlier price');
    });

    test('rows are independent', () async {
      await db.cardCacheDao.put('swsh3-136', cardJson(trend: 1.0));
      await db.cardCacheDao.put('swsh3-136', cardJson(trend: 2.0));
      await db.cardCacheDao.put('swsh3-20', cardJson(trend: 9.0, id: 'swsh3-20'));

      expect((await db.cardCacheDao.get('swsh3-20'))!.previousJson, isNull);
      expect((await db.cardCacheDao.get('swsh3-136'))!.previousJson, isNotNull);
    });
  });
}
