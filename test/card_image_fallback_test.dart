import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/data/tcgdex/set_info.dart';
import 'package:pokescan/data/tcgdex/tcgdex_models.dart';

/// TCGdex sometimes uploads a set's art before updating the card data to
/// point at it: on 2026-09-21 every sampled card in Japanese M1S and M4 had
/// art on the asset host while the API listed `image: null` for all of them.
void main() {
  TcgCard card(String json, {String lang = 'en'}) => TcgCard.fromJson({
        'id': json,
        'localId': json.split('-').last,
        'name': 'x',
        'set': {'id': json.substring(0, json.lastIndexOf('-')), 'name': 's'},
      }, lang: lang);

  test('a listed image is used as given', () {
    final c = TcgCard.fromJson({
      'id': 'sv04-185',
      'localId': '185',
      'name': 'Toedscruel',
      'image': 'https://assets.tcgdex.net/en/sv/sv04/185',
      'set': {'id': 'sv04', 'name': 'Paradox Rift'},
    });
    expect(c.hasListedImage, isTrue);
    expect(c.imageUrl(quality: 'low'), 'https://assets.tcgdex.net/en/sv/sv04/185/low.webp');
  });

  test('no listed image: falls back to the conventional path', () {
    final c = card('M1S-001', lang: 'ja');
    expect(c.hasListedImage, isFalse);
    expect(c.imageUrl(quality: 'low'), 'https://assets.tcgdex.net/ja/M/M1S/001/low.webp');
  });

  test('the series comes from the index, not a guess from the set id', () {
    // `30th` has no leading letters to guess from; its series is `me`.
    const s = SetInfo(id: '30th', name: '30th', official: 128, total: 158, serieId: 'me');
    expect(s.conventionalImageBase('001'), 'https://assets.tcgdex.net/en/me/30th/001');
  });

  test('without a recorded series id, the leading letters are the guess', () {
    const s = SetInfo(id: 'swsh3', name: 'Darkness Ablaze', official: 189, total: 201);
    expect(s.conventionalImageBase('20'), 'https://assets.tcgdex.net/en/swsh/swsh3/20');
  });

  test('a set the catalogue does not know gets no URL rather than a wild guess', () {
    expect(card('nosuchset-001').imageUrl(), isNull);
  });

  test('search briefs fall back the same way, set ids with hyphens included', () {
    const b = CardBrief(id: 'M1S-001', localId: '001', name: 'x', lang: 'ja');
    expect(b.imageUrl(), 'https://assets.tcgdex.net/ja/M/M1S/001/low.webp');
  });
}
