/// CSV export of the collection.
///
/// Pure Dart and unit-tested: the fiddly part is quoting, and card names carry
/// commas, apostrophes and accents often enough to matter.
library;

import '../../data/repositories/collection_repository.dart';

/// Columns, in order. Stable: a spreadsheet built on this should not break
/// when a column is added, so new columns go on the end.
const kCsvHeaders = [
  'card_id',
  'name',
  'set',
  'set_id',
  'number',
  'rarity',
  'variant',
  'condition',
  'language',
  'quantity',
  'unit_value',
  'currency',
  'total_value',
  'price_source',
  'price_paid',
  'acquired_at',
  'added_at',
  'notes',
];

/// RFC 4180: double quotes doubled, fields with comma/quote/newline quoted.
/// A leading `=`, `+`, `-` or `@` is prefixed with a quote so spreadsheets do
/// not treat a card name as a formula.
String csvEscape(Object? value) {
  if (value == null) return '';
  var s = value.toString();
  if (s.isEmpty) return '';
  if (RegExp(r'^[=+\-@]').hasMatch(s)) s = "'$s";
  if (s.contains('"') || s.contains(',') || s.contains('\n') || s.contains('\r')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String _date(int? epochMs) {
  if (epochMs == null) return '';
  return DateTime.fromMillisecondsSinceEpoch(epochMs).toIso8601String().split('T').first;
}

String _money(double? v) => v == null ? '' : v.toStringAsFixed(2);

/// One row per collection item, in the order given.
String collectionToCsv(List<CollectionEntry> entries) {
  final buf = StringBuffer()..writeln(kCsvHeaders.join(','));
  for (final e in entries) {
    final card = e.card;
    final unit = e.unitValue;
    final total = e.totalValue;
    final row = [
      e.item.cardId,
      card?.name,
      card?.set.name,
      card?.set.id,
      card?.localId,
      card?.rarity,
      e.variant.name,
      e.item.condition,
      e.item.language,
      e.item.quantity,
      _money(unit?.amount),
      unit?.currency,
      _money(total?.amount),
      unit?.source,
      _money(e.item.pricePaid),
      _date(e.item.acquiredAt),
      _date(e.item.addedAt),
      e.item.notes,
    ];
    buf.writeln(row.map(csvEscape).join(','));
  }
  return buf.toString();
}

/// `pokescan-collection-2026-09-15.csv`
String csvFileName({DateTime? now}) {
  final d = (now ?? DateTime.now()).toIso8601String().split('T').first;
  return 'pokescan-collection-$d.csv';
}
