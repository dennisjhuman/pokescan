import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/data/tcgdex/set_resolver.dart';
import 'package:pokescan/data/tcgdex/tcgdex_models.dart';
import 'package:pokescan/features/scan/card_results.dart';

/// A name search returns a flat list of a couple of hundred hits. The set is
/// what makes one of them identifiable, and it is derivable offline from the
/// id, so this grouping is the whole difference between a wall and a list.
void main() {
  final resolver = SetResolver();

  CardBrief brief(String id, String name) =>
      CardBrief(id: id, localId: id.split('-').last, name: name);

  test('groups by the set in the id, newest set first', () {
    final groups = groupBySet([
      brief('swsh3-20', 'Charizard VMAX'), // 2020
      brief('sv04-185', 'Toedscruel'), // 2023
      brief('swsh3-21', 'Charizard VMAX'),
      brief('base1-4', 'Charizard'), // 1999
    ], resolver);

    expect(groups.map((g) => g.setId), ['sv04', 'swsh3', 'base1']);
    expect(groups.map((g) => g.set?.name), ['Paradox Rift', 'Darkness Ablaze', 'Base Set']);
    expect(groups.firstWhere((g) => g.setId == 'swsh3').cards.length, 2);
  });

  test('an id whose set is not in the bundled index still groups', () {
    final groups = groupBySet([brief('notaset-1', 'Mystery')], resolver);
    expect(groups.single.setId, 'notaset');
    expect(groups.single.set, isNull);
  });

  test('undated sets sort after dated ones rather than jumping to the top', () {
    final groups = groupBySet([
      brief('notaset-1', 'Mystery'),
      brief('sv04-185', 'Toedscruel'),
    ], resolver);
    expect(groups.first.setId, 'sv04');
  });
}
