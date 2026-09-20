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

    test('Mega Rayquaza ex — Japanese card is flagged, not mis-resolved', () {
      final p = q('メガレックウザex');
      expect(p.japanese, isTrue);
      expect(p.kind, CardQueryKind.name);
    });

    test('Groudon — Japanese set code is reported as unknown, not guessed at', () {
      final p = q('M6 084/076 AR');
      expect(p.number, '084');
      expect(p.total, 76);
      expect(p.leftovers, contains('M6'), reason: 'so the UI can say it is unknown');
      expect(p.setCode, isNull);
      expect(parser.candidateIds(p), isEmpty, reason: 'no English set has 76 cards here');
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

  group('spotting a Japanese card without any Japanese in the text', () {
    test('a Japanese-shaped set code is a hint, not a lookup', () {
      final p = q('M6 058/076 RR');
      expect(p.japanese, isFalse, reason: 'nothing Japanese was actually typed');
      expect(p.likelyJapanese, isTrue);
      expect(parser.candidateIds(p), isEmpty);
    });

    test('SV10 is a set in both languages, so it stays an English lookup', () {
      final p = q('SV10 100/182');
      expect(p.setCode, 'SV10');
      expect(p.likelyJapanese, isFalse);
      expect(parser.candidateIds(p), ['sv10-100']);
    });

    test('a real English three-letter code is never mistaken for Japanese', () {
      expect(q('PAR EN 185/182').likelyJapanese, isFalse);
      expect(q('OBF EN 223/197').likelyJapanese, isFalse);
    });
  });

  group('did you mean', () {
    test('a near-miss code suggests real sets', () {
      final near = parser.resolver.didYouMean('PAF');
      expect(near, isNotEmpty);
      expect(near.map((s) => s.abbreviation), contains('PAR'));
    });
  });
}
