// Standard G1 and G7 drag coefficient tables.
// Cd (coefficient of drag) vs Mach number.
// Source: pyballistic / py-ballisticcalc — industry-standard reference data.

/// G1 drag model — flat-base spitzer shape.
/// [Mach, Cd]
const List<List<double>> g1DragTable = [
  [0.00, 0.2629],
  [0.05, 0.2558],
  [0.10, 0.2487],
  [0.15, 0.2413],
  [0.20, 0.2344],
  [0.25, 0.2278],
  [0.30, 0.2214],
  [0.35, 0.2155],
  [0.40, 0.2104],
  [0.45, 0.2061],
  [0.50, 0.2032],
  [0.55, 0.2020],
  [0.60, 0.2034],
  [0.70, 0.2165],
  [0.725, 0.2230],
  [0.75, 0.2313],
  [0.775, 0.2417],
  [0.80, 0.2546],
  [0.825, 0.2706],
  [0.85, 0.2901],
  [0.875, 0.3136],
  [0.90, 0.3415],
  [0.925, 0.3734],
  [0.95, 0.4084],
  [0.975, 0.4448],
  [1.0, 0.4805],
  [1.025, 0.5136],
  [1.05, 0.5427],
  [1.075, 0.5677],
  [1.10, 0.5883],
  [1.125, 0.6053],
  [1.15, 0.6191],
  [1.20, 0.6393],
  [1.25, 0.6518],
  [1.30, 0.6589],
  [1.35, 0.6621],
  [1.40, 0.6625],
  [1.45, 0.6607],
  [1.50, 0.6573],
  [1.55, 0.6528],
  [1.60, 0.6474],
  [1.65, 0.6413],
  [1.70, 0.6347],
  [1.75, 0.6280],
  [1.80, 0.6210],
  [1.85, 0.6141],
  [1.90, 0.6072],
  [1.95, 0.6003],
  [2.00, 0.5934],
  [2.05, 0.5867],
  [2.10, 0.5804],
  [2.15, 0.5743],
  [2.20, 0.5685],
  [2.25, 0.5630],
  [2.30, 0.5577],
  [2.35, 0.5527],
  [2.40, 0.5481],
  [2.45, 0.5438],
  [2.50, 0.5397],
  [2.60, 0.5325],
  [2.70, 0.5264],
  [2.80, 0.5211],
  [2.90, 0.5168],
  [3.00, 0.5133],
  [3.10, 0.5105],
  [3.20, 0.5084],
  [3.30, 0.5067],
  [3.40, 0.5054],
  [3.50, 0.5040],
  [3.60, 0.5030],
  [3.70, 0.5022],
  [3.80, 0.5016],
  [3.90, 0.5010],
  [4.00, 0.5006],
  [4.20, 0.4998],
  [4.40, 0.4995],
  [4.60, 0.4992],
  [4.80, 0.4990],
  [5.00, 0.4988],
];

/// G7 drag model — boat-tail spitzer shape (long-range match bullets).
/// [Mach, Cd]
const List<List<double>> g7DragTable = [
  [0.00, 0.1198],
  [0.05, 0.1197],
  [0.10, 0.1196],
  [0.15, 0.1194],
  [0.20, 0.1193],
  [0.25, 0.1194],
  [0.30, 0.1194],
  [0.35, 0.1194],
  [0.40, 0.1193],
  [0.45, 0.1193],
  [0.50, 0.1194],
  [0.55, 0.1193],
  [0.60, 0.1194],
  [0.65, 0.1197],
  [0.70, 0.1202],
  [0.725, 0.1207],
  [0.75, 0.1215],
  [0.775, 0.1226],
  [0.80, 0.1242],
  [0.825, 0.1266],
  [0.85, 0.1306],
  [0.875, 0.1368],
  [0.90, 0.1464],
  [0.925, 0.1660],
  [0.95, 0.2054],
  [0.975, 0.2993],
  [1.00, 0.3803],
  [1.025, 0.4015],
  [1.05, 0.4043],
  [1.075, 0.4034],
  [1.10, 0.4014],
  [1.125, 0.3987],
  [1.15, 0.3955],
  [1.20, 0.3884],
  [1.25, 0.3810],
  [1.30, 0.3732],
  [1.35, 0.3657],
  [1.40, 0.3580],
  [1.50, 0.3440],
  [1.55, 0.3376],
  [1.60, 0.3315],
  [1.65, 0.3260],
  [1.70, 0.3209],
  [1.75, 0.3160],
  [1.80, 0.3117],
  [1.85, 0.3078],
  [1.90, 0.3042],
  [1.95, 0.3010],
  [2.00, 0.2980],
  [2.05, 0.2951],
  [2.10, 0.2922],
  [2.15, 0.2892],
  [2.20, 0.2864],
  [2.25, 0.2835],
  [2.30, 0.2807],
  [2.35, 0.2779],
  [2.40, 0.2752],
  [2.45, 0.2725],
  [2.50, 0.2697],
  [2.55, 0.2670],
  [2.60, 0.2643],
  [2.65, 0.2615],
  [2.70, 0.2588],
  [2.75, 0.2561],
  [2.80, 0.2533],
  [2.85, 0.2506],
  [2.90, 0.2479],
  [2.95, 0.2451],
  [3.00, 0.2424],
  [3.10, 0.2368],
  [3.20, 0.2313],
  [3.30, 0.2258],
  [3.40, 0.2205],
  [3.50, 0.2154],
  [3.60, 0.2106],
  [3.70, 0.2060],
  [3.80, 0.2017],
  [3.90, 0.1975],
  [4.00, 0.1935],
  [4.20, 0.1861],
  [4.40, 0.1793],
  [4.60, 0.1730],
  [4.80, 0.1672],
  [5.00, 0.1618],
];

