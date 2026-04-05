import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/calibration_session.dart';

/// Paints the detected pellet positions from a [CalibrationSession] overlaid
/// on the rectified target photo. Falls back to a schematic if no image is
/// provided.
///
/// Pellets from `detectedPellets` are drawn cyan. Pellets from `addedPellets`
/// are drawn green. [selectedIndex] ≥ 0 highlights a detected pellet;
/// selectedIndex < 0 highlights added pellet at index `-(selectedIndex+1)`.
class CalibrationPreviewPainter extends CustomPainter {
  final CalibrationSession session;
  final List<Offset> detectedPellets;
  final List<Offset> addedPellets;
  final int? selectedIndex;
  final ui.Image? backgroundImage;
  final double sheetSizeInches;

  CalibrationPreviewPainter({
    required this.session,
    required this.detectedPellets,
    this.addedPellets = const [],
    this.selectedIndex,
    this.backgroundImage,
    this.sheetSizeInches = 24.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final side = min(size.width, size.height);
    final scale = side / sheetSizeInches;
    final cx = size.width / 2;
    final cy = size.height / 2;

    final sheetRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: side,
      height: side,
    );

    // ── Background: rectified photo or schematic fallback ──
    if (backgroundImage != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        backgroundImage!.width.toDouble(),
        backgroundImage!.height.toDouble(),
      );
      canvas.drawImageRect(backgroundImage!, src, sheetRect, Paint());
      // Semi-transparent overlay for contrast
      canvas.drawRect(
        sheetRect,
        Paint()..color = Colors.black.withValues(alpha: 0.15),
      );
    } else {
      canvas.drawRect(
        sheetRect,
        Paint()
          ..color = Colors.white12
          ..style = PaintingStyle.fill,
      );
    }

    // ── Sheet border ──
    canvas.drawRect(
      sheetRect,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // ── Reference circles (10" and 20") ──
    final dashPaint = Paint()
      ..color = Colors.white30
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(cx, cy), 5.0 * scale, dashPaint);
    canvas.drawCircle(Offset(cx, cy), 10.0 * scale, dashPaint);

    // ── R50 circle ──
    canvas.drawCircle(
      Offset(cx, cy),
      session.measuredR50Inches * scale,
      Paint()
        ..color = Colors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // ── R75 circle ──
    canvas.drawCircle(
      Offset(cx, cy),
      session.measuredR75Inches * scale,
      Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // ── Detected pellet dots (cyan) ──
    final pelletPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;
    final selectedPaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;
    final selectedRing = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < detectedPellets.length; i++) {
      final p = detectedPellets[i];
      final px = cx + p.dx * scale;
      final py = cy - p.dy * scale;
      if (selectedIndex != null && selectedIndex! >= 0 && i == selectedIndex) {
        canvas.drawCircle(Offset(px, py), 3.5, selectedPaint);
        canvas.drawCircle(Offset(px, py), 7, selectedRing);
      } else {
        canvas.drawCircle(Offset(px, py), 2.5, pelletPaint);
      }
    }

    // ── Manually added pellets (green) ──
    final addedPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.fill;
    for (var i = 0; i < addedPellets.length; i++) {
      final p = addedPellets[i];
      final px = cx + p.dx * scale;
      final py = cy - p.dy * scale;
      final addedIdx = -(i + 1);
      if (selectedIndex != null && selectedIndex == addedIdx) {
        canvas.drawCircle(Offset(px, py), 3.5, selectedPaint);
        canvas.drawCircle(Offset(px, py), 7, selectedRing);
      } else {
        canvas.drawCircle(Offset(px, py), 3, addedPaint);
      }
    }

    // ── POI crosshair (orange) ──
    final poiX = cx + session.poiOffsetXInches * scale;
    final poiY = cy - session.poiOffsetYInches * scale;
    final poiPaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 2;
    const arm = 8.0;
    canvas.drawLine(
      Offset(poiX - arm, poiY),
      Offset(poiX + arm, poiY),
      poiPaint,
    );
    canvas.drawLine(
      Offset(poiX, poiY - arm),
      Offset(poiX, poiY + arm),
      poiPaint,
    );

    // ── Point of aim crosshair (white, center) ──
    final aimPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    canvas.drawLine(Offset(cx - arm, cy), Offset(cx + arm, cy), aimPaint);
    canvas.drawLine(Offset(cx, cy - arm), Offset(cx, cy + arm), aimPaint);
  }

  @override
  bool shouldRepaint(covariant CalibrationPreviewPainter old) =>
      session != old.session ||
      selectedIndex != old.selectedIndex ||
      detectedPellets != old.detectedPellets ||
      addedPellets != old.addedPellets ||
      backgroundImage != old.backgroundImage ||
      sheetSizeInches != old.sheetSizeInches;
}
