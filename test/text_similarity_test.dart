import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/shared/utils/text_similarity.dart';

void main() {
  group('normalizeForCompare', () {
    test('lowercases, strips punctuation and accents, collapses spaces', () {
      expect(normalizeForCompare('G-Max  Wildfire!'), 'gmax wildfire');
      expect(normalizeForCompare('Pokémon'), 'pokemon');
      expect(normalizeForCompare("Feelin' Fine"), 'feelin fine');
      expect(normalizeForCompare('  Furret  '), 'furret');
    });
  });

  group('editDistance', () {
    test('known distances', () {
      expect(editDistance('', ''), 0);
      expect(editDistance('abc', 'abc'), 0);
      expect(editDistance('abc', ''), 3);
      expect(editDistance('kitten', 'sitting'), 3);
      expect(editDistance('flaw', 'lawn'), 2);
    });

    test('symmetric', () {
      expect(editDistance('charizard', 'charzard'), editDistance('charzard', 'charizard'));
    });
  });

  group('similarity', () {
    test('identical after normalising is 1.0', () {
      expect(similarity('Charizard VMAX', 'charizard  vmax'), 1.0);
    });

    test('typical OCR noise still scores high', () {
      expect(similarity('Charizarcl', 'Charizard'), greaterThanOrEqualTo(0.8));
      expect(similarity('G-Max Wildfrre', 'G-Max Wildfire'), greaterThan(0.8));
    });

    test('a different card scores low', () {
      expect(similarity('Pikachu', 'Charizard VMAX'), lessThan(0.4));
      expect(similarity('Dark Charizard', 'Charizard'), lessThan(0.75));
    });

    test('empty handling', () {
      expect(similarity('', ''), 1.0);
      expect(similarity('Furret', ''), 0.0);
    });
  });

  test('bestSimilarity picks the closest candidate', () {
    expect(
      bestSimilarity('Tall Smash', ['Feelin\' Fine', 'Tail Smash']),
      greaterThan(0.85),
    );
    expect(bestSimilarity('Hydro Pump', ['Feelin\' Fine', 'Tail Smash']), lessThan(0.5));
    expect(bestSimilarity('anything', const []), 0.0);
  });
}
