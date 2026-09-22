import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/data/tcgdex/card_key.dart';

void main() {
  test('English keys are the bare TCGdex id, exactly as before', () {
    // Every collection row written before other languages existed must still
    // mean what it meant.
    final k = CardKey.parse('swsh3-20');
    expect(k.lang, 'en');
    expect(k.id, 'swsh3-20');
    expect(k.key, 'swsh3-20');
  });

  test('other languages carry a prefix', () {
    final k = CardKey.parse('ja:M6-058');
    expect(k.lang, 'ja');
    expect(k.id, 'M6-058');
    expect(k.key, 'ja:M6-058');
    expect(const CardKey('ja', 'M6-058').key, 'ja:M6-058');
  });

  test('the collision it exists to prevent', () {
    // English sv10 is Destined Rivals; Japanese SV10 is a different set.
    expect(CardKey.parse('sv10-100').key.toLowerCase(),
        isNot(CardKey.parse('ja:SV10-100').key.toLowerCase()));
  });

  test('regional language codes parse', () {
    expect(CardKey.parse('zh-tw:SV1-001').lang, 'zh-tw');
  });

  test('set id is everything before the last hyphen', () {
    expect(CardKey.parse('sv04-185').setId, 'sv04');
    expect(CardKey.parse('30th-c-001').setId, '30th-c');
    expect(CardKey.parse('ja:M-P-001').setId, 'M-P');
  });

  test('card paths encode the colon', () {
    expect(cardPath('swsh3-20'), '/card/swsh3-20');
    expect(cardPath('ja:M6-058'), '/card/ja%3AM6-058');
    expect(Uri.decodeComponent(cardPath('ja:M6-058').substring(6)), 'ja:M6-058');
  });
}
