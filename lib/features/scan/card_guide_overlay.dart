
import 'package:flutter/material.dart';

/// Dims everything except a card-shaped window at [guide] (0..1 coords of
/// the overlay's own size) and draws rounded corner marks.
class CardGuideOverlay extends StatelessWidget {
  const CardGuideOverlay({super.key, required this.guide, this.hint});

  final Rect guide;
  final String? hint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final rect = Rect.fromLTWH(
            guide.left * c.maxWidth,
            guide.top * c.maxHeight,
            guide.width * c.maxWidth,
            guide.height * c.maxHeight,
          );
          return Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _MaskPainter(rect))),
              if (hint != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: rect.bottom + 16,
                  child: Text(
                    hint!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, shadows: [Shadow(blurRadius: 4)]),
                  ),
                ),
            ],
          );
        },
      );
}

class _MaskPainter extends CustomPainter {
  _MaskPainter(this.window);
  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(window, const Radius.circular(14));
    final mask = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(mask, Paint()..color = Colors.black54);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white70,
    );
  }

  @override
  bool shouldRepaint(_MaskPainter old) => old.window != window;
}
