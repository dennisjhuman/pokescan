import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/features/scan/card_text_parser.dart';

/// Shorthand: text at vertical position [y] with height [h].
OcrLine line(String text, double y, {double h = 0.03, double x = 0.1, double w = 0.5}) =>
    OcrLine(text, left: x, top: y - h / 2, right: x + w, bottom: y + h / 2);

void main() {
  final parser = CardTextParser();

  group('Sword & Shield era (number/total, no printed set code)', () {
    final charizardVmax = [
      line('VMAX', 0.04, h: 0.02),
      line('Charizard VMAX', 0.08, h: 0.045),
      line('HP 330', 0.08, h: 0.03, x: 0.7, w: 0.2),
      line('Gigantamax', 0.11, h: 0.015),
      line('Claw Slash 100', 0.62),
      line('G-Max Wildfire 300', 0.68),
      line('Discard 2 Energy from this Pokémon.', 0.71, h: 0.015),
      line('D', 0.94, h: 0.02, x: 0.05, w: 0.03),
      line('020/189', 0.94, h: 0.02, x: 0.09, w: 0.12),
      line('©2020 Pokémon / Nintendo / Creatures / GAME FREAK', 0.97, h: 0.012),
    ];

    test('reads number, total, name, hp, attacks', () {
      final p = parser.parse(charizardVmax);
      expect(p.number, '020');
      expect(p.total, 189);
      expect(p.setCode, isNull);
      expect(p.name, 'Charizard VMAX');
      expect(p.hp, 330);
      expect(p.attackNames, ['Claw Slash', 'G-Max Wildfire']);
    });

    test('189 → two candidate sets, newest first, not confident', () {
      final p = parser.parse(charizardVmax);
      expect(p.candidateIds, ['swsh10-020', 'swsh3-20'], reason: 'padding is per set');
      expect(p.isConfident, isFalse);
    });
  });

  group('Scarlet & Violet era (printed set code)', () {
    test('code next to number resolves to one set', () {
      final p = parser.parse([
        line('Charizard ex', 0.08, h: 0.045),
        line('HP 330', 0.08, x: 0.7, w: 0.2),
        line('MEW EN', 0.945, h: 0.015, x: 0.05, w: 0.08),
        line('125/165', 0.945, h: 0.02, x: 0.14, w: 0.12),
      ]);
      expect(p.setCode, 'MEW');
      expect(p.number, '125');
      expect(p.total, 165);
      expect(p.candidateIds, ['sv03.5-125']);
      expect(p.isConfident, isTrue);
    });

    test('code on the same OCR line as number', () {
      final p = parser.parse([
        line('Pikachu', 0.08, h: 0.045),
        line('G  PAR EN  042/193', 0.945, h: 0.02, x: 0.05, w: 0.3),
      ]);
      expect(p.setCode, 'PAR');
      expect(p.candidateIds, ['sv04-042'], reason: 'SV era keeps zero padding');
    });

    test('secret rare above the printed total still resolves', () {
      final p = parser.parse([
        line('Charizard ex', 0.08, h: 0.045),
        line('OBF EN', 0.945, h: 0.015, x: 0.05, w: 0.08),
        line('223/197', 0.945, h: 0.02, x: 0.14, w: 0.12),
      ]);
      expect(p.candidateIds, ['sv03-223']);
    });
  });

  group('OCR noise', () {
    test('O→0, I→1 inside numbers; spaces around slash', () {
      final p = parser.parse([
        line('Furret', 0.08, h: 0.045),
        line('I36 / I89', 0.94, h: 0.02),
      ]);
      expect(p.number, '136');
      expect(p.total, 189);
    });

    test('HP glued to name; stage prefix stripped', () {
      final p = parser.parse([
        line('STAGE 1 Furret HP110', 0.08, h: 0.045),
        line('136/189', 0.94, h: 0.02),
      ]);
      expect(p.name, 'Furret');
      expect(p.hp, 110);
    });

    test('name is the tallest top line, not the small "Evolves from"', () {
      final p = parser.parse([
        line('Evolves from Sentret', 0.05, h: 0.012),
        line('Furret', 0.09, h: 0.045),
        line('136/189', 0.94, h: 0.02),
      ]);
      expect(p.name, 'Furret');
    });

    test('number line found even if crop put it above the bottom band', () {
      final p = parser.parse([
        line('Furret', 0.08, h: 0.045),
        line('136/189', 0.60, h: 0.02),
      ]);
      expect(p.number, '136');
    });
  });

  group('Promos and oddities', () {
    test('SWSH promo number without slash maps to swshp', () {
      final p = parser.parse([
        line('Pikachu V', 0.08, h: 0.045),
        line('SWSH061', 0.94, h: 0.02),
      ]);
      expect(p.number, 'SWSH061');
      expect(p.total, isNull);
      expect(p.setCode, 'swshp');
      expect(p.candidateIds, ['swshp-SWSH061']);
    });

    test('trainer gallery TG number', () {
      final p = parser.parse([
        line('Charizard V', 0.08, h: 0.045),
        line('TG12/TG30', 0.94, h: 0.02),
      ]);
      expect(p.number, 'TG12');
      expect(p.total, 30);
      expect(p.candidateIds, everyElement(endsWith('tg-TG12')));
      expect(p.candidateIds, contains('swsh9tg-TG12'));
    });

    test('nothing readable → empty candidates, no crash', () {
      final p = parser.parse([line('blurry', 0.5)]);
      expect(p.number, isNull);
      expect(p.candidateIds, isEmpty);
      expect(p.isConfident, isFalse);
    });

    test('unknown total → number kept, no candidates (caller falls back to name search)', () {
      final p = parser.parse([
        line('Snorlax', 0.08, h: 0.045),
        line('11/999', 0.94, h: 0.02),
      ]);
      expect(p.number, '11');
      expect(p.candidateIds, isEmpty);
      expect(p.name, 'Snorlax');
    });
  });
}
