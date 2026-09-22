import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/data/tcgdex/set_info.dart';
import 'package:pokescan/data/tcgdex/tcgdex_models.dart';
import 'package:pokescan/features/card_detail/fake_signals.dart';
import 'package:pokescan/features/scan/card_text_parser.dart';

TcgCard fixtureCard(String name) => TcgCard.fromJson(
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>);

List<FakeSignal> warningsOf(List<FakeSignal> all) => all.where((s) => s.isWarning).toList();

void main() {
  final furret = fixtureCard('swsh3-136'); // HP 110, Feelin' Fine / Tail Smash
  const darknessAblaze = SetInfo(
    id: 'swsh3',
    name: 'Darkness Ablaze',
    official: 189,
    total: 201,
    releaseDate: '2020-08-14',
  );

  ParsedCard scan({
    String? name = 'Furret',
    int? hp = 110,
    List<String> attacks = const ["Feelin' Fine", 'Tail Smash'],
    String? number = '136',
    int? total = 189,
  }) =>
      ParsedCard(name: name, hp: hp, attackNames: attacks, number: number, total: total);

  group('clean scan', () {
    test('a matching scan raises no warnings, only the visual checklist', () {
      final signals = FakeSignals.evaluate(card: furret, scan: scan(), set: darknessAblaze);
      expect(warningsOf(signals), isEmpty);
      expect(signals, isNotEmpty);
      expect(signals.every((s) => s.kind == SignalKind.visual), isTrue);
    });

    test('no scan at all still gives the checklist and no warnings', () {
      final signals = FakeSignals.evaluate(card: furret, set: darknessAblaze);
      expect(warningsOf(signals), isEmpty);
      expect(signals.length, greaterThanOrEqualTo(5));
    });

    test('never states a verdict', () {
      final signals = FakeSignals.evaluate(card: furret, scan: scan(hp: 90), set: darknessAblaze);
      for (final s in signals) {
        final text = '${s.prompt} ${s.detail ?? ''}'.toLowerCase();
        expect(text.contains('fake'), isFalse, reason: 'signal must not conclude: $s');
        expect(text.contains('counterfeit is'), isFalse);
        expect(text.contains('this card is fake'), isFalse);
      }
    });
  });

  group('text mismatch (the Phase 4 done-when)', () {
    test('wrong HP raises a warning naming both values', () {
      final signals = FakeSignals.evaluate(card: furret, scan: scan(hp: 90), set: darknessAblaze);
      final w = warningsOf(signals);
      expect(w, hasLength(1));
      expect(w.single.kind, SignalKind.textMismatch);
      expect(w.single.detail, contains('90'));
      expect(w.single.detail, contains('110'));
    });

    test('a counterfeit with a typo’d attack name triggers a warning', () {
      final signals = FakeSignals.evaluate(
        card: furret,
        scan: scan(attacks: ['Tail Smashs Power', 'Feelin Fine']),
        set: darknessAblaze,
      );
      final w = warningsOf(signals);
      expect(w, isNotEmpty);
      expect(w.first.kind, SignalKind.textMismatch);
    });

    test('OCR noise inside an attack name does not cry wolf', () {
      final signals = FakeSignals.evaluate(
        card: furret,
        scan: scan(attacks: ['Tall Smash', "Feelln' Fine"]),
        set: darknessAblaze,
      );
      expect(warningsOf(signals), isEmpty);
    });

    test('a Japanese card is not flagged for text the Latin OCR cannot read', () {
      // The same card data, but as a Japanese print: the OCR's attempt at the
      // name and attacks is garbage, and that is the model's fault, not a fake.
      final japanese = TcgCard.fromJson(
          jsonDecode(File('test/fixtures/swsh3-136.json').readAsStringSync()) as Map<String, dynamic>,
          lang: 'ja');
      final signals = FakeSignals.evaluate(
        card: japanese,
        scan: scan(name: 'Xk7 qq', attacks: ['Zzz zz zz']),
        set: darknessAblaze,
      );
      expect(warningsOf(signals), isEmpty);
    });

    test('...but a wrong HP still warns on a Japanese card — digits are digits', () {
      final japanese = TcgCard.fromJson(
          jsonDecode(File('test/fixtures/swsh3-136.json').readAsStringSync()) as Map<String, dynamic>,
          lang: 'ja');
      final signals = FakeSignals.evaluate(card: japanese, scan: scan(hp: 90), set: darknessAblaze);
      expect(warningsOf(signals), hasLength(1));
    });

    test('a completely different name warns', () {
      final signals =
          FakeSignals.evaluate(card: furret, scan: scan(name: 'Pikachu'), set: darknessAblaze);
      expect(warningsOf(signals).any((s) => s.detail!.contains('Pikachu')), isTrue);
    });

    test('a slightly misread name does not warn', () {
      final signals =
          FakeSignals.evaluate(card: furret, scan: scan(name: 'Furrct'), set: darknessAblaze);
      expect(warningsOf(signals), isEmpty);
    });

    test('missing OCR fields are simply not checked', () {
      final signals = FakeSignals.evaluate(
        card: furret,
        scan: scan(name: null, hp: null, attacks: const []),
        set: darknessAblaze,
      );
      expect(warningsOf(signals), isEmpty);
    });
  });

  group('number and set sanity', () {
    test('printed total that disagrees with the set warns', () {
      final signals =
          FakeSignals.evaluate(card: furret, scan: scan(total: 165), set: darknessAblaze);
      final w = warningsOf(signals);
      expect(w.any((s) => s.kind == SignalKind.setSanity), isTrue);
      expect(w.first.detail, contains('189'));
    });

    test('a number above the whole print run warns', () {
      const tiny = SetInfo(id: 'swsh3', name: 'Darkness Ablaze', official: 189, total: 201);
      final card = TcgCard.fromJson({
        'id': 'swsh3-999',
        'localId': '999',
        'name': 'Furret',
        'set': {'id': 'swsh3', 'name': 'Darkness Ablaze'},
      });
      final signals = FakeSignals.evaluate(card: card, set: tiny);
      expect(warningsOf(signals).any((s) => s.kind == SignalKind.numberSanity), isTrue);
    });

    test('a secret rare above the official count is fine', () {
      final card = TcgCard.fromJson({
        'id': 'swsh3-195',
        'localId': '195',
        'name': 'Charizard',
        'set': {'id': 'swsh3', 'name': 'Darkness Ablaze'},
      });
      final signals = FakeSignals.evaluate(card: card, set: darknessAblaze);
      expect(warningsOf(signals), isEmpty);
    });
  });

  group('colour', () {
    test('a large saturation gap adds a soft, hedged prompt', () {
      final signals = FakeSignals.evaluate(
        card: furret,
        scan: scan(),
        set: darknessAblaze,
        saturationDelta: 0.4,
      );
      final w = warningsOf(signals);
      expect(w.single.kind, SignalKind.colour);
      expect(w.single.detail, contains('nudge'));
    });

    test('a small gap is ignored', () {
      final signals = FakeSignals.evaluate(
        card: furret,
        scan: scan(),
        set: darknessAblaze,
        saturationDelta: 0.05,
      );
      expect(warningsOf(signals), isEmpty);
    });

    test('an unmeasurable delta is ignored', () {
      final signals = FakeSignals.evaluate(card: furret, scan: scan(), saturationDelta: null);
      expect(warningsOf(signals), isEmpty);
    });
  });

  test('warnings sort above routine prompts', () {
    final signals = FakeSignals.evaluate(card: furret, scan: scan(hp: 40), set: darknessAblaze);
    expect(signals.first.isWarning, isTrue);
    expect(signals.last.isWarning, isFalse);
  });
}
