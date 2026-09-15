import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/data/db/database.dart';
import 'package:pokescan/data/repositories/collection_repository.dart';
import 'package:pokescan/data/tcgdex/tcgdex_models.dart';

void main() {
  late AppDatabase db;
  late CollectionRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CollectionRepository(db);
    await db.cardCacheDao.put(
      'swsh3-136',
      jsonEncode({
        'id': 'swsh3-136',
        'localId': '136',
        'name': 'Furret',
        'set': {'id': 'swsh3', 'name': 'Darkness Ablaze'},
        'variants': {'normal': true},
      }),
    );
  });
  tearDown(() => db.close());

  Future<int> addFurret() => repo.add(
        cardId: 'swsh3-136',
        variant: CardVariant.normal,
        quantity: 3,
        condition: 'LP',
        notes: 'bent corner',
        pricePaid: 2.5,
      );

  group('removeRestorable / restore', () {
    test('removing returns the row and deletes it', () async {
      final id = await addFurret();
      final removed = await repo.removeRestorable(id);

      expect(removed, isNotNull);
      expect(removed!.cardId, 'swsh3-136');
      expect(await db.collectionDao.getById(id), isNull);
    });

    test('restore puts everything the user typed back', () async {
      final id = await addFurret();
      final removed = await repo.removeRestorable(id);
      await repo.restore(removed!);

      final rows = await db.collectionDao.watchAll().first;
      expect(rows, hasLength(1));
      final back = rows.single;
      expect(back.cardId, 'swsh3-136');
      expect(back.quantity, 3);
      expect(back.condition, 'LP');
      expect(back.notes, 'bent corner');
      expect(back.pricePaid, 2.5);
    });

    test('restore keeps the original addedAt, not the time of the undo', () async {
      final id = await addFurret();
      final before = (await db.collectionDao.getById(id))!.addedAt;
      final removed = await repo.removeRestorable(id);
      await repo.restore(removed!);

      final back = (await db.collectionDao.watchAll().first).single;
      expect(back.addedAt, before);
    });

    test('removing something already gone is a no-op, not a crash', () async {
      expect(await repo.removeRestorable(999), isNull);
    });

    test('other rows are untouched', () async {
      final keep = await addFurret();
      final drop = await addFurret();
      await repo.removeRestorable(drop);

      final rows = await db.collectionDao.watchAll().first;
      expect(rows.map((r) => r.id), [keep]);
    });
  });
}
