import 'dart:math';

/// Atmospheric calculations for ballistic correction.
///
/// Matches pyballistic's CIPM-2007 air density model and lapse-rate
/// altitude corrections.

// ──────────────────────────────────────────────────────────────────────
// Constants (from pyballistic constants.py)
// ──────────────────────────────────────────────────────────────────────
const double cGravity = 32.17405; // ft/s²
const double cStandardDensity = 0.076474; // lb/ft³
const double cStandardDensityMetric = 1.2250; // kg/m³
const double cStandardTemperatureC = 15.0; // °C
const double cStandardTemperatureF = 59.0; // °F
const double cStandardPressureMetric = 1013.25; // hPa
const double cDegreesCtoK = 273.15;
const double cDegreesFtoR = 459.67;
const double cLapseRateKperFoot = -0.0019812; // K/ft
const double cLapseRateMetric = -6.5e-03; // °C/m
const double cPressureExponent = 5.255876;
const double cSpeedOfSoundImperial = 49.0223; // fps per √°R
const double cSpeedOfSoundMetric = 20.0467; // m/s per √K

/// Speed of sound in ft/s from temperature (°F).
double speedOfSound({required double tempF}) {
  final tempR = tempF + cDegreesFtoR;
  return cSpeedOfSoundImperial * sqrt(tempR);
}

// ──────────────────────────────────────────────────────────────────────
// CIPM-2007 Air Density (matches pyballistic Atmo.calculate_air_density)
// ──────────────────────────────────────────────────────────────────────

/// Air density in **kg/m³** from temperature (°C), pressure (hPa), and
/// relative humidity (0–100 or 0–1 fraction).
double _calculateAirDensityMetric(double tempC, double pHpa, double humidity) {
  const R = 8.314472; // J/(mol·K)
  const mA = 28.96546e-3; // kg/mol, dry air
  const mV = 18.01528e-3; // kg/mol, water vapour

  final tK = tempC + cDegreesCtoK;
  final p = pHpa * 100.0; // Pa

  // Normalize humidity to fraction
  double rh = humidity;
  if (rh > 1.0) rh /= 100.0;
  rh = rh.clamp(0.0, 1.0);

  // Saturation vapour pressure (Pa)
  const svpA = [1.2378847e-5, -1.9121316e-2, 33.93711047, -6.3431645e3];
  final pSv = exp(svpA[0] * tK * tK + svpA[1] * tK + svpA[2] + svpA[3] / tK);

  // Enhancement factor (p in Pa, tempC in °C)
  const alpha = 1.00062;
  const beta = 3.14e-8;
  const gamma = 5.6e-7;
  final f = alpha + beta * p + gamma * tempC * tempC;

  // Partial pressure & mole fraction of water vapour
  final pV = rh * f * pSv;
  final xV = pV / p;

  // Compressibility factor
  final tL = tempC; // t_l = T - 273.15 but T was already in °C
  const a0 = 1.58123e-6;
  const a1 = -2.9331e-8;
  const a2 = 1.1043e-10;
  const b0 = 5.707e-6;
  const b1 = -2.051e-8;
  const c0 = 1.9898e-4;
  const c1 = -2.376e-6;
  const d = 1.83e-11;
  const e = -0.765e-8;
  final pOverT = p / tK;
  final z =
      1 -
      pOverT *
          (a0 +
              a1 * tL +
              a2 * tL * tL +
              (b0 + b1 * tL) * xV +
              (c0 + c1 * tL) * xV * xV) +
      pOverT * pOverT * (d + e * xV * xV);

  return (p * mA) / (z * R * tK) * (1.0 - xV * (1.0 - mV / mA));
}

/// Compute air density **ratio** (local / standard) at station level.
double computeDensityRatio({
  required double tempC,
  required double pressureHpa,
  required double humidity,
}) {
  return _calculateAirDensityMetric(tempC, pressureHpa, humidity) /
      cStandardDensityMetric;
}

/// Density altitude in feet.
double densityAltitude({
  required double tempF,
  required double pressureInHg,
  required double humidityPercent,
}) {
  final tempC = (tempF - 32.0) * 5.0 / 9.0;
  final pHpa = pressureInHg * 33.8639;
  final rhoMetric = _calculateAirDensityMetric(tempC, pHpa, humidityPercent);
  final rhoImperial = rhoMetric / 16.0185; // slugs/ft³ equivalent
  const icaoDensity = 0.0023769; // slugs/ft³
  return 145442.156 * (1.0 - pow(rhoImperial / icaoDensity, 0.234969));
}

// ──────────────────────────────────────────────────────────────────────
// Atmosphere state — supports lapse-rate altitude correction during
// trajectory integration (matches pyballistic Atmo class).
// ──────────────────────────────────────────────────────────────────────
class AtmoState {
  final double _a0; // base altitude (ft)
  final double _t0; // base temperature (°C)
  final double _p0; // base pressure (hPa)
  final double _densityRatio; // at base altitude
  final double _mach; // speed of sound (fps) at base altitude

  AtmoState._({
    required double altFt,
    required double tempC,
    required double pressureHpa,
    required double humidity,
  }) : _a0 = altFt,
       _t0 = tempC,
       _p0 = pressureHpa,
       _densityRatio = computeDensityRatio(
         tempC: tempC,
         pressureHpa: pressureHpa,
         humidity: humidity,
       ),
       _mach =
           cSpeedOfSoundMetric *
           sqrt(tempC + cDegreesCtoK) *
           3.28084; // m/s → fps

  /// Create from station-level weather in mixed units (as our app provides).
  factory AtmoState.fromWeather({
    required double tempF,
    required double pressureInHg,
    required double humidityPercent,
    double altitudeFt = 0,
  }) {
    final tempC = (tempF - 32.0) * 5.0 / 9.0;
    final pHpa = pressureInHg * 33.8639;
    return AtmoState._(
      altFt: altitudeFt,
      tempC: tempC,
      pressureHpa: pHpa,
      humidity: humidityPercent,
    );
  }

  /// Standard ICAO atmosphere (for zero-finding).
  factory AtmoState.icao() => AtmoState._(
    altFt: 0,
    tempC: cStandardTemperatureC,
    pressureHpa: cStandardPressureMetric,
    humidity: 0,
  );

  double get densityRatio => _densityRatio;
  double get mach => _mach;
  double get baseAltitudeFt => _a0;

  /// Density ratio and Mach at an arbitrary altitude during flight.
  /// [altitude] is feet above sea level.
  (double densityRatio, double machFps) densityAndMachAt(double altitude) {
    if ((altitude - _a0).abs() < 30) return (_densityRatio, _mach);

    final tC = (altitude - _a0) * cLapseRateKperFoot + _t0;
    final tK = tC + cDegreesCtoK;
    final machFps = cSpeedOfSoundMetric * sqrt(tK) * 3.28084;
    final p =
        _p0 *
        pow(
          1 + cLapseRateKperFoot * (altitude - _a0) / (_t0 + cDegreesCtoK),
          cPressureExponent,
        );
    final densityDelta = ((_t0 + cDegreesCtoK) * p) / (_p0 * tK);
    return (_densityRatio * densityDelta, machFps);
  }
}
