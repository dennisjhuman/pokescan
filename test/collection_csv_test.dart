import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/data/db/database.dart';
import 'package:pokescan/data/repositories/collection_repository.dart';
import 'package:pokescan/data/tcgdex/tcgdex_models.dart';
import 'package:pokescan/features/collection/collection_csv.dart';

TcgCard fixtureCard(String name) => TcgCard.fromJson(
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>);

CollectionItem item({
  int id = 1,
  String cardId = 'swsh3-136',
  String variant = 'normal',
  int quantity = 1,
  String condition = 'NM',
  String language = 'en',
  String? notes,
  double? pricePaid,
  int? acquiredAt,
  int addedAt = 1757894400000, // 2025-09-15
}) =>
    CollectionItem(
      id: id,
      cardId: cardId,
      variant: variant,
      quantity: quantity,
      condition: condition,
      language: language,
      scanPath: null,
      notes: notes,
      acquiredAt: acquiredAt,
      pricePaid: pricePaid,
      addedAt: addedAt,
    );

List<String> rowsOf(String csv) =>
    csv.trim().split('\n').map((l) => l.trimRight()).toList();

void main() {
  final furret = fixtureCard('swsh3-136');

  group('csvEscape', () {
    test('plain values pass through', () {
      expect(csvEscape('Furret'), 'Furret');
      expect(csvEscape(3), '3');
    });

    test('null and empty become empty', () {
      expect(csvEscape(null), '');
      expect(csvEscape(''), '');
    });

    test('commas, quotes and newlines are quoted', () {
      expect(csvEscape('Hello, world'), '"Hello, world"');
      expect(csvEscape('say "hi"'), '"say ""hi"""');
      expect(csvEscape('two\nlines'), '"two\nlines"');
    });

    test('formula injection is defused', () {
      expect(csvEscape('=SUM(A1:A9)'), "'=SUM(A1:A9)");
      expect(csvEscape('-1'), "'-1");
      expect(csvEscape('@here'), "'@here");
    });

    test('an apostrophe in a card name is left alone', () {
      expect(csvEscape("Feelin' Fine"), "Feelin' Fine");
    });
  });

  group('collectionToCsv', () {
    test('empty collection is just the header', () {
      final csv = collectionToCsv(const []);
      expect(rowsOf(csv), [kCsvHeaders.join(',')]);
    });

    test('a row carries card, variant and derived value', () {
      final csv = collectionToCsv([
        CollectionEntry(item: item(quantity: 2, variant: 'reverse'), card: furret),
      ]);
      final rows = rowsOf(csv);
      expect(rows, hasLength(2));
      final cells = rows[1].split(',');
      expect(cells[0], 'swsh3-136');
      expect(cells[1], 'Furret');
      expect(cells[2], 'Darkness Ablaze');
      expect(cells[3], 'swsh3');
      expect(cells[4], '136');
      expect(cells[6], 'reverse');
      expect(cells[9], '2');
      expect(cells[11], 'USD', reason: 'reverse falls back to TCGplayer');
    });

    test('total is unit times quantity', () {
      final entry = CollectionEntry(item: item(quantity: 3), card: furret);
      final cells = rowsOf(collectionToCsv([entry]))[1].split(',');
      final unit = double.parse(cells[10]);
      final total = double.parse(cells[12]);
      expect(total, closeTo(unit * 3, 0.001));
    });

    test('a card missing from the cache still exports its row', () {
      final csv = collectionToCsv([CollectionEntry(item: item(), card: null)]);
      final cells = rowsOf(csv)[1].split(',');
      expect(cells[0], 'swsh3-136');
      expect(cells[1], '');
      expect(cells[10], '', reason: 'no price without a card');
    });

    test('dates render as plain ISO days', () {
      final csv = collectionToCsv([
        CollectionEntry(item: item(acquiredAt: 1757894400000), card: furret),
      ]);
      final cells = rowsOf(csv)[1].split(',');
      expect(cells[15], matches(r'^\d{4}-\d{2}-\d{2}$'));
      expect(cells[16], matches(r'^\d{4}-\d{2}-\d{2}$'));
    });

    test('notes with a comma do not shift the columns', () {
      final csv = collectionToCsv([
        CollectionEntry(item: item(notes: 'bent corner, small crease'), card: furret),
      ]);
      expect(csv, contains('"bent corner, small crease"'));
      expect(rowsOf(csv), hasLength(2));
    });

    test('header column count matches every row', () {
      final csv = collectionToCsv([
        CollectionEntry(item: item(), card: furret),
        CollectionEntry(item: item(id: 2, notes: 'has, comma'), card: furret),
      ]);
      // Count separators outside quotes.
      for (final row in rowsOf(csv)) {
        var inQuotes = false, commas = 0;
        for (final ch in row.split('')) {
          if (ch == '"') inQuotes = !inQuotes;
          if (ch == ',' && !inQuotes) commas++;
        }
        expect(commas, kCsvHeaders.length - 1, reason: 'row: $row');
      }
    });
  });

  test('csvFileName is dated and safe', () {
    expect(csvFileName(now: DateTime(2026, 9, 15)), 'pokescan-collection-2026-09-15.csv');
  });
}
