import 'package:flutter/material.dart';

import '../models/shot_solution.dart';
import '../models/weather_data.dart';

class SolutionCard extends StatelessWidget {
  final ShotSolution solution;
  final VoidCallback onDismiss;

  const SolutionCard({
    super.key,
    required this.solution,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TARGET SOLUTION',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                _weatherBadge(),
              ],
            ),
            const SizedBox(height: 4),
            // Range
            Text(
              '${solution.rangeYards.round()} yds',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const Divider(color: Colors.grey, height: 24),
            // Elevation
            _correctionRow(
              icon: Icons.swap_vert,
              label: 'Elevation',
              inches: solution.dropInches.abs(),
              moa: solution.dropMoa.abs(),
              clicks: solution.dropClicks.abs(),
              direction: solution.elevationDirection,
              directionColor: solution.dropInches < 0
                  ? Colors.orangeAccent
                  : Colors.cyan,
            ),
            const Divider(color: Colors.grey, height: 24),
            // Wind
            _correctionRow(
              icon: Icons.air,
              label:
                  'Wind (${solution.crosswindMph.abs().toStringAsFixed(1)} mph ${solution.crosswindMph >= 0 ? "from L" : "from R"})',
              inches: solution.windDriftInches.abs(),
              moa: solution.windDriftMoa.abs(),
              clicks: solution.windDriftClicks.abs(),
              direction: solution.windDirection,
              directionColor: Colors.lightBlueAccent,
            ),
            const Divider(color: Colors.grey, height: 24),
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _infoChip(
                  'Angle',
                  '${solution.shotAngleDeg >= 0 ? "+" : ""}${solution.shotAngleDeg.toStringAsFixed(1)}°',
                ),
                _infoChip('DA', '${solution.densityAltitudeFt.round()} ft'),
                _infoChip('Vel', '${solution.velocityAtTargetFps.round()} fps'),
                _infoChip(
                  'TOF',
                  '${solution.timeOfFlightSec.toStringAsFixed(2)}s',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _correctionRow({
    required IconData icon,
    required String label,
    required double inches,
    required double moa,
    required int clicks,
    required String direction,
    required Color directionColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white54, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _valuePill('${inches.toStringAsFixed(1)}"'),
            _valuePill('${moa.toStringAsFixed(1)} MOA'),
            _valuePill('$clicks clicks'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: directionColor.withAlpha(40),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                direction.isEmpty ? '—' : direction,
                style: TextStyle(
                  color: directionColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _valuePill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    );
  }

  Widget _weatherBadge() {
    final Color color;
    final String label;
    switch (solution.weatherSource) {
      case WeatherSource.live:
        color = Colors.green;
        label = 'LIVE';
      case WeatherSource.cached:
        color = Colors.amber;
        label = 'CACHED';
      case WeatherSource.estimated:
        color = Colors.red;
        label = 'EST';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
