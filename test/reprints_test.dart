import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/data/tcgdex/reprints.dart';
import 'package:pokescan/data/tcgdex/tcgdex_models.dart';

/// The 30th Classic Collection reprints print the original's number (the
/// 30th Charizard says 4/102), and TCGdex records no link between the two.
/// These pairs are real, checked against TCGdex on 2026-09-21.
void main() {
  TcgCard card(String id, String name,
          {int? hp, String? illus, List<String> attacks = const []}) =>
      TcgCard.fromJson({
        'id': id,
        'localId': id.split('-').last,
        'name': name,
        'hp': hp,
        'illustrator': illus,
        'attacks': [for (final a in attacks) {'name': a}],
        'set': {'id': id.substring(0, id.lastIndexOf('-')), 'name': 'x'},
      });

  final baseCharizard =
      card('base1-4', 'Charizard', hp: 120, illus: 'Mitsuhiro Arita', attacks: ['Fire Spin']);
  final reprintCharizard =
      card('30th-c-001', 'Charizard', hp: 120, illus: 'Mitsuhiro Arita', attacks: ['Fire Spin']);

  test('Charizard 4/102 and its 30th reprint match', () {
    expect(isReprintOf(reprintCharizard, baseCharizard), isTrue);
  });

  test('Crobat G 47/127 and Magikarp 203/193 match their reprints', () {
    expect(
        isReprintOf(
          card('30th-c-011', 'Crobat G', hp: 80, illus: 'Makoto Imai', attacks: ['Toxic Fang']),
          card('pl1-47', 'Crobat G', hp: 80, illus: 'Makoto Imai', attacks: ['Toxic Fang']),
        ),
        isTrue);
    expect(
        isReprintOf(
          card('30th-c-030', 'Magikarp', hp: 30, illus: 'Shinji Kanda', attacks: ['Expert Splasher']),
          card('sv02-203', 'Magikarp', hp: 30, illus: 'Shinji Kanda', attacks: ['Expert Splasher']),
        ),
        isTrue);
  });

  test('another Charizard that shares only the name does not', () {
    final charizardEx =
        card('sv03-125', 'Charizard ex', hp: 330, illus: 'aky CG Works', attacks: ['Burning Darkness']);
    final plainModern = card('swsh3-25', 'Charizard', hp: 170, illus: 'Kagemaru Himeno');
    expect(isReprintOf(reprintCharizard, charizardEx), isFalse);
    expect(isReprintOf(reprintCharizard, plainModern), isFalse);
  });

  test('a trainer with no HP or attacks matches on name and illustrator', () {
    expect(isReprintOf(card('30th-c-005', 'Misty', illus: 'Ken Sugimori'), card('xx-1', 'Misty', illus: 'Ken Sugimori')),
        isTrue);
    expect(isReprintOf(card('30th-c-005', 'Misty', illus: 'Ken Sugimori'), card('xx-1', 'Misty', illus: 'Someone Else')),
        isFalse);
  });

  test('only cards from a reprint set count as reprints', () {
    expect(isReprintOf(baseCharizard, reprintCharizard), isFalse, reason: 'direction matters');
    expect(isReprintOf(baseCharizard, baseCharizard), isFalse);
  });

  test('name matches narrow the fetch list before the real check', () {
    const briefs = [
      CardBrief(id: '30th-c-001', localId: '001', name: 'Charizard'),
      CardBrief(id: '30th-c-002', localId: '002', name: 'Delcatty'),
    ];
    expect(nameMatches(baseCharizard, briefs).map((b) => b.id), ['30th-c-001']);
  });
}
