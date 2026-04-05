# Shotgun Pattern Estimation

Users can create shotgun profiles alongside rifle profiles. Select a shotgun setup (gauge, choke, load, wad type), drop a pin on the map, and see an estimated pellet pattern at the computed distance. Pro subscribers can calibrate predictions with real patterning-board photos analysed on-device via OpenCV.

## How it works

1. **Create profile** — Tap the profile button → **Add** → select **Shotgun** → fill in gauge, choke, load details, pellet count, wad type, and ammo spread class.
2. **Predict** — Long-press the map to drop a pin. The app computes haversine distance from your GPS position to the pin and displays the predicted pattern at that range.
3. **Visualise** — A full-screen pattern view shows concentric circles (spread edge, R75, R50, 20" and 10" reference circles) with simulated pellet dots, plus metric pills (spread diameter, R50, R75, pellets in 10"/20" circles).
4. **Adjust distance** — A slider (5–60 yds) lets you explore different ranges; the pattern updates live.
5. **Calibrate (Pro)** — Tap "Calibrate from Photo", follow the on-screen instructions, take a photo of your shot pattern on any square target (any size, any color, at any distance), then specify the target size and shooting distance. The app analyses the photo on-device and shows detections overlaid on the actual rectified image. A before/after comparison lets you accept or discard the calibration.
6. **Improve over time** — Each accepted calibration is blended into the setup's stored record using an exponential moving average weighted by session confidence, progressively refining predictions.

## Free vs Pro

| Capability                                | Free | Pro |
| ----------------------------------------- | ---- | --- |
| Shotgun profile creation                  | ✅   | ✅  |
| Pattern prediction (any distance)         | ✅   | ✅  |
| Pattern visualisation + distance slider   | ✅   | ✅  |
| Photo-based calibration                   | —    | ✅  |
| Calibration history (cumulative blending) | —    | ✅  |

## Pattern Engine

The prediction engine uses a **Rayleigh distribution anchored to published pattern efficiency (PE)** data — the fraction of pellets landing in a 30″ circle at 40 yards. PE values are from Lyman's Shotshell Handbook and the NRA Firearms Fact Book.

### Why Rayleigh?

A shotgun pellet's miss distance from the bore axis can be decomposed into independent horizontal and vertical deviations, each approximately normally distributed with zero mean and equal variance σ². The radial distance $r = \sqrt{x^2 + y^2}$ then follows a **Rayleigh distribution** with CDF:

$$P(r) = 1 - e^{-r^2 / 2\sigma^2}$$

This gives the fraction of pellets landing within a circle of radius $r$. The single parameter σ controls how spread out the pattern is — a tighter choke means a smaller σ, concentrating more pellets near the center. From σ alone you can derive every useful metric: the radius containing 50% of pellets (R50 = $\sigma\sqrt{\ln 4}$), the radius containing 75% (R75 = R50 × √2), or the expected pellet count in any circle. The ratio R75/R50 = √2 is an invariant of the Rayleigh distribution regardless of choke or distance.

### Algorithm

1. **Look up PE** for the choke and derive σ₄₀ (the Rayleigh sigma at 40 yards):

$$\sigma_{40} = \frac{15}{\sqrt{-2\ln(1-PE)}}$$

2. **Apply modifiers**: $\sigma_{40_{adj}} = \sigma_{40} \times \text{gauge} \times \text{hardness} \times \text{wad} \times \text{ammo}$
3. **Scale to distance**: $\sigma = \sigma_{40_{adj}} \times \frac{d}{40}$
4. **Apply calibration**: $\sigma_{final} = \sigma \times \text{calDiamMod} \times \text{calSigMod}$
5. **Derive metrics** from σ_final:
   - R50 = $\sigma\sqrt{\ln 4}$, &ensp; R75 = $\sigma\sqrt{2\ln 4}$ = R50 × √2
   - Pellets in circle of radius r = $N \times (1 - e^{-r^2/2\sigma^2})$
   - Spread diameter (99% containment) = $2\sigma\sqrt{-2\ln(0.01)}$

