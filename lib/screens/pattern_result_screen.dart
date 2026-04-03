import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';

import '../blocs/shotgun_pattern_cubit.dart';
import '../blocs/subscription_cubit.dart';
import '../models/pattern_result.dart';
import '../models/shotgun_setup.dart';
import '../widgets/pattern_painter.dart';
import 'calibration_result_screen.dart';

class PatternResultScreen extends StatefulWidget {
  final PatternResult initialResult;
  final ShotgunSetup setup;

  const PatternResultScreen({
    super.key,
    required this.initialResult,
    required this.setup,
  });

  @override
  State<PatternResultScreen> createState() => _PatternResultScreenState();
}

class _PatternResultScreenState extends State<PatternResultScreen> {
  late double _distanceYards;
  late Set<String> _visibleCircles;

  static const _minDistance = 5.0;
  static const _maxDistance = 100.0;

  static const _hiveBoxName = 'pattern_prefs';
  static const _hiveKey = 'hidden_circles';

  @override
  void initState() {
    super.initState();
    _distanceYards = widget.initialResult.distanceYards.clamp(
      _minDistance,
      _maxDistance,
    );
    _visibleCircles = Set<String>.from(PatternCircle.all);
    _loadCirclePrefs();
  }

  Future<void> _loadCirclePrefs() async {
    final box = await Hive.openBox<List<String>>(_hiveBoxName);
    final hidden = box.get(_hiveKey);
    if (hidden != null && hidden.isNotEmpty) {
      setState(() {
        _visibleCircles = Set<String>.from(PatternCircle.all)
          ..removeAll(hidden);
      });
    }
  }

  Future<void> _saveCirclePrefs() async {
    final box = await Hive.openBox<List<String>>(_hiveBoxName);
    final hidden = PatternCircle.all
        .where((c) => !_visibleCircles.contains(c))
        .toList();
    await box.put(_hiveKey, hidden);
  }

  void _toggleCircle(String circleId) {
    setState(() {
      final updated = Set<String>.from(_visibleCircles);
      if (updated.contains(circleId)) {
        updated.remove(circleId);
      } else {
        updated.add(circleId);
      }
      _visibleCircles = updated;
    });
    _saveCirclePrefs();
  }

