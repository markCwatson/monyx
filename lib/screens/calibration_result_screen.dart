import 'dart:math';
import 'dart:ui' show Offset;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/shotgun_pattern_cubit.dart';
import '../models/calibration_session.dart';
import '../models/pattern_result.dart';
import '../models/shotgun_setup.dart';
import '../widgets/calibration_preview_painter.dart';

/// Shows the result of a calibration photo analysis.
///
/// Displays detected pellet positions, before/after pattern comparisons,
/// and lets the user accept or discard the calibration. The user can tap
/// detected pellets to remove false positives, or tap empty space to add
/// missed pellets.
class CalibrationResultScreen extends StatefulWidget {
  final CalibrationSession session;
  final PatternResult before;
  final PatternResult after;
  final ShotgunSetup setup;
  final double distanceYards;

  const CalibrationResultScreen({
    super.key,
    required this.session,
    required this.before,
    required this.after,
    required this.setup,
    required this.distanceYards,
  });

  @override
  State<CalibrationResultScreen> createState() =>
      _CalibrationResultScreenState();
}

class _CalibrationResultScreenState extends State<CalibrationResultScreen> {
  late CalibrationSession _session;
  late PatternResult _after;
  late List<Offset> _detectedPellets;
  final List<Offset> _addedPellets = [];
  int? _selectedIndex;
  bool _edited = false;
  bool _addMode = false;

  /// Key for the preview area so we can find its RenderBox for hit-testing.
  final _previewKey = GlobalKey();