### Pattern efficiency table

| Choke             | PE (40 yd) | σ₄₀ (inches) |
| ----------------- | ---------: | -----------: |
| Cylinder          |        40% |        14.84 |
| Skeet             |        45% |        13.72 |
| Improved Cylinder |        50% |        12.74 |
| Modified          |        60% |        11.08 |
| Improved Modified |        65% |        10.35 |
| Full              |        70% |         9.66 |
| Extra Full        |        73% |         9.18 |

### Modifiers

| Category              | Values                                                       |
| --------------------- | ------------------------------------------------------------ |
| **Gauge**             | 12ga 1.00, 20ga 1.05, 28ga 1.08, .410 1.12                   |
| **Shot material**     | Lead 1.00, Steel 0.85, Bismuth 0.93, Tungsten 0.87, TSS 0.85 |
| **Wad type**          | Plastic 1.00, Fiber 1.10                                     |
| **Ammo spread class** | Tight 0.85, Standard 1.00, Wide 1.20                         |

> **Steel "two chokes tighter" rule**: Steel + Modified (σ = 11.08 × 0.85 ≈ 9.42″) ≈ Lead + Full (σ = 9.66″), confirming the commonly cited guideline.

## Calibration Pipeline (opencv_dart)

Photo calibration uses `opencv_dart` (dartcv4) to analyse patterning-board photos entirely on-device. Supports **any square target** of any size, any color, at any distance — the user specifies target dimensions and shooting distance after taking the photo.

1. **Decode** — `imdecode` from camera JPEG bytes.
2. **Page detection** — Grayscale → Gaussian blur → adaptive threshold → `findContours` (external) → `approxPolyDP` to find the largest quadrilateral (≥5% of image area). Automatically adapts detection for light or dark targets.
3. **Perspective rectification** — `getPerspectiveTransform` + `warpPerspective` to a 720×720 px square (px/inch scales to target size).
4. **Pellet detection** — Invert → Otsu threshold → morphological open (elliptical kernel) → `connectedComponentsWithStats` → filter by area (4–250 px²).
5. **Metrics** — Centroid (POI offset), radial sort for R50/R75, pellets in 10"/20" circles, edge clipping likelihood, confidence score.
6. **Display** — Detected pellet positions are overlaid on the actual rectified photo image for visual verification. Users can tap to add or remove detections.
7. **Blending** — New session is merged into the stored `CalibrationRecord` via exponential moving average weighted by session confidence.

## Effective Range

A red dashed circle on the map shows the **effective hunting range** for the selected shotgun profile and game animal. The user picks a game target (e.g. Deer, Duck, Turkey) in the profile editor; the circle updates automatically.

### Game targets

Each `GameTarget` defines three thresholds:

| Target            | Min pellet energy (ft-lbs) | Vital zone ∅ (in) | Min vital energy (ft-lbs) |
| ----------------- | -------------------------: | ----------------: | ------------------------: |
| Dove / Quail      |                        3.5 |               2.5 |                       3.0 |
| Duck / Teal       |                        3.0 |               4.0 |                       5.0 |
| Pheasant          |                        3.0 |               4.0 |                       5.0 |
| Goose             |                        3.0 |               5.0 |                       8.0 |
| Turkey            |                        1.0 |               3.0 |                      15.0 |
| Rabbit / Squirrel |                        3.5 |               3.0 |                       3.0 |
| Coyote            |                       35.0 |               7.0 |                      60.0 |
| Deer              |                       35.0 |              10.0 |                     300.0 |
| Hog               |                       40.0 |               8.0 |                     350.0 |

- **Min pellet energy** — per-pellet kinetic energy floor for adequate penetration. High for buckshot targets (deer, hog, coyote) because the pellet must reach vitals through hide and muscle. Low for birdshot targets where small pellets suffice.
- **Vital zone diameter** — approximate cross-section of the animal's lethal target area.
- **Min vital energy** — total kinetic energy that must be delivered inside the vital zone. For large game (deer, hog) this is hundreds of ft-lbs; for birds a few ft-lbs is sufficient.

