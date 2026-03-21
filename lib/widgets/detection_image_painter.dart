import 'package:flutter/material.dart';

import '../models/detection.dart';
import '../models/track_result.dart';

/// Draws bounding boxes with species labels over a track photo.
class DetectionImagePainter extends CustomPainter {
  final List<Detection> detections;
  final int imageWidth;
  final int imageHeight;

  DetectionImagePainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    debugPrint(
      '[DetectionPainter] paint called. canvasSize=$size, imageSize=${imageWidth}x$imageHeight, detections=${detections.length}',
    );

    if (size.width == 0 || size.height == 0) {
      debugPrint('[DetectionPainter] ZERO canvas size — skipping paint');
      return;
    }

    // Calculate the display rect of the image within the container
    // (matches BoxFit.contain behaviour).
    final imageAspect = imageWidth / imageHeight;
    final containerAspect = size.width / size.height;

    double displayW, displayH, offsetX, offsetY;
    if (imageAspect > containerAspect) {
      displayW = size.width;
      displayH = displayW / imageAspect;
      offsetX = 0;
      offsetY = (size.height - displayH) / 2;
    } else {
      displayH = size.height;
      displayW = displayH * imageAspect;
      offsetX = (size.width - displayW) / 2;
      offsetY = 0;
    }

    final scaleX = displayW / imageWidth;
    final scaleY = displayH / imageHeight;

    debugPrint(
      '[DetectionPainter] display=${displayW.toInt()}x${displayH.toInt()} offset=(${offsetX.toInt()},${offsetY.toInt()}) scale=($scaleX,$scaleY)',
    );

    for (final det in detections) {
      final color = _colorForConfidence(det.confidence);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      final rect = Rect.fromLTRB(
        offsetX + det.x1 * scaleX,
        offsetY + det.y1 * scaleY,
        offsetX + det.x2 * scaleX,
        offsetY + det.y2 * scaleY,
      );

      // Draw box
      canvas.drawRect(rect, paint);

      // Draw label background
      final label =
          '${TrackResult.formatSpeciesName(det.className)} ${(det.confidence * 100).toStringAsFixed(0)}%';
      final textSpan = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout();

      final bgRect = Rect.fromLTWH(
        rect.left,
        rect.top - tp.height - 4,
        tp.width + 8,
        tp.height + 4,
      );
      canvas.drawRect(bgRect, Paint()..color = color.withAlpha(200));
      tp.paint(canvas, Offset(rect.left + 4, rect.top - tp.height - 2));
    }
  }

  Color _colorForConfidence(double conf) {
    if (conf >= 0.7) return Colors.green;
    if (conf >= 0.4) return Colors.amber;
    return Colors.red;
  }

  @override
  bool shouldRepaint(DetectionImagePainter oldDelegate) =>
      oldDelegate.detections != detections;
}