  void _onDistanceChanged(double value) {
    setState(() => _distanceYards = value);
    context.read<ShotgunPatternCubit>().predict(
      setup: widget.setup,
      distanceYards: value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Pattern Estimate'),
        backgroundColor: Colors.grey[850],
        foregroundColor: Colors.white,
      ),
      body: BlocListener<ShotgunPatternCubit, ShotgunPatternState>(
        listener: (context, state) {
          if (state is CalibrationReady) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<ShotgunPatternCubit>(),
                  child: CalibrationResultScreen(
                    session: state.session,
                    before: state.before,
                    after: state.after,
                    setup: state.setup,
                    distanceYards: _distanceYards,
                  ),
                ),
              ),
            );
          } else if (state is CalibrationError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: BlocBuilder<ShotgunPatternCubit, ShotgunPatternState>(
          builder: (context, state) {
            final result = state is PatternReady
                ? state.result
                : widget.initialResult;
            final layout = PelletLayout.fromResult(result);

            return Column(
              children: [
                // ── Pattern visualization ──
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: CustomPaint(
                      painter: PatternPainter(
                        result: result,
                        pelletLayout: layout,
                        visibleCircles: _visibleCircles,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),

                // ── Metrics card ──
                Expanded(
                  flex: 2,
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
                          // Load summary
                          Text(
                            '${widget.setup.gauge.label}  ·  ${widget.setup.chokeType.label}  ·  ${widget.setup.shotSize.label}  ·  ${widget.setup.gameTarget.label}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Distance slider
                          Row(
                            children: [
                              const Icon(
                                Icons.straighten,
                                color: Colors.white54,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_distanceYards.round()} yds',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              _badge(
                                result.isCalibrated
                                    ? 'CALIBRATED'
                                    : 'ESTIMATED',
                                result.isCalibrated
                                    ? Colors.green
                                    : Colors.amber,
                              ),
                            ],
                          ),
                          Slider(
                            value: _distanceYards,
                            min: _minDistance,
                            max: _maxDistance,
                            divisions: (_maxDistance - _minDistance).round(),
                            activeColor: Colors.orangeAccent,
                            inactiveColor: Colors.white24,
                            label: '${_distanceYards.round()} yds',
                            onChanged: _onDistanceChanged,
                          ),

                          const SizedBox(height: 8),

                          // Metrics
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _togglePill(
                                'Spread',
                                '${result.spreadDiameterInches.toStringAsFixed(1)}"',
                                PatternCircle.spread,
                              ),
                              _togglePill(
                                'R50',
                                '${result.r50Inches.toStringAsFixed(1)}"',
                                PatternCircle.r50,
                              ),
                              _togglePill(
                                'R75',
                                '${result.r75Inches.toStringAsFixed(1)}"',
                                PatternCircle.r75,
                              ),
                              _togglePill(
                                '10" circle',
                                '${layout.in10Circle} pellets',
                                PatternCircle.ref10,
                              ),
                              _togglePill(
                                '20" circle',
                                '${layout.in20Circle} pellets',
                                PatternCircle.ref20,
                              ),
                              if (result.isCalibrated &&
                                  (result.poiOffsetXInches.abs() > 0.1 ||
                                      result.poiOffsetYInches.abs() > 0.1))
                                _metricPill(
                                  'POI offset',
                                  '${result.poiOffsetXInches.toStringAsFixed(1)}" × ${result.poiOffsetYInches.toStringAsFixed(1)}"',
                                ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Calibrate button (Pro-gated)
                          SizedBox(
                            width: double.infinity,
                            child: _CalibrateButton(setup: widget.setup),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _togglePill(String label, String value, String circleId) {
    final active = _visibleCircles.contains(circleId);
    return GestureDetector(
      onTap: () => _toggleCircle(circleId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Colors.grey[800]
              : Colors.grey[800]!.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: active ? null : Border.all(color: Colors.white24, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                color: active ? Colors.white : Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white54 : Colors.white24,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
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

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _CalibrateButton extends StatelessWidget {
  final ShotgunSetup setup;
  const _CalibrateButton({required this.setup});

  Future<void> _pickAndAnalyze(BuildContext context) async {
    // Show instructions first — returns the chosen image source or null
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.grey[850],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CalibrationInstructions(),
    );
    if (source == null || !context.mounted) return;

    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (xFile == null || !context.mounted) return;

    final cubit = context.read<ShotgunPatternCubit>();
    final state = cubit.state;
    final distance = state is PatternReady ? state.result.distanceYards : 20.0;

    cubit.analyzePhoto(
      imageFile: File(xFile.path),
      setup: setup,
      distanceYards: distance,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPro = context.watch<SubscriptionCubit>().isPro;
    final isAnalyzing =
        context.watch<ShotgunPatternCubit>().state is CalibrationAnalyzing;

    if (isAnalyzing) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.orangeAccent),
              SizedBox(height: 8),
              Text(
                'Analyzing pattern...',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      icon: Icon(isPro ? Icons.camera_alt : Icons.lock, size: 18),
      label: const Text('Calibrate from Photo'),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPro ? Colors.orangeAccent : Colors.grey[700],
        foregroundColor: isPro ? Colors.black : Colors.white54,
      ),
      onPressed: isPro
          ? () => _pickAndAnalyze(context)
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Upgrade to Pro to calibrate'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
    );
  }
}

class _CalibrationInstructions extends StatelessWidget {
  const _CalibrationInstructions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              'Calibration Setup',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _step('1', 'Tape a 24" × 24" white sheet to your backstop'),
          _step('2', 'Fire one shot from exactly 20 yards'),
          _step('3', 'Take a photo of the full sheet straight-on'),
          const SizedBox(height: 8),
          const Text(
            'Ensure the entire sheet is visible with good contrast. '
            'The app will detect the page edges and pellet holes automatically.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: const Text('Photos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  onPressed: () =>
                      Navigator.of(context).pop(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Take Photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () =>
                      Navigator.of(context).pop(ImageSource.camera),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static Widget _step(String num, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.orangeAccent,
            child: Text(
              num,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
