import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/data/tcgdex/card_query.dart';

/// Every case in the first group is a real card that was awkward to look up
/// by hand, photographed bottom-edge-first. If one of these regresses, the
/// finder has got worse at the thing it exists to do.
void main() {
  final parser = CardQueryParser();

  CardQuery q(String s) => parser.parse(s);

  group('cards in hand', () {
    test('Duraludon VMAX — regulation mark, no set code', () {
      final p = q('E 123/203');
      expect(p.kind, CardQueryKind.number);
      expect(p.number, '123');
      expect(p.total, 203);
      expect(p.regulationMark, 'E', reason: 'the lone letter is not a set');
      expect(p.setCode, isNull);
      expect(parser.candidateIds(p), ['swsh7-123']);
    });

    test('Toedscruel — set code, language marker, secret rare number', () {
      final p = q('PAR EN 185/182');
      expect(p.number, '185');
      expect(p.total, 182);
      expect(p.setCode, 'PAR');
      expect(p.leftovers, isEmpty, reason: 'EN is a language, not an unknown code');
      expect(parser.candidateIds(p), ['sv04-185']);
    });

    test('Toedscruel — 185/182 without the code still narrows to two sets', () {
      final p = q('185/182');
      final ids = parser.candidateIds(p);
      expect(ids, contains('sv04-185'));
      expect(ids.length, lessThanOrEqualTo(3), reason: 'a shortlist, not a wall');
    });

    test("Iono's Bellibolt ex — promo with no printed total", () {
      final p = q('SVP EN 194');
      expect(p.number, '194');
      expect(p.total, isNull);
      expect(p.setCode, 'SVP');
      expect(parser.candidateIds(p), ['svp-194']);
    });

    test('Pikachu — promo with the code glued to the number', () {
      final p = q('SWSH153');
      expect(p.number, 'SWSH153');
      expect(p.total, isNull);
      expect(parser.candidateIds(p), ['swshp-SWSH153']);
    });

    test('Mega Rayquaza ex — typed in Japanese, searched as Japanese', () {
      final p = q('メガレックウザex');
      expect(p.japanese, isTrue);
      expect(p.kind, CardQueryKind.name);
      expect(p.preferredLang, 'ja');
    });

    test('Mega Rayquaza ex — from its bottom edge, J M6 058/076 RR', () {
      final p = q('J M6 058/076 RR');
      expect(p.setCode, 'M6');
      expect(p.regulationMark, 'J', reason: 'J is the 2026 mark, not a set');
      expect(p.leftovers, isEmpty, reason: 'RR is a rarity');
      expect(parser.candidateIds(p), ['ja:M6-058']);
    });

    test('Groudon — Japanese set code resolves to the Japanese set', () {
      final p = q('M6 084/076 AR');
      expect(p.number, '084');
      expect(p.total, 76);
      expect(p.setCode, 'M6');
      expect(p.japaneseCode, isTrue);
      expect(parser.candidateIds(p), ['ja:M6-084']);
    });

    test('Groudon — even without the code, 084/076 finds it', () {
      // No English set has 76 cards, so the Japanese catalogue is tried next.
      expect(parser.candidateIds(q('084/076')), contains('ja:M6-084'));
    });
  });

  group('shapes', () {
    test('a bare TCGdex id goes straight through', () {
      final p = q('swsh3-20');
      expect(p.kind, CardQueryKind.cardId);
      expect(parser.candidateIds(p), ['swsh3-20']);
    });

    test('set code and number, no slash', () {
      final p = q('PAR 185');
      expect(p.number, '185');
      expect(p.total, isNull);
      expect(p.setCode, 'PAR');
      expect(parser.candidateIds(p), ['sv04-185']);
    });

    test('trainer gallery numbers stay in the gallery subsets', () {
      final p = q('TG12/TG30');
      expect(p.number, 'TG12');
      expect(p.total, 30);
      expect(parser.candidateIds(p), everyElement(endsWith('tg-TG12')));
    });

    test('a name is a name', () {
      final p = q('Charizard');
      expect(p.kind, CardQueryKind.name);
      expect(p.name, 'Charizard');
    });

    test('empty input is empty, not a search for nothing', () {
      expect(q('').kind, CardQueryKind.empty);
      expect(q('   ').kind, CardQueryKind.empty);
    });

    test('a bare number cannot be placed on its own', () {
      final p = q('185');
      expect(p.number, '185');
      expect(parser.candidateIds(p), isEmpty);
    });

    test('a set size no set has resolves to nothing rather than guessing', () {
      expect(parser.candidateIds(q('11/999')), isEmpty);
    });
  });

  group('OCR fixups', () {
    test('O and I inside the number are digits', () {
      final p = q('I36/I89');
      expect(p.number, '136');
      expect(p.total, 189);
    });

    test('lowercase id and spaced slash', () {
      final p = q('020 / 189');
      expect(p.number, '020');
      expect(p.total, 189);
    });

    test('zero padding is preserved for the sets that want it', () {
      expect(parser.candidateIds(q('MEW EN 125/165')), ['sv03.5-125']);
      expect(parser.candidateIds(q('PAR 042/182')), ['sv04-042']);
      expect(parser.candidateIds(q('DAA 020/189')), ['swsh3-20']);
    });
  });

  group('regulation mark as a tie-breaker', () {
    test('it narrows a number that fits more than one set', () {
      // 189 is both Darkness Ablaze (2020, mark D) and Astral Radiance (2022).
      final withMark = parser.candidateIds(q('D 020/189'));
      final without = parser.candidateIds(q('020/189'));
      expect(without.length, 2);
      expect(withMark.length, lessThanOrEqualTo(without.length));
      expect(withMark, contains('swsh3-20'));
    });

    test('it never empties the shortlist when it disagrees', () {
      // An impossible pairing (mark I is 2024+, this set is 2020) must not
      // silently rule the only real candidate out.
      expect(parser.candidateIds(q('I 020/189')), isNotEmpty);
    });
  });

  group('the two catalogues, and where they collide', () {
    test('a Japanese set code is recognised without any Japanese text', () {
      final p = q('M6 058/076 RR');
      expect(p.japanese, isFalse, reason: 'nothing Japanese was actually typed');
      expect(p.likelyJapanese, isTrue);
      expect(parser.candidateIds(p), ['ja:M6-058']);
    });

    test('SV10 is a set in both languages; the printed total decides', () {
      // English sv10 is Destined Rivals (182 cards); Japanese SV10 is a
      // different set of 98. Same code, different cards.
      expect(parser.candidateIds(q('SV10 100/182')), ['sv10-100']);
      expect(parser.candidateIds(q('SV10 050/098')), ['ja:SV10-050']);
    });

    test('an ordinary English number never grows Japanese look-alikes', () {
      final ids = parser.candidateIds(q('185/182'));
      expect(ids.every((id) => !id.startsWith('ja:')), isTrue);
    });

    test('a Japanese card key goes straight through', () {
      final p = q('ja:M6-058');
      expect(p.kind, CardQueryKind.cardId);
      expect(parser.candidateIds(p), ['ja:M6-058']);
    });

    test('a bare Japanese id with no prefix is still recognised', () {
      expect(parser.candidateIds(q('M6-058')), ['ja:M6-058']);
    });

    test('a code-and-number with a hyphen is not mistaken for an id', () {
      // PAR is a printed code, not a set id; sv04 is the id.
      expect(parser.candidateIds(q('PAR-185')), ['sv04-185']);
    });

    test('a real English three-letter code is never mistaken for Japanese', () {
      expect(q('PAR EN 185/182').likelyJapanese, isFalse);
      expect(q('OBF EN 223/197').likelyJapanese, isFalse);
    });
  });

  group('sets released after the app was built', () {
    test('30th Celebration: 045/128 resolves', () {
      expect(parser.candidateIds(q('045/128')), contains('30th-045'));
    });

    test('its id starts with a digit and still parses', () {
      final p = q('30th-045');
      expect(p.kind, CardQueryKind.cardId);
      expect(parser.candidateIds(p), ['30th-045']);
    });

    test('a set id with a hyphen in it parses too', () {
      expect(parser.candidateIds(q('30th-c-001')), ['30th-c-001']);
    });

    test('30C is shared by two sets; the total picks the right one', () {
      expect(parser.candidateIds(q('30C 045/128')), ['30th-045']);
    });

    test('30C with no total offers both rather than guessing', () {
      final ids = parser.candidateIds(q('30C 012'));
      expect(ids, containsAll(['30th-012', '30th-c-012']));
    });
  });

  group('products TCGdex does not have', () {
    // Pokémon Trading Card Game Classic (2023): three 34-card decks printed
    // CLV / CLC / CLB. TCGdex has no such sets, and its only 34-card set is
    // Double Crisis — which the set size alone used to pick.
    test('CLC 003/034 is not Double Crisis', () {
      final p = q('CLC 003/034');
      expect(p.untracked, 'CLC');
      expect(parser.candidateIds(p), isEmpty);
      expect(p.leftovers, isEmpty, reason: 'it is recognised, just not supported');
    });

    test('all three decks are recognised', () {
      for (final code in ['CLV', 'CLC', 'CLB']) {
        expect(q('$code 001/034').untracked, code);
      }
    });

    test('a bare 003/034 is still ambiguous and still shown', () {
      // Nothing on the input says it is the Classic deck; the artwork picker
      // makes the mismatch obvious to someone holding the card.
      expect(parser.candidateIds(q('003/034')), ['dc1-3']);
    });
  });

  group('did you mean', () {
    test('a near-miss code suggests real sets', () {
      final near = parser.resolver.didYouMean('PAF');
      expect(near, isNotEmpty);
      expect(near.map((s) => s.abbreviation), contains('PAR'));
    });
  });

  group('a Japanese name is a name, not a code', () {
    // Latin letters glued to a Japanese name used to survive the punctuation
    // strip on their own: `メガレックウザex` left the token `ex`, which matches
    // the English e-Card set, so the app read the name as "set ex" and offered
    // to browse it.
    test('a name ending in ex names no set', () {
      final query = q('メガレックウザex');
      expect(query.kind, CardQueryKind.name);
      expect(query.name, 'メガレックウザex');
      expect(query.setCode, isNull);
      expect(query.japanese, isTrue);
    });

    test('a plain kana name is unaffected', () {
      final query = q('ピカチュウ');
      expect(query.kind, CardQueryKind.name);
      expect(query.setCode, isNull);
      expect(query.preferredLang, 'ja');
    });

    test('a Latin set code beside a Japanese name is still read', () {
      final query = q('M6 メガレックウザex');
      expect(query.setCode, 'M6');
      expect(query.japaneseCode, isTrue);
    });
  });
}