/// Linearly interpolate Cd from a drag table at the given Mach number.
double interpolateCd(double mach, List<List<double>> table) {
  if (mach <= table.first[0]) return table.first[1];
  if (mach >= table.last[0]) return table.last[1];

  for (int i = 0; i < table.length - 1; i++) {
    if (mach >= table[i][0] && mach <= table[i + 1][0]) {
      final t = (mach - table[i][0]) / (table[i + 1][0] - table[i][0]);
      return table[i][1] + t * (table[i + 1][1] - table[i][1]);
    }
  }
  return table.last[1];
}

/// Pre-computed PCHIP (monotone cubic Hermite) spline for smooth drag
/// coefficient interpolation. Matches pyballistic's interpolation method.
class PchipSpline {
  final List<double> _xs;
  final List<double> _ys;
  final List<double> _ms; // slopes at each knot

  PchipSpline._(this._xs, this._ys, this._ms);

  /// Build a PCHIP spline from the given drag table.
  factory PchipSpline.fromTable(List<List<double>> table) {
    final n = table.length;
    final xs = List<double>.generate(n, (i) => table[i][0]);
    final ys = List<double>.generate(n, (i) => table[i][1]);
    final ms = _pchipSlopes(xs, ys);
    return PchipSpline._(xs, ys, ms);
  }

  /// Evaluate the spline at Mach number [x].
  double eval(double x) {
    if (x <= _xs.first) return _ys.first;
    if (x >= _xs.last) return _ys.last;

    // Binary search for interval
    int lo = 0, hi = _xs.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (_xs[mid] <= x) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    final h = _xs[hi] - _xs[lo];
    final t = (x - _xs[lo]) / h;
    final t2 = t * t;
    final t3 = t2 * t;

    // Cubic Hermite basis functions
    return (2 * t3 - 3 * t2 + 1) * _ys[lo] +
        (t3 - 2 * t2 + t) * h * _ms[lo] +
        (-2 * t3 + 3 * t2) * _ys[hi] +
        (t3 - t2) * h * _ms[hi];
  }

  /// Compute PCHIP (Fritsch-Carlson) slopes for monotone cubic interpolation.
  static List<double> _pchipSlopes(List<double> xs, List<double> ys) {
    final n = xs.length;
    final ds = List<double>.filled(n - 1, 0.0);
    final ms = List<double>.filled(n, 0.0);

    // Secant slopes
    for (int i = 0; i < n - 1; i++) {
      ds[i] = (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]);
    }

    // Interior points: Fritsch-Carlson method
    for (int i = 1; i < n - 1; i++) {
      if (ds[i - 1] * ds[i] <= 0) {
        ms[i] = 0;
      } else {
        final w1 = 2 * (xs[i + 1] - xs[i]) + (xs[i] - xs[i - 1]);
        final w2 = (xs[i + 1] - xs[i]) + 2 * (xs[i] - xs[i - 1]);
        ms[i] = (w1 + w2) / (w1 / ds[i - 1] + w2 / ds[i]);
      }
    }

    // Endpoints: one-sided shape-preserving
    ms[0] = _endSlope(xs[0], xs[1], xs[2], ys[0], ys[1], ys[2], ds[0]);
    ms[n - 1] = _endSlope(
      xs[n - 1],
      xs[n - 2],
      xs[n - 3],
      ys[n - 1],
      ys[n - 2],
      ys[n - 3],
      ds[n - 2],
    );

    return ms;
  }

  static double _endSlope(
    double x0,
    double x1,
    double x2,
    double y0,
    double y1,
    double y2,
    double d0,
  ) {
    final h0 = x1 - x0;
    final h1 = x2 - x1;
    final del0 = (y1 - y0) / h0;
    final del1 = (y2 - y1) / h1;
    var s = ((2 * h0 + h1) * del0 - h0 * del1) / (h0 + h1);
    if (s.sign != del0.sign) {
      s = 0;
    } else if (del0.sign != del1.sign && s.abs() > (3 * del0).abs()) {
      s = 3 * del0;
    }
    return s;
  }
}
