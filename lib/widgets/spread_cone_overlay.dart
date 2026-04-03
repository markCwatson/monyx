import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import '../models/pattern_result.dart';
import 'map_line_projector.dart';

/// Map overlay that draws a cone from the shooter to the target representing
/// the shotgun pattern spread. The cone is colour-coded by pellet density zones:
///   - Green (inner/R50) — kill zone, highest pellet concentration
///   - Amber (mid/R75) — effective zone
///   - Red (outer/spread edge) — fringe, low pellet density
class SpreadConeOverlay extends StatefulWidget {
  final MapboxMap mapboxMap;
  final double shooterLat;
  final double shooterLon;
  final double targetLat;
  final double targetLon;
  final PatternResult result;

  const SpreadConeOverlay({
    super.key,
    required this.mapboxMap,
    required this.shooterLat,
    required this.shooterLon,
    required this.targetLat,
    required this.targetLon,
    required this.result,
  });

  @override
  State<SpreadConeOverlay> createState() => _SpreadConeOverlayState();
}

class _SpreadConeOverlayState extends State<SpreadConeOverlay> {
  Offset? _shooterScreen;
  Offset? _targetScreen;
  bool _projecting = false;

  @override
  void initState() {
    super.initState();
    _projectCoordinates();
  }

  @override
  void didUpdateWidget(SpreadConeOverlay old) {
    super.didUpdateWidget(old);
    _projectCoordinates();
  }

  Future<void> _projectCoordinates() async {
    if (_projecting) return;
    _projecting = true;
    try {
      final result = await MapLineProjector.project(
        widget.mapboxMap,
        shooterLat: widget.shooterLat,
        shooterLon: widget.shooterLon,
        targetLat: widget.targetLat,
        targetLon: widget.targetLon,
      );
      if (mounted) {
        setState(() {
          if (result != null) {
            _shooterScreen = result.$1;
            _targetScreen = result.$2;
          } else {
            _shooterScreen = null;
            _targetScreen = null;
          }
        });
      }
    } catch (_) {}
    _projecting = false;
  }

  @override
  Widget build(BuildContext context) {
    // Re-project on every build so the cone follows map pan/zoom.
    _projectCoordinates();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _SpreadConePainter(
            shooterScreen: _shooterScreen,
            targetScreen: _targetScreen,
            result: widget.result,
          ),
        ),
      ),
    );
  }
}

class _SpreadConePainter extends CustomPainter {
  final Offset? shooterScreen;
  final Offset? targetScreen;
  final PatternResult result;

  _SpreadConePainter({
    required this.shooterScreen,
    required this.targetScreen,
    required this.result,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (shooterScreen == null || targetScreen == null) return;

    final A = shooterScreen!;
    final B = targetScreen!;
    final lineVec = B - A;
    final lineLen = lineVec.distance;
    if (lineLen < 10) return;

    final dir = lineVec / lineLen;
    final perp = Offset(dir.dy, -dir.dx); // perpendicular left

    // Compute the angular half-width of each zone at the target distance.
    // The real spread-to-range ratio is very small (e.g. 18" at 26 yds = ~1%),
    // which is invisible on screen. We enforce a minimum visible cone width
    // and scale the inner zones proportionally to keep the colour bands
    // meaningful.
    final rangeInches = result.distanceYards * 36.0; // yards → inches
    if (rangeInches <= 0) return;

    final realSpreadHalf =
        (result.spreadDiameterInches / 2) / rangeInches * lineLen;
    final realR75Half = result.r75Inches / rangeInches * lineLen;
    final realR50Half = result.r50Inches / rangeInches * lineLen;

    // Minimum outer cone half-width: 30px or 8% of line length, whichever is
    // larger. This makes the cone clearly visible at all zoom levels.
    const minHalf = 30.0;
    final desiredMin = lineLen * 0.08;
    final floor = minHalf > desiredMin ? minHalf : desiredMin;

    final scale = realSpreadHalf < floor && realSpreadHalf > 0
        ? floor / realSpreadHalf
        : 1.0;

    final spreadHalf = realSpreadHalf * scale;
    final r75Half = realR75Half * scale;
    final r50Half = realR50Half * scale;

    // Draw from outermost to innermost so inner zones paint on top.
    _drawZone(canvas, A, B, perp, spreadHalf, Colors.red, 0.15);
    _drawZone(canvas, A, B, perp, r75Half, Colors.amber, 0.20);
    _drawZone(canvas, A, B, perp, r50Half, Colors.green, 0.25);

    // Draw the centre line (faint)
    canvas.drawLine(
      A,
      B,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..strokeWidth = 1.0,
    );

    // Crosshair at target point
    _drawCrosshair(canvas, B);
  }

  void _drawZone(
    Canvas canvas,
    Offset origin,
    Offset target,
    Offset perp,
    double halfWidth,
    Color color,
    double opacity,
  ) {
    if (halfWidth < 1) return;

    final path = Path()
      ..moveTo(origin.dx, origin.dy)
      ..lineTo(target.dx + perp.dx * halfWidth, target.dy + perp.dy * halfWidth)
      ..lineTo(target.dx - perp.dx * halfWidth, target.dy - perp.dy * halfWidth)
      ..close();

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // Zone edge stroke
    final strokePaint = Paint()
      ..color = color.withValues(alpha: opacity + 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(path, strokePaint);
  }

  void _drawCrosshair(Canvas canvas, Offset center) {
    const arm = 8.0;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(center.dx - arm, center.dy),
      Offset(center.dx + arm, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - arm),
      Offset(center.dx, center.dy + arm),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SpreadConePainter oldDelegate) =>
      shooterScreen != oldDelegate.shooterScreen ||
      targetScreen != oldDelegate.targetScreen ||
      result != oldDelegate.result;
}
