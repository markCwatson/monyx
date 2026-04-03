import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import 'map_line_projector.dart';

/// Animated pellet spray from shooter → target that fans out in a cone
/// matching the shotgun spread pattern. Pellet count matches the profile.
class PelletSprayOverlay extends StatefulWidget {
  final MapboxMap mapboxMap;
  final double shooterLat;
  final double shooterLon;
  final double targetLat;
  final double targetLon;
  final int pelletCount;
  final double spreadDiameterInches;
  final double distanceYards;

  const PelletSprayOverlay({
    super.key,
    required this.mapboxMap,
    required this.shooterLat,
    required this.shooterLon,
    required this.targetLat,
    required this.targetLon,
    required this.pelletCount,
    required this.spreadDiameterInches,
    required this.distanceYards,
  });

  @override
  State<PelletSprayOverlay> createState() => _PelletSprayOverlayState();
}

class _PelletSprayOverlayState extends State<PelletSprayOverlay>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _t = 0;

  Offset? _shooterScreen;
  Offset? _targetScreen;
  bool _projecting = false;

  /// Pre-computed per-pellet random offsets (lateral fraction -1..1).
  /// Generated once using Rayleigh-like distribution so more pellets
  /// cluster near centre.
  late final List<double> _pelletOffsets;

  /// Slight per-pellet speed variation so they don't all land at once.
  late final List<double> _pelletSpeedVar;

  /// Flight duration in seconds.
  static const _flightDuration = 1.2;

  /// Pause between volleys.
  static const _pauseDuration = 0.8;

  /// Max pellets rendered (perf cap).
  static const _maxRendered = 80;

  @override
  void initState() {
    super.initState();
    _initPellets();
    _ticker = createTicker(_onTick)..start();
    _projectCoordinates();
  }

  void _initPellets() {
    final rng = Random(42); // deterministic for same profile
    final count = widget.pelletCount.clamp(1, _maxRendered);
    // Rayleigh-distributed lateral offsets: more pellets near centre
    _pelletOffsets = List.generate(count, (_) {
      // Rayleigh sample mapped to -1..1
      final u = rng.nextDouble();
      final r = sqrt(-2 * log(1 - u * 0.95)) / 2.0; // σ≈0.5
      final sign = rng.nextBool() ? 1.0 : -1.0;
      return (r * sign).clamp(-1.0, 1.0);
    });
    _pelletSpeedVar = List.generate(count, (_) {
      return 0.85 + rng.nextDouble() * 0.30; // 0.85–1.15
    });
  }

  @override
  void didUpdateWidget(PelletSprayOverlay old) {
    super.didUpdateWidget(old);
    if (old.pelletCount != widget.pelletCount) _initPellets();
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
      final result = await MapLineProjector.project(
        widget.mapboxMap,
        shooterLat: widget.shooterLat,
        shooterLon: widget.shooterLon,
        targetLat: widget.targetLat,
        targetLon: widget.targetLon,
      );
      if (mounted && result != null) {
        _shooterScreen = result.$1;
        _targetScreen = result.$2;
      } else if (mounted) {
        _shooterScreen = null;
        _targetScreen = null;
      }
    } catch (_) {}
    _projecting = false;
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    _projectCoordinates();

    _t += dt / (_flightDuration + _pauseDuration);
    if (_t >= 1.0) _t -= 1.0;

    if (mounted) (context as Element).markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _PelletSprayPainter(
            shooterScreen: _shooterScreen,
            targetScreen: _targetScreen,
            pelletOffsets: _pelletOffsets,
            pelletSpeedVar: _pelletSpeedVar,
            spreadDiameterInches: widget.spreadDiameterInches,
            distanceYards: widget.distanceYards,
            t: _t,
            flightFraction:
                _flightDuration / (_flightDuration + _pauseDuration),
          ),
        ),
      ),
    );
  }
}

class _PelletSprayPainter extends CustomPainter {
  final Offset? shooterScreen;
  final Offset? targetScreen;
  final List<double> pelletOffsets;
  final List<double> pelletSpeedVar;
  final double spreadDiameterInches;
  final double distanceYards;
  final double t;
  final double flightFraction;

  _PelletSprayPainter({
    required this.shooterScreen,
    required this.targetScreen,
    required this.pelletOffsets,
    required this.pelletSpeedVar,
    required this.spreadDiameterInches,
    required this.distanceYards,
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
    if (lineLen < 10) return;

    final dir = lineVec / lineLen;
    final perp = Offset(dir.dy, -dir.dx);

    // In the pause gap — nothing to draw
    if (t > flightFraction) return;
    final bt = t / flightFraction; // 0–1 within flight

    // Half-spread in screen px at the target distance (with visual scaling)
    final rangeInches = distanceYards * 36.0;
    final realHalf = rangeInches > 0
        ? (spreadDiameterInches / 2) / rangeInches * lineLen
        : 20.0;
    final floor = max(30.0, lineLen * 0.08);
    final halfSpread = max(realHalf, floor);

    for (var i = 0; i < pelletOffsets.length; i++) {
      // Per-pellet progress adjusted by speed variation
      final pelletT = (bt * pelletSpeedVar[i]).clamp(0.0, 1.0);

      // Position along the centre line
      final pos = A + lineVec * pelletT;

      // Lateral offset grows linearly from 0 at shooter to full at target
      final lateralPx = pelletOffsets[i] * halfSpread * pelletT;
      final finalPos = pos + perp * lateralPx;

      // Fade in at start, full mid-flight, fade at end
      final alpha = pelletT < 0.1
          ? pelletT / 0.1
          : pelletT > 0.85
          ? (1.0 - pelletT) / 0.15
          : 1.0;

      final paint = Paint()
        ..color = Colors.orangeAccent.withValues(
          alpha: (alpha * 0.8).clamp(0.0, 1.0),
        );

      // Pellet size: small dot
      canvas.drawCircle(finalPos, 2.0, paint);
    }
  }

  @override
  bool shouldRepaint(_PelletSprayPainter old) => true;
}
