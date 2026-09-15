import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/data/tcgdex/set_info.dart';
import 'package:pokescan/data/tcgdex/set_resolver.dart';

void main() {
  final r = SetResolver();

  test('bundled index resolves known sets by id and abbreviation', () {
    expect(r.byCode('swsh3')?.name, 'Darkness Ablaze');
    expect(r.byCode('DAA')?.id, 'swsh3');
    expect(r.byCode('par')?.id, 'sv04');
    expect(r.byCode('nope'), isNull);
  });

  test('total 189 gives two candidates, newest first', () {
    final c = r.byTotal(189);
    expect(c.map((s) => s.id), ['swsh10', 'swsh3']);
  });

  test('resolve prefers code over total', () {
    expect(r.resolve(number: '20', total: 189, code: 'DAA').single.id, 'swsh3');
  });

  test('resolve by total filters out sets the number cannot belong to', () {
    final subset = SetResolver([
      const SetInfo(id: 'a', name: 'A', official: 100, total: 110, releaseDate: '2020-01-01'),
      const SetInfo(id: 'b', name: 'B', official: 100, total: 100, releaseDate: '2021-01-01'),
    ]);
    expect(subset.resolve(number: '105', total: 100).map((s) => s.id), ['a']);
    expect(subset.resolve(number: '50', total: 100).map((s) => s.id), ['b', 'a']);
  });

  test('resolve with nothing usable is empty', () {
    expect(r.resolve(number: '20'), isEmpty);
    expect(r.resolve(number: '20', total: 99999), isEmpty);
  });

  test('pocket sets excluded', () {
    expect(r.byCode('A1'), isNull);
    expect(r.all.any((s) => s.serie == 'Pokémon TCG Pocket'), isFalse);
  });

  test('normaliseNumber keeps zeros, trims, uppercases', () {
    expect(SetResolver.normaliseNumber(' 020 '), '020');
    expect(SetResolver.normaliseNumber('tg12'), 'TG12');
  });

  test('cardIdFor pads per set', () {
    expect(r.byCode('swsh3')!.cardIdFor('020'), 'swsh3-20');
    expect(r.byCode('swsh3')!.cardIdFor('20'), 'swsh3-20');
    expect(r.byCode('sv04')!.cardIdFor('42'), 'sv04-042');
    expect(r.byCode('sv04')!.cardIdFor('042'), 'sv04-042');
    expect(r.byCode('sv04')!.cardIdFor('223'), 'sv04-223');
    expect(r.byCode('svp')!.cardIdFor('12'), 'svp-012');
    expect(r.byCode('swshp')!.cardIdFor('SWSH061'), 'swshp-SWSH061');
    expect(r.byCode('swshp')!.cardIdFor('swsh61'), 'swshp-SWSH061');
    expect(r.byCode('swsh9tg')!.cardIdFor('TG1'), 'swsh9tg-TG01');
    expect(r.byCode('swsh9tg')!.cardIdFor('TG12'), 'swsh9tg-TG12');
    expect(r.byCode('me01')!.cardIdFor('5'), 'me01-005');
  });

  test('TG number restricts to trainer-gallery subsets', () {
    final c = r.resolve(number: 'TG12', total: 30);
    expect(c, isNotEmpty);
    expect(c.every((s) => s.id.endsWith('tg')), isTrue);
  });
}
