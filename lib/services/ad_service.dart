import 'dart:io';

import 'package:flutter/foundation.dart';

/// Centralises AdMob ad-unit IDs.
///
/// Debug / simulator builds automatically use Google's test ad unit IDs.
/// Release builds use the real Monyx Hunt ad unit IDs.
class AdService {
  // ── Banner ────────────────────────────────────────────────────────────
  static String get bannerAdUnitId {
    if (Platform.isIOS) {
      return kReleaseMode
          ? 'ca-app-pub-8357274860394786/5507605098' // real
          : 'ca-app-pub-3940256099942544/2435281174'; // test
    }
    if (Platform.isAndroid) {
      return kReleaseMode
          ? 'ca-app-pub-3940256099942544/6300978111' // TODO: real Android ID
          : 'ca-app-pub-3940256099942544/6300978111'; // test
    }
    throw UnsupportedError('Unsupported platform');
  }
}
