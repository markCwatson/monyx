import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:opencv_dart/opencv_dart.dart' as cv;

import '../models/calibration_session.dart';

/// Result of calibration photo analysis: the session metrics plus the
/// perspective-rectified image bytes (JPEG) for overlay display.
typedef CalibrationAnalysis = ({
  CalibrationSession session,
  Uint8List rectifiedImage,
});

/// Analyses a photo of a shotgun pattern shot on a square target at a known
/// distance. Detects the target boundary, rectifies perspective, locates
/// pellet impacts, and computes calibration metrics.
///
/// The target can be any colour and any size — the pellet detector tries both
/// dark-on-light and light-on-dark polarities and picks the better match.
class PatternCalibrator {
  static const _pxPerInch = 30.0;

  /// Analyse a single photo and return a [CalibrationAnalysis].
  ///
  /// [expectedPelletCount] is the user's known pellet count from the load
  /// setup. Used for confidence scoring and clipping detection.
  ///
  /// [sheetSizeInches] is the side length of the square target (default 24").
  /// [distanceYards] is the shooting distance (default 20 yds).
  Future<CalibrationAnalysis> analyze(
    File imageFile, {
    required int expectedPelletCount,
    double sheetSizeInches = 24.0,
    double distanceYards = 20.0,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final src = cv.imdecode(bytes, cv.IMREAD_COLOR);
    if (src.isEmpty) throw StateError('Could not decode image');

    final rectifiedSize = (sheetSizeInches * _pxPerInch).round();

    try {
      // 1. Find the page quadrilateral
      final corners = _detectPage(src);

      // 2. Rectify to a top-down square
      final rectified = _rectify(src, corners, rectifiedSize);

      // 3. Encode the rectified image for UI overlay
      final (_, jpegBytes) = cv.imencode('.jpg', rectified);

      // 4. Detect pellet holes — tries both polarities for colour-agnostic
      //    detection and picks the result closest to expected count.
      final pellets = _detectPellets(
        rectified,
        expectedPelletCount,
        sheetSizeInches,
        rectifiedSize,
      );

      // 5. Compute metrics
      final session = _computeMetrics(
        pellets,
        expectedPelletCount,
        sheetSizeInches,
        distanceYards,
      );

      rectified.dispose();

      return (session: session, rectifiedImage: Uint8List.fromList(jpegBytes));
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

  cv.Mat _rectify(cv.Mat src, List<cv.Point> corners, int rectifiedSize) {
    final srcPts = corners
        .map((p) => cv.Point2f(p.x.toDouble(), p.y.toDouble()))
        .toList();
    final s = rectifiedSize.toDouble();
    final dstPts = [
      cv.Point2f(0, 0),
      cv.Point2f(s, 0),
      cv.Point2f(s, s),
      cv.Point2f(0, s),
    ];

    final M = cv.getPerspectiveTransform2f(srcPts.cvd, dstPts.cvd);
    final rectified = cv.warpPerspective(src, M, (
      rectifiedSize,
      rectifiedSize,
    ));
    M.dispose();
    return rectified;
  }

  // ── Pellet Detection ─────────────────────────────────────────────

  /// Returns pellet positions in inches relative to page center.
  ///
  /// Tries both dark-on-light (inverted) and light-on-dark (direct) threshold
  /// polarities and picks whichever yields a count closer to
  /// [expectedPelletCount]. This makes detection work on targets of any colour.
  ///
  /// Morphology and area filtering are scaled by [expectedPelletCount]:
  ///   - Low counts (buckshot, ≤20): large close kernel to merge splatter,
  ///     wide area range to accept big holes.
  ///   - High counts (birdshot, 200+): small close kernel to avoid merging
  ///     adjacent tiny holes, narrow area range.
  List<Offset> _detectPellets(
    cv.Mat rectified,
    int expectedPelletCount,
    double sheetSizeInches,
    int rectifiedSize,
  ) {
    final gray = cv.cvtColor(rectified, cv.COLOR_BGR2GRAY);

    // Try both polarities: dark holes on light target, light holes on dark
    final inverted = cv.bitwiseNOT(gray);
    final pelletsInverted = _detectPelletsFromGray(
      inverted,
      expectedPelletCount,
      sheetSizeInches,
      rectifiedSize,
    );
    final pelletsDirect = _detectPelletsFromGray(
      gray,
      expectedPelletCount,
      sheetSizeInches,
      rectifiedSize,
    );

    gray.dispose();
    inverted.dispose();

    // Pick whichever polarity gives a count closer to expected
    final diffInv = (pelletsInverted.length - expectedPelletCount).abs();
    final diffDir = (pelletsDirect.length - expectedPelletCount).abs();
    return diffInv <= diffDir ? pelletsInverted : pelletsDirect;
  }

  /// Core detection on a single-polarity grayscale image (bright = pellet).
  List<Offset> _detectPelletsFromGray(
    cv.Mat gray,
    int expectedPelletCount,
    double sheetSizeInches,
    int rectifiedSize,
  ) {
    // Otsu's threshold
    final (_, binary) = cv.threshold(
      gray,
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
      maxArea = rectifiedSize * rectifiedSize ~/ 10; // 10% of image
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
      final xInches = cx / _pxPerInch - sheetSizeInches / 2;
      final yInches = -(cy / _pxPerInch - sheetSizeInches / 2); // Y up
      pellets.add(Offset(xInches, yInches));
    }

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
    double sheetSizeInches,
    double distanceYards,
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
    final halfSheet = sheetSizeInches / 2;
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
      distanceYards: distanceYards,
      sheetSizeInches: sheetSizeInches,
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