  static const _sheetInches = 24.0;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _after = widget.after;
    _detectedPellets = List<Offset>.from(widget.session.pelletCoordinates);
  }

  void _rebuildSession() {
    _session = widget.session.copyWithPellets([
      ..._detectedPellets,
      ..._addedPellets,
    ], widget.setup.pelletCount);
  }

  /// Convert a screen tap position to inches relative to sheet center.
  Offset? _tapToInches(Offset localPosition) {
    final box = _previewKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final size = box.size;
    final side = min(size.width, size.height);
    final scale = side / _sheetInches;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final dx = (localPosition.dx - cx) / scale;
    final dy = -(localPosition.dy - cy) / scale; // Y inverted
    // Clamp to sheet bounds
    final half = _sheetInches / 2;
    if (dx.abs() > half || dy.abs() > half) return null;
    return Offset(dx, dy);
  }

  /// Find the index of the nearest pellet within a tap radius.
  /// Returns ≥ 0 for detected pellets, < 0 (-(i+1)) for added pellets.
  int? _hitTestPellet(Offset localPosition) {
    final box = _previewKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final size = box.size;
    final side = min(size.width, size.height);
    final scale = side / _sheetInches;
    final cx = size.width / 2;
    final cy = size.height / 2;

    const hitRadiusPx = 20.0;
    int? closest;
    double closestDist = double.infinity;

    for (var i = 0; i < _detectedPellets.length; i++) {
      final p = _detectedPellets[i];
      final px = cx + p.dx * scale;
      final py = cy - p.dy * scale;
      final d = (Offset(px, py) - localPosition).distance;
      if (d < closestDist) {
        closestDist = d;
        closest = i;
      }
    }

    for (var i = 0; i < _addedPellets.length; i++) {
      final p = _addedPellets[i];
      final px = cx + p.dx * scale;
      final py = cy - p.dy * scale;
      final d = (Offset(px, py) - localPosition).distance;
      if (d < closestDist) {
        closestDist = d;
        closest = -(i + 1);
      }
    }

    if (closestDist <= hitRadiusPx) return closest;
    return null;
  }

  void _onTapDown(TapDownDetails details) {
    final localPos = details.localPosition;

    if (_addMode) {
      // In add mode, always place a new pellet
      final inches = _tapToInches(localPos);
      if (inches != null) {
        setState(() {
          _addedPellets.add(inches);
          _selectedIndex = null;
          _edited = true;
          _rebuildSession();
        });
        _recalculate();
      }
      return;
    }

    // In select mode, tap pellets to select/remove
    final hitIdx = _hitTestPellet(localPos);

    if (hitIdx != null) {
      if (_selectedIndex == hitIdx) {
        _removePellet(hitIdx);
      } else {
        setState(() => _selectedIndex = hitIdx);
      }
    } else {
      // Tap on empty space — deselect
      setState(() => _selectedIndex = null);
    }
  }

  void _removePellet(int index) {
    setState(() {
      if (index >= 0) {
        _detectedPellets.removeAt(index);
      } else {
        _addedPellets.removeAt(-(index + 1));
      }
      _selectedIndex = null;
      _edited = true;
      _rebuildSession();
    });
    _recalculate();
  }

  Future<void> _recalculate() async {
    final after = await context.read<ShotgunPatternCubit>().previewCalibration(
      session: _session,
      setup: widget.setup,
      distanceYards: widget.distanceYards,
    );
    if (mounted) setState(() => _after = after);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Calibration Result'),
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Mode toggle + pellets preview ──
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  // Add / Select mode toggle
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _modeButton(
                          icon: Icons.touch_app,
                          label: 'Select',
                          active: !_addMode,
                          onTap: () => setState(() {
                            _addMode = false;
                            _selectedIndex = null;
                          }),
                        ),
                        const SizedBox(width: 8),
                        _modeButton(
                          icon: Icons.add_circle_outline,
                          label: 'Add',
                          active: _addMode,
                          onTap: () => setState(() {
                            _addMode = true;
                            _selectedIndex = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: GestureDetector(
                        onTapDown: _onTapDown,
                        child: CustomPaint(
                          key: _previewKey,
                          painter: CalibrationPreviewPainter(
                            session: _session,
                            detectedPellets: _detectedPellets,
                            addedPellets: _addedPellets,
                            selectedIndex: _selectedIndex,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Metrics comparison ──
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Editing hint
                      if (!_edited)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Use Select mode to tap a pellet twice to remove it. '
                            'Use Add mode to tap where missed pellets should be.',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),

                      // Delete button for selected pellet
                      if (_selectedIndex != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text('Remove selected pellet'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                              ),
                              onPressed: () => _removePellet(_selectedIndex!),
                            ),
                          ),
                        ),

                      // Detection summary
                      _sectionHeader('Detection'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _pill(
                            'Pellets found',
                            '${_session.detectedPelletCount}',
                          ),
                          _pill('Expected', '${widget.setup.pelletCount}'),
                          _pill(
                            'Confidence',
                            '${(_session.sessionConfidence * 100).round()}%',
                          ),
                          if (_session.clippingLikelihood > 0.05)
                            _pill(
                              'Clipping',
                              '${(_session.clippingLikelihood * 100).round()}%',
                              color: Colors.red,
                            ),
                          if (_edited)
                            _pill('Edited', 'Yes', color: Colors.amber),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Before / After comparison
                      _sectionHeader('Pattern Comparison'),
                      const SizedBox(height: 8),
                      _comparisonRow(
                        'Spread',
                        '${widget.before.spreadDiameterInches.toStringAsFixed(1)}"',
                        '${_after.spreadDiameterInches.toStringAsFixed(1)}"',
                      ),
                      _comparisonRow(
                        'R50',
                        '${widget.before.r50Inches.toStringAsFixed(1)}"',
                        '${_after.r50Inches.toStringAsFixed(1)}"',
                      ),
                      _comparisonRow(
                        'R75',
                        '${widget.before.r75Inches.toStringAsFixed(1)}"',
                        '${_after.r75Inches.toStringAsFixed(1)}"',
                      ),
                      _comparisonRow(
                        '10" circle',
                        '${widget.before.pelletsIn10Circle}',
                        '${_after.pelletsIn10Circle}',
                      ),
                      _comparisonRow(
                        '20" circle',
                        '${widget.before.pelletsIn20Circle}',
                        '${_after.pelletsIn20Circle}',
                      ),
                      if (_session.poiOffsetXInches.abs() > 0.3 ||
                          _session.poiOffsetYInches.abs() > 0.3)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _pill(
                            'POI offset',
                            '${_session.poiOffsetXInches.toStringAsFixed(1)}" × ${_session.poiOffsetYInches.toStringAsFixed(1)}"',
                            color: Colors.orange,
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Accept / Discard buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white54,
                                side: const BorderSide(color: Colors.white24),
                              ),
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Discard'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Apply Calibration'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () {
                                context
                                    .read<ShotgunPatternCubit>()
                                    .acceptCalibration(
                                      session: _session,
                                      setup: widget.setup,
                                      distanceYards: widget.distanceYards,
                                    );
                                Navigator.of(context).pop(true);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeButton({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white12 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? Colors.white38 : Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? Colors.white : Colors.white38),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white38,
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _pill(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (color ?? Colors.white).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _comparisonRow(String label, String beforeVal, String afterVal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              beforeVal,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ),
          const Icon(Icons.arrow_forward, color: Colors.white24, size: 14),
          Expanded(
            child: Text(
              afterVal,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
