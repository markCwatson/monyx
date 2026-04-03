import 'dart:math';

import 'package:flutter/material.dart';

import '../models/pattern_result.dart';

/// Circle identifiers that can be toggled on/off.
class PatternCircle {
  static const spread = 'spread';
  static const r75 = 'r75';
  static const r50 = 'r50';
  static const ref20 = 'ref20';
  static const ref10 = 'ref10';

  static const all = {spread, r75, r50, ref20, ref10};
}

/// Pre-generated pellet positions (in inches relative to POI) with actual
/// counts inside the 10" and 20" circles.
class PelletLayout {
  final List<Offset> positions;
  final int in10Circle;
  final int in20Circle;

  const PelletLayout({
    required this.positions,
    required this.in10Circle,
    required this.in20Circle,
  });

  /// Generate deterministic pellet positions from a [PatternResult].
  /// Positions are in inches relative to POI center.
  factory PelletLayout.fromResult(PatternResult result) {
    final rng = Random(result.hashCode);
    final count = min(result.totalPellets, 500);
    final rSpread = result.spreadDiameterInches / 2;
    final r75 = result.r75Inches;
    final r50 = result.r50Inches;

    final nR50 = (count * 0.50).round();
    final nR75 = (count * 0.25).round();
    final nOuter = max(count - nR50 - nR75, 1);

    final positions = <Offset>[];

    void place(int n, double innerR, double outerR) {
      for (var i = 0; i < n; i++) {
        final angle = rng.nextDouble() * 2 * pi;
        final r = sqrt(
          innerR * innerR +
              rng.nextDouble() * (outerR * outerR - innerR * innerR),
        );
        positions.add(Offset(r * cos(angle), r * sin(angle)));
      }
    }

    place(nR50, 0, r50);
    place(nR75, r50, r75);
    place(nOuter - 1, r75, rSpread);

    // Edge pellet
    final edgeAngle = rng.nextDouble() * 2 * pi;
    final edgeR = rSpread * (0.90 + rng.nextDouble() * 0.08);
    positions.add(Offset(edgeR * cos(edgeAngle), edgeR * sin(edgeAngle)));

    // Count pellets relative to POI (positions are already POI-relative)
    int in10 = 0, in20 = 0;
    for (final p in positions) {
      final d = p.distance;
      if (d <= 5.0) in10++;
      if (d <= 10.0) in20++;
    }

    return PelletLayout(
      positions: positions,
      in10Circle: in10,
      in20Circle: in20,
    );
  }
}

/// Visualizes a shotgun pattern as concentric circles with random pellet dots
/// drawn from a Rayleigh distribution approximation.
class PatternPainter extends CustomPainter {
  final PatternResult result;
  final Set<String> visibleCircles;
  final PelletLayout pelletLayout;

  PatternPainter({
    required this.result,
    required this.pelletLayout,
    Set<String>? visibleCircles,
  }) : visibleCircles = visibleCircles ?? PatternCircle.all;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Scale: fit the spread diameter into the available space with some margin.
    final spreadRadius = result.spreadDiameterInches / 2;
    if (spreadRadius <= 0) return;

    final margin = 24.0;
    final availableRadius = (min(size.width, size.height) / 2) - margin;
    final scale = availableRadius / spreadRadius; // pixels per inch

    // ── Draw reference circles ──

    // Spread edge (outermost)
    if (visibleCircles.contains(PatternCircle.spread)) {
      _drawCircle(
        canvas,
        center,
        spreadRadius * scale,
        Colors.red.withValues(alpha: 0.3),
        strokeWidth: 1.5,
      );
      _drawLabel(
        canvas,
        center,
        spreadRadius * scale,
        '${result.spreadDiameterInches.toStringAsFixed(1)}" spread',
        Colors.red.withValues(alpha: 0.7),
      );
    }

    // R75 ring
    if (visibleCircles.contains(PatternCircle.r75)) {
      _drawCircle(
        canvas,
        center,
        result.r75Inches * scale,
        Colors.amber.withValues(alpha: 0.4),
      );
      _drawLabel(
        canvas,
        center,
        result.r75Inches * scale,
        'R75 ${result.r75Inches.toStringAsFixed(1)}"',
        Colors.amber.withValues(alpha: 0.7),
      );
    }

    // R50 ring
    if (visibleCircles.contains(PatternCircle.r50)) {
      _drawCircle(
        canvas,
        center,
        result.r50Inches * scale,
        Colors.green.withValues(alpha: 0.5),
      );
      _drawLabel(
        canvas,
        center,
        result.r50Inches * scale,
        'R50 ${result.r50Inches.toStringAsFixed(1)}"',
        Colors.green.withValues(alpha: 0.8),
      );
    }

    // 20" reference circle
    final r20px = 10.0 * scale;
    if (r20px < availableRadius &&
        visibleCircles.contains(PatternCircle.ref20)) {
      _drawCircle(
        canvas,
        center,
        r20px,
        Colors.white.withValues(alpha: 0.15),
        dashed: true,
      );
      _drawLabel(canvas, center, r20px, '20"', Colors.white38);
    }

    // 10" reference circle
    final r10px = 5.0 * scale;
    if (r10px < availableRadius &&
        visibleCircles.contains(PatternCircle.ref10)) {
      _drawCircle(
        canvas,
        center,
        r10px,
        Colors.white.withValues(alpha: 0.2),
        dashed: true,
      );
      _drawLabel(canvas, center, r10px, '10"', Colors.white38);
    }

    // ── POI offset crosshair ──
    final poiCenter = Offset(
      center.dx + result.poiOffsetXInches * scale,
      center.dy - result.poiOffsetYInches * scale, // Y inverted for screen
    );
    final crossSize = 8.0;
    final crossPaint = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 2.0;
    canvas.drawLine(
      poiCenter.translate(-crossSize, 0),
      poiCenter.translate(crossSize, 0),
      crossPaint,
    );
    canvas.drawLine(
      poiCenter.translate(0, -crossSize),
      poiCenter.translate(0, crossSize),
      crossPaint,
    );

    // ── Point-of-aim crosshair (center) ──
    final aimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      center.translate(-crossSize, 0),
      center.translate(crossSize, 0),
      aimPaint,
    );
    canvas.drawLine(
      center.translate(0, -crossSize),
      center.translate(0, crossSize),
      aimPaint,
    );

    // ── Draw pellet dots from pre-generated layout ──
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    for (final p in pelletLayout.positions) {
      final px = poiCenter.dx + p.dx * scale;
      final py = poiCenter.dy - p.dy * scale;
      canvas.drawCircle(Offset(px, py), 2.5, dotPaint);
    }
  }

  void _drawCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Color color, {
    double strokeWidth = 1.0,
    bool dashed = false,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    if (!dashed) {
      canvas.drawCircle(center, radius, paint);
      return;
    }

    // Approximate dashed circle with arc segments
    const dashCount = 40;
    const dashAngle = (2 * pi) / dashCount;
    const gapFraction = 0.3;
    for (var i = 0; i < dashCount; i++) {
      final start = i * dashAngle;
      final sweep = dashAngle * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
    }
  }

  void _drawLabel(
    Canvas canvas,
    Offset center,
    double radius,
    String text,
    Color color,
  ) {
    final span = TextSpan(
      text: text,
      style: TextStyle(color: color, fontSize: 10),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
      ..layout();

    // Place label at the top of the circle
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - radius - tp.height - 2),
    );
  }

  @override
  bool shouldRepaint(covariant PatternPainter old) =>
      old.result != result ||
      old.visibleCircles != visibleCircles ||
      old.pelletLayout != pelletLayout;
}
