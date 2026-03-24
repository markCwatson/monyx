import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

/// Animated bullet that loops along an exaggerated arc from shooter to target.
///
/// The arc bows toward the upwind side: if crosswind pushes the bullet right,
/// the path curves from left-of-line to the target (the shooter compensates
/// by aiming into the wind).
class BulletArcOverlay extends StatefulWidget {
  final MapboxMap mapboxMap;
  final double shooterLat;
  final double shooterLon;
  final double targetLat;
  final double targetLon;

  /// Positive = from left (pushes bullet right). Same sign as ShotSolution.
  final double crosswindMph;
  final double rangeYards;

  const BulletArcOverlay({
    super.key,
    required this.mapboxMap,
    required this.shooterLat,
    required this.shooterLon,
    required this.targetLat,
    required this.targetLon,
    required this.crosswindMph,
    required this.rangeYards,
  });

  @override
  State<BulletArcOverlay> createState() => _BulletArcOverlayState();
}

class _BulletArcOverlayState extends State<BulletArcOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  /// Animation parameter 0 → 1, then resets.
  double _t = 0;

  /// Cached screen positions (updated async each frame).
  Offset? _shooterScreen;
  Offset? _targetScreen;
  bool _projecting = false;

  /// Duration of one bullet flight in seconds.
  static const _flightDuration = 1.8;

  /// Pause between flights in seconds.
  static const _pauseDuration = 0.4;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _projectCoordinates();
  }

  @override
  void didUpdateWidget(BulletArcOverlay old) {
    super.didUpdateWidget(old);
    // Re-project when coordinates or map changes.
    _projectCoordinates();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Future<void> _projectCoordinates() async {
    if (_projecting) return;
    _projecting = true;
    try {
      final shooterPx = await widget.mapboxMap.pixelForCoordinate(
        Point(
          coordinates:
              Position(widget.shooterLon, widget.shooterLat),
        ),
      );
      final targetPx = await widget.mapboxMap.pixelForCoordinate(
        Point(
          coordinates:
              Position(widget.targetLon, widget.targetLat),
        ),
      );
      if (mounted) {
        _shooterScreen = Offset(shooterPx.x, shooterPx.y);
        _targetScreen = Offset(targetPx.x, targetPx.y);
      }
    } catch (_) {
      // Map not ready yet — will retry next frame.
    }
    _projecting = false;
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    // Re-project each frame so the arc follows the map during pan/zoom.
    _projectCoordinates();

    // Advance t
    _t += dt / (_flightDuration + _pauseDuration);
    if (_t >= 1.0) _t -= 1.0;

    // Trigger repaint
    if (mounted) (context as Element).markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _BulletArcPainter(
            shooterScreen: _shooterScreen,
            targetScreen: _targetScreen,
            crosswindMph: widget.crosswindMph,
            t: _t,
            flightFraction:
                _flightDuration / (_flightDuration + _pauseDuration),
          ),
        ),
      ),
    );
  }
}

class _BulletArcPainter extends CustomPainter {
  final Offset? shooterScreen;
  final Offset? targetScreen;
  final double crosswindMph;
  final double t; // 0–1 total cycle progress
  final double flightFraction; // portion of cycle that is flight (vs pause)

  _BulletArcPainter({
    required this.shooterScreen,
    required this.targetScreen,
    required this.crosswindMph,
    required this.t,
    required this.flightFraction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (shooterScreen == null || targetScreen == null) return;

    final A = shooterScreen!;
    final B = targetScreen!;
    final lineVec = B - A;
    final lineLen = lineVec.distance;
    if (lineLen < 10) return; // too close to draw

    // Perpendicular to the left (from shooter's POV, screen Y-down).
    final perpLeft = Offset(lineVec.dy, -lineVec.dx) / lineLen;

    // Control-point offset: exaggerated curve proportional to crosswind.
    // Positive crosswind → from left → bullet compensates left → arc bows left
    // (perpLeft direction). Scale: ~20% of line length per 10 mph crosswind,
    // with a minimum visible curve when there IS crosswind.
    final cwAbs = crosswindMph.abs();
    final cwSign = crosswindMph >= 0 ? 1.0 : -1.0;
    final fraction = cwAbs < 0.5
        ? 0.0
        : (0.12 + 0.04 * cwAbs).clamp(0.0, 0.6);
    final controlOffset = perpLeft * (lineLen * fraction * cwSign);
    final mid = Offset.lerp(A, B, 0.5)!;
    final C = mid + controlOffset; // quadratic Bezier control point

    // --- draw the curved path (faint) ---
    final pathPaint = Paint()
      ..color = Colors.orangeAccent.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path()
      ..moveTo(A.dx, A.dy)
      ..quadraticBezierTo(C.dx, C.dy, B.dx, B.dy);
    canvas.drawPath(path, pathPaint);

    // --- animate bullet ---
    if (t > flightFraction) return; // in the pause gap

    final bt = t / flightFraction; // 0–1 within the flight portion

    // Position along quadratic Bezier: B(t) = (1-t)²A + 2(1-t)tC + t²B
    final pos = _quadBezier(A, C, B, bt);

    // Tangent for rotation: B'(t) = 2(1-t)(C-A) + 2t(B-C)
    final tangent = _quadBezierTangent(A, C, B, bt);
    final angle = atan2(tangent.dy, tangent.dx);

    // Trail: draw several past positions with fading opacity
    const trailCount = 12;
    const trailSpan = 0.08; // how far back in t-space the trail extends
    for (var i = trailCount; i >= 1; i--) {
      final tt = bt - (i / trailCount) * trailSpan;
      if (tt < 0) continue;
      final trailPos = _quadBezier(A, C, B, tt);
      final alpha = (1.0 - i / trailCount) * 0.4;
      final trailPaint = Paint()
        ..color = Colors.orangeAccent.withValues(alpha: alpha);
      canvas.drawCircle(trailPos, 2.5 - i * 0.15, trailPaint);
    }

    // Bullet head — small rotated diamond
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);
    final bulletPaint = Paint()..color = Colors.orangeAccent;
    final bulletPath = Path()
      ..moveTo(6, 0) // nose
      ..lineTo(-3, -3) // top-left
      ..lineTo(-5, 0) // tail
      ..lineTo(-3, 3) // bottom-left
      ..close();
    canvas.drawPath(bulletPath, bulletPaint);

    // Bright core
    final corePaint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    canvas.drawCircle(Offset.zero, 1.5, corePaint);
    canvas.restore();

    // Fade-in at start, fade-out at end
    // (handled via trail naturally)
  }

  static Offset _quadBezier(Offset a, Offset c, Offset b, double t) {
    final mt = 1 - t;
    return a * (mt * mt) + c * (2 * mt * t) + b * (t * t);
  }

  static Offset _quadBezierTangent(Offset a, Offset c, Offset b, double t) {
    final mt = 1 - t;
    return (c - a) * (2 * mt) + (b - c) * (2 * t);
  }

  @override
  bool shouldRepaint(_BulletArcPainter oldDelegate) => true;
}
