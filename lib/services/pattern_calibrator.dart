import 'dart:io';
import 'dart:math';
import 'dart:ui' show Offset;

import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../models/calibration_session.dart';

/// Analyses a photo of a shotgun pattern shot on a 24"×24" white sheet at
/// 20 yards. Detects the page boundary, rectifies perspective, locates pellet
/// impacts, and computes calibration metrics.
class PatternCalibrator {
  static const _rectifiedSize = 720; // pixels (30 px per inch for 24" sheet)
  static const _pxPerInch = 30.0;
  static const _sheetSizeInches = 24.0;
  static const _calibrationDistanceYards = 20.0;

  /// Analyse a single photo and return a [CalibrationSession].
  ///
  /// [expectedPelletCount] is the user's known pellet count from the load
  /// setup. Used for confidence scoring and clipping detection.
  Future<CalibrationSession> analyze(
    File imageFile, {
    required int expectedPelletCount,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final src = cv.imdecode(bytes, cv.IMREAD_COLOR);
    if (src.isEmpty) throw StateError('Could not decode image');

    try {
      // 1. Find the page quadrilateral
      final corners = _detectPage(src);

      // 2. Rectify to a top-down square
      final rectified = _rectify(src, corners);

      // 3. Detect pellet holes on the rectified image
      final pellets = _detectPellets(rectified, expectedPelletCount);

      // 4. Compute metrics
      return _computeMetrics(pellets, expectedPelletCount);
    } finally {
      src.dispose();
    }
  }

  // ── Page Detection ───────────────────────────────────────────────

  /// Returns 4 corners in order: TL, TR, BR, BL.
  List<cv.Point> _detectPage(cv.Mat src) {
    final gray = cv.cvtColor(src, cv.COLOR_BGR2GRAY);
    final blurred = cv.gaussianBlur(gray, (7, 7), 3.0);

    // Canny edge detection — finds the sharp brightness transition at the
    // paper/wood boundary. Adaptive threshold fails here because the large
    // white paper area has no local contrast.
    final edges = cv.canny(blurred, 30, 100);

    // Dilate to close small gaps in the edge contour
    final kernel = cv.getStructuringElement(cv.MORPH_RECT, (3, 3));
    final dilated = cv.dilate(edges, kernel);

    final (contours, _) = cv.findContours(
      dilated,
      cv.RETR_EXTERNAL,
      cv.CHAIN_APPROX_SIMPLE,
    );

    gray.dispose();
    blurred.dispose();
    edges.dispose();
    kernel.dispose();
    dilated.dispose();

    if (contours.isEmpty) throw StateError('Page not detected');

    // Find the largest roughly-quadrilateral contour
    cv.VecPoint? bestContour;
    double bestArea = 0;

    final minArea = src.rows * src.cols * 0.05; // at least 5% of image
    for (var i = 0; i < contours.length; i++) {
      final contour = contours[i];
      final peri = cv.arcLength(contour, true);
      final approx = cv.approxPolyDP(contour, 0.02 * peri, true);
      final area = cv.contourArea(approx);
      if (approx.length == 4 && area > minArea && area > bestArea) {
        bestContour = approx;
        bestArea = area;
      }
    }

    if (bestContour == null) {
      throw StateError('Page not detected — no quadrilateral found');
    }

    // Order corners: TL, TR, BR, BL
    return _orderCorners(bestContour);
  }

  /// Orders 4 points as: top-left, top-right, bottom-right, bottom-left.
  List<cv.Point> _orderCorners(cv.VecPoint contour) {
    final pts = List.generate(contour.length, (i) => contour[i]);
    // Sum of x+y: smallest = TL, largest = BR
    // Diff of y-x: smallest = TR, largest = BL
    pts.sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
    final tl = pts[0];
    final br = pts[3];
    final remaining = [pts[1], pts[2]];
    remaining.sort((a, b) => (a.y - a.x).compareTo(b.y - b.x));
    final tr = remaining[0];
    final bl = remaining[1];
    return [tl, tr, br, bl];
  }

  // ── Perspective Rectification ────────────────────────────────────

  cv.Mat _rectify(cv.Mat src, List<cv.Point> corners) {
    final srcPts = corners
        .map((p) => cv.Point2f(p.x.toDouble(), p.y.toDouble()))
        .toList();
    final s = _rectifiedSize.toDouble();
    final dstPts = [
      cv.Point2f(0, 0),
      cv.Point2f(s, 0),
      cv.Point2f(s, s),
      cv.Point2f(0, s),
    ];

    final M = cv.getPerspectiveTransform2f(srcPts.cvd, dstPts.cvd);
    final rectified = cv.warpPerspective(src, M, (
      _rectifiedSize,
      _rectifiedSize,
    ));
    M.dispose();
    return rectified;
  }

  // ── Pellet Detection ─────────────────────────────────────────────

  /// Returns pellet positions in inches relative to page center.
  ///
  /// Morphology and area filtering are scaled by [expectedPelletCount]:
  ///   - Low counts (buckshot, ≤20): large close kernel to merge splatter,
  ///     wide area range to accept big holes.
  ///   - High counts (birdshot, 200+): small close kernel to avoid merging
  ///     adjacent tiny holes, narrow area range.
  List<Offset> _detectPellets(cv.Mat rectified, int expectedPelletCount) {
    final gray = cv.cvtColor(rectified, cv.COLOR_BGR2GRAY);

    // Invert: pellet holes (dark) become bright
    final inverted = cv.bitwiseNOT(gray);

    // Otsu's threshold
    final (_, binary) = cv.threshold(
      inverted,
      0,
      255,
      cv.THRESH_BINARY | cv.THRESH_OTSU,
    );

    // Adaptive morphology based on expected pellet size.
    // Buckshot (≤20 pellets): big holes with splatter → aggressive close.
    // Birdshot (200+ pellets): tiny holes close together → gentle close.
    final int closeSize;
    final int openSize;
    final int minArea;
    final int maxArea;
    if (expectedPelletCount <= 20) {
      // Buckshot / slug
      closeSize = 9;
      openSize = 5;
      minArea = 30;
      maxArea = _rectifiedSize * _rectifiedSize ~/ 10; // 10% of image
    } else if (expectedPelletCount <= 100) {
      // Mid-range (#4, #2, BB)
      closeSize = 5;
      openSize = 3;
      minArea = 10;
      maxArea = 2000;
    } else {
      // Birdshot (#6, #7½, #8, #9)
      closeSize = 3;
      openSize = 3;
      minArea = 4;
      maxArea = 500;
    }

    final closeKernel = cv.getStructuringElement(cv.MORPH_ELLIPSE, (
      closeSize,
      closeSize,
    ));
    final closed = cv.morphologyEx(binary, cv.MORPH_CLOSE, closeKernel);
    final openKernel = cv.getStructuringElement(cv.MORPH_ELLIPSE, (
      openSize,
      openSize,
    ));
    final cleaned = cv.morphologyEx(closed, cv.MORPH_OPEN, openKernel);

    // Connected components with stats
    final labels = cv.Mat.empty();
    final stats = cv.Mat.empty();
    final centroids = cv.Mat.empty();
    final numLabels = cv.connectedComponentsWithStats(
      cleaned,
      labels,
      stats,
      centroids,
      8,
      cv.MatType.CV_32SC1.value,
      cv.CCL_DEFAULT,
    );

    final pellets = <Offset>[];
    // Skip label 0 (background)
    for (var i = 1; i < numLabels; i++) {
      final area = stats.at<int>(i, cv.CC_STAT_AREA);
      if (area < minArea || area > maxArea) continue;

      final cx = centroids.at<double>(i, 0);
      final cy = centroids.at<double>(i, 1);

      // Convert from pixels to inches, centered at page middle
      final xInches = cx / _pxPerInch - _sheetSizeInches / 2;
      final yInches = -(cy / _pxPerInch - _sheetSizeInches / 2); // Y up
      pellets.add(Offset(xInches, yInches));
    }

    gray.dispose();
    inverted.dispose();
    binary.dispose();
    closeKernel.dispose();
    closed.dispose();
    openKernel.dispose();
    cleaned.dispose();
    labels.dispose();
    stats.dispose();
    centroids.dispose();

    return pellets;
  }

  // ── Metrics Computation ──────────────────────────────────────────

  CalibrationSession _computeMetrics(
    List<Offset> pellets,
    int expectedPelletCount,
  ) {
    if (pellets.isEmpty) throw StateError('No pellet impacts detected');

    // POI offset: centroid of all detected pellets
    final meanX =
        pellets.map((p) => p.dx).reduce((a, b) => a + b) / pellets.length;
    final meanY =
        pellets.map((p) => p.dy).reduce((a, b) => a + b) / pellets.length;

    // Distances from centroid
    final distances =
        pellets
            .map((p) => sqrt(pow(p.dx - meanX, 2) + pow(p.dy - meanY, 2)))
            .toList()
          ..sort();

    // R50: radius containing 50% of pellets
    final i50 = (distances.length * 0.50).ceil().clamp(1, distances.length) - 1;
    final r50 = distances[i50];

    // R75: radius containing 75% of pellets
    final i75 = (distances.length * 0.75).ceil().clamp(1, distances.length) - 1;
    final r75 = distances[i75];

    // Pellets in 10" and 20" circles (from centroid)
    final in10 = pellets.where((p) {
      final d = sqrt(pow(p.dx - meanX, 2) + pow(p.dy - meanY, 2));
      return d <= 5.0;
    }).length;
    final in20 = pellets.where((p) {
      final d = sqrt(pow(p.dx - meanX, 2) + pow(p.dy - meanY, 2));
      return d <= 10.0;
    }).length;

    // Clipping: pellets within 1" of any page edge
    final edgeMargin = 1.0;
    final halfSheet = _sheetSizeInches / 2;
    final nearEdge = pellets.where((p) {
      return p.dx.abs() > (halfSheet - edgeMargin) ||
          p.dy.abs() > (halfSheet - edgeMargin);
    }).length;
    final clippingLikelihood = pellets.isEmpty
        ? 0.0
        : (nearEdge / pellets.length).clamp(0.0, 1.0);

    // Confidence scoring
    final countRatio = (pellets.length / expectedPelletCount).clamp(0.0, 1.0);
    final clippingPenalty = 1.0 - clippingLikelihood * 0.5;
    final confidence = (countRatio * clippingPenalty).clamp(0.0, 1.0);

    return CalibrationSession(
      distanceYards: _calibrationDistanceYards,
      detectedPelletCount: pellets.length,
      measuredR50Inches: r50,
      measuredR75Inches: r75,
      pelletsIn10Circle: in10,
      pelletsIn20Circle: in20,
      poiOffsetXInches: meanX,
      poiOffsetYInches: meanY,
      clippingLikelihood: clippingLikelihood,
      sessionConfidence: confidence,
      timestamp: DateTime.now(),
      pelletCoordinates: pellets,
    );
  }
}
