import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/features/scan/set_browser.dart';

/// Browsing sets used to be an imperative push that behaved as a picker:
/// tapping a card in the grid popped the grid *and* the set list before the
/// card was pushed, so Back from a card landed on the Scan tab rather than on
/// the set you were looking at. These are routes now, and the path builders
/// are what keeps the stack addressable.
void main() {
  group('setsPath', () {
    test('no query and English carries no parameters', () {
      expect(setsPath(), '/sets');
    });

    test('a set code is carried so the browser opens filtered', () {
      expect(setsPath(query: 'PAR'), '/sets?q=PAR');
    });

    test('Japanese is carried; English is the default and stays implicit', () {
      expect(setsPath(lang: 'ja'), '/sets?lang=ja');
      expect(setsPath(query: 'M6', lang: 'ja'), '/sets?q=M6&lang=ja');
      expect(setsPath(query: 'PAR', lang: 'en'), '/sets?q=PAR');
    });

    test('a blank query is not carried', () {
      expect(setsPath(query: '   '), '/sets');
    });

    test('a set name with spaces survives the round trip', () {
      final uri = Uri.parse(setsPath(query: 'Evolving Skies'));
      expect(uri.path, '/sets');
      expect(uri.queryParameters['q'], 'Evolving Skies');
    });
  });

  group('setPath', () {
    test('language and id name one set', () {
      expect(setPath('en', 'swsh3'), '/sets/en/swsh3');
      expect(setPath('ja', 'M6'), '/sets/ja/M6');
    });

    test('a set id with a hyphen or a dot is encoded, not split', () {
      // `30th-c` and `sv03.5` are real set ids.
      expect(setPath('en', '30th-c'), '/sets/en/30th-c');
      final uri = Uri.parse(setPath('en', 'sv03.5'));
      expect(uri.pathSegments, ['sets', 'en', 'sv03.5']);
    });
  });
}