### Algorithm

The effective range is the **minimum** of two independently computed limits:

1. **Energy-limited range** — binary search for the farthest distance where a single pellet still carries ≥ `minPelletEnergyFtLbs`. Pellet velocity decays via an exponential drag model: `v(x) = v₀ × exp(−x / (BC × 6000))`, where BC is approximated as `mass_lbs / (d² × 1.5)` for a spherical projectile.

2. **Confidence-limited range** — binary search for the farthest distance where, with **≥ 80 % probability**, enough pellets strike the vital zone to deliver `minVitalEnergyFtLbs` total. This uses a binomial survival function: `P(X ≥ k) where X ~ Binomial(n, p)`, with:
   - `n` = pellet count
   - `p` = probability a single pellet hits the vital circle, computed from the Rayleigh CDF using the PE-anchored σ model (same as the Pattern Engine, with gauge and shot-material hardness modifiers)
   - `k` = ⌈minVitalEnergyFtLbs / pelletEnergy⌉ — the minimum number of pellets needed

Both binary searches converge to within 0.5 yards over a 0–300 yard domain.

### Verified ranges

| Setup                            | Target | Effective range |
| -------------------------------- | ------ | --------------: |
| 12 ga 00 Buck, Cylinder, Plastic | Coyote |           16 yd |
| 12 ga 00 Buck, Cylinder, Plastic | Deer   |           16 yd |
| 12 ga 00 Buck, Cylinder, Plastic | Hog    |           13 yd |
| 12 ga 00 Buck, Modified, Plastic | Deer   |           22 yd |
| 12 ga #6 Lead, Modified, Plastic | Dove   |           38 yd |
| 12 ga #6 Lead, Modified, Plastic | Duck   |           45 yd |
| 12 ga TSS #9, Full, Plastic      | Turkey |           33 yd |
| 20 ga #6 Lead, Modified, Plastic | Duck   |           41 yd |

## Architecture

| Component          | File                                           | Role                                                                                      |
| ------------------ | ---------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Model              | `lib/models/shotgun_setup.dart`                | ShotgunSetup + enums (Gauge, ChokeType, ShotCategory, ShotSize, WadType, AmmoSpreadClass) |
| Calibration data   | `lib/models/calibration_record.dart`           | Stored calibration multipliers per setup                                                  |
| Session data       | `lib/models/calibration_session.dart`          | Single photo analysis output (metrics + pellet coordinates)                               |
| Result data        | `lib/models/pattern_result.dart`               | Prediction output (spread, R50, R75, pellet counts, POI)                                  |
| Engine             | `lib/ballistics/pattern_engine.dart`           | PE-anchored Rayleigh distribution prediction                                              |
| Shotgun ballistics | `lib/ballistics/shotgun_ballistics.dart`       | Per-pellet velocity decay, energy, hit probability, effective range                       |
| CV pipeline        | `lib/services/pattern_calibrator.dart`         | opencv_dart page detection + pellet detection                                             |
| Persistence        | `lib/services/shotgun_service.dart`            | Hive-based save/load for calibration records + session history                            |
| State              | `lib/blocs/shotgun_pattern_cubit.dart`         | Predict, analyse photo, accept/discard calibration                                        |
| Pattern viz        | `lib/widgets/pattern_painter.dart`             | CustomPainter rendering concentric circles + simulated pellets                            |
| Calibration viz    | `lib/widgets/calibration_preview_painter.dart` | CustomPainter rendering detected pellet positions                                         |
| Result screen      | `lib/screens/pattern_result_screen.dart`       | Pattern visualisation + metrics + distance slider + calibrate button                      |
| Calibration screen | `lib/screens/calibration_result_screen.dart`   | Before/after comparison + accept/discard                                                  |
| Profile form       | `lib/screens/profile_screen.dart`              | Unified rifle/shotgun profile editor (weapon type selector)                               |
| Lethal range       | `lib/widgets/lethal_range_overlay.dart`        | Red dashed circle on map at effective range                                               |
