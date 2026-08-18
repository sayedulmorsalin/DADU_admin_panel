import 'dart:ui';
import 'package:flutter/material.dart';

/// Ultra-smooth sports watermark background widget.
/// Pre-bakes watermark icons into a GPU-cached [Picture] to achieve constant 60/120 FPS
/// with zero CPU/GPU overhead during list scrolling.
class SportsBackgroundPattern extends StatelessWidget {
  final Widget child;
  final double opacity;
  final Color backgroundColor;

  const SportsBackgroundPattern({
    super.key,
    required this.child,
    this.opacity = 0.045,
    this.backgroundColor = const Color(0xFF112240),
  });

  static const List<IconData> _sportsIcons = [
    Icons.sports_soccer,
    Icons.sports_cricket,
    Icons.sports_basketball,
    Icons.sports_tennis,
    Icons.emoji_events,
    Icons.fitness_center,
    Icons.sports_motorsports,
    Icons.sports_football,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  isComplex: true,
                  willChange: false,
                  painter: _SportsIconPatternPainter(
                    icons: _sportsIcons,
                    opacity: opacity,
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SportsIconPatternPainter extends CustomPainter {
  final List<IconData> icons;
  final double opacity;
  Picture? _cachedPicture;
  Size? _lastSize;

  _SportsIconPatternPainter({
    required this.icons,
    required this.opacity,
  });

  void _renderToCanvas(Canvas canvas, Size size) {
    // Elegant, distributed watermark coordinates
    final List<Map<String, dynamic>> watermarkSpots = [
      {'x': 0.12, 'y': 0.08, 'icon': icons[0], 'size': 68.0, 'rot': -0.2},
      {'x': 0.85, 'y': 0.15, 'icon': icons[1], 'size': 62.0, 'rot': 0.25},
      {'x': 0.20, 'y': 0.32, 'icon': icons[2], 'size': 58.0, 'rot': 0.15},
      {'x': 0.80, 'y': 0.44, 'icon': icons[3], 'size': 72.0, 'rot': -0.3},
      {'x': 0.15, 'y': 0.58, 'icon': icons[4], 'size': 64.0, 'rot': 0.18},
      {'x': 0.82, 'y': 0.72, 'icon': icons[5], 'size': 60.0, 'rot': -0.22},
      {'x': 0.22, 'y': 0.86, 'icon': icons[6], 'size': 66.0, 'rot': 0.12},
      {'x': 0.78, 'y': 0.92, 'icon': icons[7], 'size': 64.0, 'rot': -0.15},
    ];

    for (final spot in watermarkSpots) {
      final double posX = (spot['x'] as double) * size.width;
      final double posY = (spot['y'] as double) * size.height;
      final IconData icon = spot['icon'] as IconData;
      final double iconSize = spot['size'] as double;
      final double rotation = spot['rot'] as double;

      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: iconSize,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: Colors.white.withValues(alpha: opacity),
          ),
        ),
      );
      textPainter.layout();

      canvas.save();
      canvas.translate(posX, posY);
      canvas.rotate(rotation);
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      canvas.restore();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_cachedPicture == null || _lastSize != size) {
      _lastSize = size;
      final recorder = PictureRecorder();
      final recordCanvas = Canvas(recorder, Rect.fromLTWH(0, 0, size.width, size.height));
      _renderToCanvas(recordCanvas, size);
      _cachedPicture = recorder.endRecording();
    }

    if (_cachedPicture != null) {
      canvas.drawPicture(_cachedPicture!);
    }
  }

  @override
  bool shouldRepaint(covariant _SportsIconPatternPainter oldDelegate) {
    return oldDelegate.opacity != opacity || oldDelegate.icons != icons;
  }
}
