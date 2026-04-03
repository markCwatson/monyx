import 'dart:math';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

/// Draws a red dotted circle around the user's position on the map
/// representing the lethal effective range of the current shotgun profile.
///
/// Projects only the centre and one edge point to screen space, then draws
/// a screen-space circle. This works at every zoom level (projecting many
/// perimeter points breaks when zoomed in because off-screen coordinates
/// produce degenerate geometry).
class LethalRangeOverlay extends StatefulWidget {
  final MapboxMap mapboxMap;
  final double centerLat;
  final double centerLon;

  /// Lethal range in yards.
  final double rangeYards;

  /// Display label for the game being hunted.
  final String gameLabel;

  const LethalRangeOverlay({
    super.key,
    required this.mapboxMap,
    required this.centerLat,
    required this.centerLon,
    required this.rangeYards,
    required this.gameLabel,
  });

  @override
  State<LethalRangeOverlay> createState() => _LethalRangeOverlayState();
}

class _LethalRangeOverlayState extends State<LethalRangeOverlay> {
  Offset? _centerScreen;
  double? _radiusPx;
  bool _projecting = false;

  @override
  void initState() {
    super.initState();
    _project();
  }

  @override
  void didUpdateWidget(LethalRangeOverlay old) {
    super.didUpdateWidget(old);
    _project();
  }

  Future<void> _project() async {
    if (_projecting) return;
    _projecting = true;
    try {
      // Compute a point due north at the lethal range
      final rangeMetres = widget.rangeYards * 0.9144;
      const R = 6371000.0;
      final lat0 = widget.centerLat * pi / 180;
      // Destination bearing 0 (north): lat2 = asin(sin(lat0)*cos(d/R) + cos(lat0)*sin(d/R))
      final edgeLat = asin(
        sin(lat0) * cos(rangeMetres / R) + cos(lat0) * sin(rangeMetres / R),
      );
      final edgeLon = widget.centerLon; // due north → same longitude

      final results = await Future.wait([
        widget.mapboxMap.pixelForCoordinate(
          Point(coordinates: Position(widget.centerLon, widget.centerLat)),
        ),
        widget.mapboxMap.pixelForCoordinate(
          Point(coordinates: Position(edgeLon, edgeLat * 180 / pi)),
        ),
      ]);

      if (mounted) {
        final cPx = Offset(results[0].x, results[0].y);
        final ePx = Offset(results[1].x, results[1].y);
        setState(() {
          _centerScreen = cPx;
          _radiusPx = (ePx - cPx).distance;
        });
      }
    } catch (_) {}
    _projecting = false;
  }

  @override
  Widget build(BuildContext context) {
    _project(); // re-project on every build to follow map pan/zoom
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _LethalRangePainter(
            centerScreen: _centerScreen,
            radiusPx: _radiusPx,
            rangeYards: widget.rangeYards,
            gameLabel: widget.gameLabel,
          ),
        ),
      ),
    );
  }
}

class _LethalRangePainter extends CustomPainter {
  final Offset? centerScreen;
  final double? radiusPx;
  final double rangeYards;
  final String gameLabel;

  _LethalRangePainter({
    required this.centerScreen,
    required this.radiusPx,
    required this.rangeYards,
    required this.gameLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (centerScreen == null || radiusPx == null || radiusPx! < 2) return;

    final c = centerScreen!;
    final r = radiusPx!;

    // Semi-transparent red fill
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = Colors.red.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill,
    );

    // Dashed red stroke via path metrics
    final circlePath = Path()..addOval(Rect.fromCircle(center: c, radius: r));

    final dashPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final metric = circlePath.computeMetrics().first;
    const dashOn = 8.0;
    const dashOff = 6.0;
    var distance = 0.0;
    var draw = true;
    while (distance < metric.length) {
      final len = draw ? dashOn : dashOff;
      final end = min(distance + len, metric.length);
      if (draw) {
        final segment = metric.extractPath(distance, end);
        canvas.drawPath(segment, dashPaint);
      }
      distance = end;
      draw = !draw;
    }

    // Label at top of circle
    final label = '${rangeYards.round()} yd effective ($gameLabel)';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.red.withValues(alpha: 0.85),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - r - tp.height - 4));
  }

  @override
  bool shouldRepaint(_LethalRangePainter old) => true;
}
