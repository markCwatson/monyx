import 'package:flutter/material.dart';

import '../models/pattern_result.dart';

/// Bottom-sheet solution card for shotgun pattern results on the map.
/// Styled to match [SolutionCard] for rifle ballistics.
class PatternCard extends StatelessWidget {
  final PatternResult result;
  final VoidCallback onDismiss;
  final VoidCallback? onExpand; // navigate to full PatternResultScreen
  final VoidCallback? onDelete;

  const PatternCard({
    super.key,
    required this.result,
    required this.onDismiss,
    this.onExpand,
    this.onDelete,
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
                  'PATTERN ESTIMATE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onDelete != null) ...[
                      GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.red[800],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    GestureDetector(
                      onTap: onDismiss,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Range
            Text(
              '${result.distanceYards.round()} yds',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const Divider(color: Colors.grey, height: 24),

            // Spread zone
            _metricRow(
              icon: Icons.blur_circular,
              label: 'Spread',
              children: [
                _valuePill(
                  '${result.spreadDiameterInches.toStringAsFixed(1)}"',
                ),
                _valuePill(
                  'R50 ${result.r50Inches.toStringAsFixed(1)}"',
                  color: Colors.green,
                ),
                _valuePill(
                  'R75 ${result.r75Inches.toStringAsFixed(1)}"',
                  color: Colors.amber,
                ),
              ],
            ),
            const Divider(color: Colors.grey, height: 24),

            // Pellet density
            _metricRow(
              icon: Icons.grain,
              label: 'Pellet density',
              children: [
                _valuePill('${result.pelletsIn10Circle} in 10"'),
                _valuePill('${result.pelletsIn20Circle} in 20"'),
                _valuePill('${result.totalPellets} total'),
              ],
            ),
            const Divider(color: Colors.grey, height: 24),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _infoChip(
                  '10" %',
                  '${(result.pelletsIn10Circle / result.totalPellets * 100).round()}%',
                ),
                _infoChip(
                  '20" %',
                  '${(result.pelletsIn20Circle / result.totalPellets * 100).round()}%',
                ),
                if (result.isCalibrated &&
                    (result.poiOffsetXInches.abs() > 0.1 ||
                        result.poiOffsetYInches.abs() > 0.1))
                  _infoChip(
                    'POI',
                    '${result.poiOffsetXInches.toStringAsFixed(1)}" × ${result.poiOffsetYInches.toStringAsFixed(1)}"',
                  ),
              ],
            ),

            // Expand button
            if (onExpand != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  icon: const Icon(Icons.fullscreen, size: 18),
                  label: const Text('Full Pattern View'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.orangeAccent,
                  ),
                  onPressed: onExpand,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricRow({
    required IconData icon,
    required String label,
    required List<Widget> children,
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
          children: children,
        ),
      ],
    );
  }

  Widget _valuePill(String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.15) ?? Colors.grey[800],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? Colors.white,
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
}
